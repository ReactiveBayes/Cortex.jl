"""
    UndefValue

A singleton type used to represent an undefined or uninitialized state within a [`Signal`](@ref).
This indicates that the signal has not yet been computed or has been invalidated.
"""
struct UndefValue end

"""
    UndefMetadata

A singleton type used to represent an undefined or uninitialized state within a [`Signal`](@ref).
This indicates that the signal has no metadata.
"""
struct UndefMetadata end

# Stores properties of a `Signal`'s dependencies in a bit-packed format.
#
# Each dependency's properties are stored in 4 bits (nibbles) within a `UInt64` chunk. 
# herefore, each `UInt64` chunk can store properties for 16 dependencies.
#
# The 4 bits for each dependency are used as follows (from LSB to MSB):
# - Bit 1 (Mask `0x1`): `IsIntermediate` - Indicates if the dependency is intermediate or not.
# - Bit 2 (Mask `0x2`): `IsWeak` - Indicates if the dependency is weak or not.
# - Bit 3 (Mask `0x4`): `IsComputed` - Indicates if the dependency's value has been computed or not.
# - Bit 4 (Mask `0x8`): `IsFresh` - Indicates if the dependency has a new, fresh (unused) value or not.
#
# !!! warning
#     This is an internal type and should not be used directly. Use the functions defined in the `Signal` structure instead.
#     This structure can be removed in the future. The structure itself uses `@inbounds` annotations 
#     to access the `chunks` array in the most efficient way possible. Incorrect usage of this structure
#     may result in undefined behavior and memory corruption.
# 
# The lowlevel implementation of this structure and the associated functions is implemented under the `Signal` structure
# Here we only need to defined this structure in order to properly define the `Signal` structure below
mutable struct SignalDependenciesProps
    length::Int
    const chunks::Vector{UInt64}

    function SignalDependenciesProps()
        # It is reasonable to assume that a signal will have at least one dependency
        # Thus we need to allocate at least one chunk
        return new(0, UInt64[UInt64(0)])
    end
end

# Stores the properties of a `Signal` in a single structure to avoid excessive memory accesses
Base.@kwdef struct SignalProps
    is_potentially_pending::Bool = false
    is_pending::Bool = false
end

"""
    Signal()
    Signal(value; type::UInt8 = 0x00, metadata::Any = UndefMetadata())

A reactive signal that holds a value and tracks dependencies as well as notifies listeners when the value changes.
If created without an initial value, the signal is initialized with [`UndefValue()`](@ref).
The `metadata` field can be used to store arbitrary metadata about the signal. Default value is [`UndefMetadata()`](@ref).

A signal is said to be 'pending' if it is ready for potential recomputation (due to updated dependencies).
However, a signal is not recomputed immediately when it becomes pending. Moreover, a Signal does not know 
how to recompute itself. The recomputation logic is defined separately with the [`compute!`](@ref) function.

Signals form a directed graph where edges represent dependencies.
When a signal's value is updated via [`set_value!`](@ref), it notifies its active listeners.

A signal may become 'pending' if all its dependencies meet the following criteria:
- all its weak dependencies have computed values, AND
- all its strong dependencies have computed values and are older than the listener.

A signal can depend on another signal without listening to it, see [`add_dependency!`](@ref) for more details.

The `type` field is an optional `UInt8` type identifier. 
It might be useful to choose different computation strategies for different types of signals within the [`compute!`](@ref) function.

See also: [`add_dependency!`](@ref), [`set_value!`](@ref), [`compute!`](@ref), [`process_dependencies!`](@ref)
"""
mutable struct Signal
    value::Any
    metadata::Any

    type::UInt8
    props::SignalProps

    const dependencies_props::SignalDependenciesProps
    const dependencies::Vector{Signal}

    const listenmask::BitVector
    const listeners::Vector{Signal}

    # Constructor for creating an empty signal
    function Signal(; type::UInt8 = 0x00, metadata::Any = UndefMetadata())
        return new(
            UndefValue(),
            metadata,
            type,
            SignalProps(),
            SignalDependenciesProps(),
            Vector{Signal}(),
            trues(0),
            Vector{Signal}()
        )
    end

    # Constructor for creating a new signal with a value
    function Signal(value::Any; type::UInt8 = 0x00, metadata::Any = UndefMetadata())
        return new(
            value,
            metadata,
            type,
            SignalProps(),
            SignalDependenciesProps(),
            Vector{Signal}(),
            trues(0),
            Vector{Signal}()
        )
    end
end

"""
    is_pending(s::Signal) -> Bool

Check if the signal `s` is marked as pending. This usually indicates that the signal's value is stale and needs recomputation.
See also: [`compute!`](@ref), [`process_dependencies!`](@ref).
"""
function is_pending(s::Signal)::Bool
    # In case if the signal is potentially pending, we need to check if it is actually pending or not
    # and reset the potential pending state
    props = s.props
    if props.is_pending
        return true
    end
    if props.is_potentially_pending
        new_is_pending = is_meeting_pending_criteria(s.dependencies_props)
        s.props = SignalProps(is_potentially_pending = false, is_pending = new_is_pending)
        return new_is_pending
    end
    return false
end

"""
    is_computed(s::Signal) -> Bool

Check if the signal `s` has been computed (i.e., its value is not equal to [`UndefValue()`](@ref)).
See also: [`set_value!`](@ref).
"""
function is_computed(s::Signal)::Bool
    return s.value !== UndefValue()
end

"""
    get_value(s::Signal)

Get the current value of the signal `s`.
"""
function get_value(s::Signal)
    return s.value
end

"""
    get_type(s::Signal) -> UInt8

Get the type identifier (UInt8) of the signal `s`.
Defaults to `0x00` if not specified during construction.
"""
function get_type(s::Signal)::UInt8
    return s.type
end

"""
    get_metadata(s::Signal)

Get the metadata associated with the signal `s`.
"""
function get_metadata(s::Signal)
    return s.metadata
end

"""
    get_dependencies(s::Signal) -> Vector{Signal}

Get the list of signals that the signal `s` depends on.
"""
function get_dependencies(s::Signal)::Vector{Signal}
    return s.dependencies
end

"""
    get_listeners(s::Signal) -> Vector{Signal}

Get the list of signals that listen to the signal `s` (i.e., signals that depend on `s`).
"""
function get_listeners(s::Signal)::Vector{Signal}
    return s.listeners
end

"""
    set_value!(s::Signal, value::Any)

Set the `value` of the signal `s`. Notifies all the active listeners of the signal.

!!! note
    This function is not a part of the public API. 
    Additionally, it is implied that [`set_value!`](@ref) must be called only on signals that are pending.
    Use [`compute!`](@ref) for a more general way to update signal values.

"""
function set_value!(signal::Signal, @nospecialize(value))

    # We update the value of the signal
    signal.value = value

    # This marks the current dependencies as "not fresh", meaning that they have been used 
    # to set a new value on the current signal. The signal will not be pending anymore 
    # as its dependencies are not fresh 
    # (unless they are weak dependencies, which only required to be computed and not necessarily fresh)
    unset_all_dependencies_fresh!(signal.dependencies_props)

    signal.props = SignalProps(is_potentially_pending = false, is_pending = false)

    # We notify all the signals that listen to this signal that it has been updated
    # We only notify the signals that are listening to the current signal
    for (is_listening, listener) in zip(signal.listenmask, signal.listeners)
        # The listener will update its state to potentially pending if it is listening to the current signal
        notify_listener!(listener, signal; update_potentially_pending = is_listening)
    end

    return nothing
end

"""
    add_dependency!(signal::Signal, dependency::Signal; weak::Bool = false, listen::Bool = true, intermediate::Bool = false)

Add `dependency` to the list of dependencies for signal `signal`.
Also adds `signal` to the list of listeners for `dependency`.

Arguments:
- `signal::Signal`: The signal to add a dependency to.
- `dependency::Signal`: The signal to be added as a dependency.

Keyword Arguments:
- `intermediate::Bool = false`: If `true`, marks the dependency as intermediate. Intermediate dependencies
have an effect on the `process_dependencies!` function. See the documentation of [`process_dependencies!`](@ref) for more details.
By default, the added dependency is not intermediate.
- `weak::Bool = false`: If `true`, marks the dependency as weak. Weak dependencies
  only require `is_computed` to be true (not necessarily older) for the dependent
  signal `signal` to potentially become pending.
- `listen::Bool = true`: If `true`, `signal` will be notified when `dependency` is updated.
  If `false`, `dependency` is added, but `signal` will not automatically be notified
  of updates to `dependency`.
- `check_computed::Bool = true`: If `true`, the function will check if `dependency` is already computed.
If so, it will notify `signal` immediately. Note that if `listen` is set to false, 
further updates to `dependency` will not trigger notifications to `signal`.

The same dependency should not be added multiple times. Doing so will result in wrong notification behaviour and likely will lead to incorrect results.
Note that this function does nothing if `signal === dependency`.
"""
function add_dependency!(
    signal::Signal,
    dependency::Signal;
    weak::Bool = false,
    listen::Bool = true,
    check_computed::Bool = true,
    intermediate::Bool = false
)
    # We check that the dependency is not the same signal
    if signal === dependency
        return nothing
    end

    dependencies_props = signal.dependencies_props
    dependencies_props_index = add_dependency!(dependencies_props)

    if weak
        set_dependency_weak!(dependencies_props, dependencies_props_index)
    end

    if intermediate
        set_dependency_intermediate!(dependencies_props, dependencies_props_index)
    end

    push!(signal.dependencies, dependency)

    # If the dependency listens to updates, we add the current signal, 
    # we add `true` to the listenmask, `false` otherwise
    if listen
        push!(dependency.listenmask, true)
    else
        push!(dependency.listenmask, false)
    end

    push!(dependency.listeners, signal)

    # If a new dependency has been added and this new dependency has already been computed,
    # we immediately notify the current signal `s` as if it was already subscribed to the changes
    if check_computed && is_computed(dependency)
        set_dependency_computed!(dependencies_props, dependencies_props_index)
        # If the current signal is not computed, we mark the newly added dependency as fresh
        # so that the current signal can potentially become pending
        if !is_computed(signal)
            set_dependency_fresh!(dependencies_props, dependencies_props_index)
        end
        signal.props = SignalProps(is_potentially_pending = true, is_pending = false)
    elseif check_computed && !is_computed(dependency)
        signal.props = SignalProps(is_potentially_pending = false, is_pending = false)
    end

    return nothing
end

function notify_listener!(listener::Signal, signal::Signal; update_potentially_pending::Bool = false)
    if update_potentially_pending
        listener.props = SignalProps(is_potentially_pending = true, is_pending = false)
    end

    # Duplicate dependencies will never received a notification
    for i in eachindex(listener.dependencies)
        @inbounds dependency = listener.dependencies[i]
        if (dependency === signal)
            listener_dependencies_props = listener.dependencies_props
            set_dependency_fresh!(listener_dependencies_props, i)
            set_dependency_computed!(listener_dependencies_props, i)
            break
        end
    end

    return nothing
end

# --- Show Method ---

function Base.show(io::IO, s::Signal)
    val_str = is_computed(s) ? repr(get_value(s)) : "#undef"
    pending_str = is_pending(s) ? "true" : "false"
    type_str = repr(get_type(s)) # Use repr directly for type
    meta = get_metadata(s)

    print(io, "Signal(value=", val_str, ", pending=", pending_str) # New order
    if get_type(s) !== 0x00
        print(io, ", type=", type_str)                               # New order
    end
    if meta !== UndefMetadata()
        print(io, ", metadata=", repr(meta))
    end
    print(io, ")")
end

# --- Compute Interface ---

"""
    compute!(s::Signal, strategy; force::Bool = false)

Compute the value of the signal `s` using the given `strategy`. 
The strategy must implement [`compute_value!`](@ref) method.
If the strategy is a function, it is assumed to be a function
that takes the signal and a vector of signal's dependencies as arguments and returns a value.
Be sure to call `compute!` only on signals that are pending. 
Calling `compute!` on a non-pending signal will result in an error.

Keyword Arguments:
- `force::Bool = false`: If `true`, the signal will be computed even if it is not pending.
"""
function compute!(strategy, signal::Signal; force::Bool = false)
    if !force && !is_pending(signal)
        throw(
            ArgumentError(
                "Signal is not pending. Cannot compute a non-pending signal. Use `force=true` to force computation."
            )
        )
    end
    dependencies = get_dependencies(signal)
    new_value = compute_value!(strategy, signal, dependencies)
    set_value!(signal, new_value)
    return nothing
end

"""
    compute_value!(strategy, signal, dependencies)

Compute the value of the signal `signal` using the given `strategy`.
The strategy must implement this method. See also [`compute!`](@ref).
"""
function compute_value!(strategy, signal, dependencies)
    error("`compute_value!` must be implemented for the given strategy of type `$(typeof(strategy))`")
end

function compute_value!(strategy::F, signal::Signal, dependencies::Vector{Signal}) where {F <: Function}
    return strategy(signal, dependencies)
end

# --- Processing Interface ---

"""
    process_dependencies!(f::F, signal::Signal; retry::Bool = false) where {F}

Recursively processes the dependencies of a `signal` using a provided function `f`.

The function `f` is applied to each direct dependency of `signal`. If a dependency is marked as `intermediate` 
and `f` returns `false` for it (indicating it was not processed by `f` according to its own criteria), 
`process_dependencies!` will then be called recursively on that intermediate dependency.

Arguments:
- `f::F`: A function (or callable object) that takes a `Signal` (a dependency) as an argument and returns a `Bool`. 
  It should return `true` if it considered the dependency processed, and `false` otherwise. The specific logic 
  for this determination (e.g., checking if a dependency is pending before processing) is up to `f`.
- `signal::Signal`: The signal whose dependencies are to be processed.

Keyword Arguments:
- `retry::Bool = false`: If `true`, and an intermediate dependency's own sub-dependencies were processed 
  (i.e., the recursive call to `process_dependencies!` for the intermediate dependency returned `true` 
  because `f` returned `true` for at least one sub-dependency), then the function `f` will be called 
  again on the intermediate dependency itself. This allows for a second attempt by `f` to process the 
  intermediate dependency after its own prerequisites might have been met by processing its sub-dependencies.

Returns:
- `Bool`: `true` if the function `f` returned `true` for at least one dependency encountered (either directly 
  or recursively through an intermediate one). Returns `false` if `f` returned `false` for all dependencies 
  it was applied to.

Behavior Details:
- For each dependency of `signal`:
    1. `f(dependency)` is called.
    2. If `f(dependency)` returns `true`, this dependency is considered processed by `f`.
    3. If `f(dependency)` returns `false` AND the dependency is marked as `intermediate`:
        a. `process_dependencies!(f, dependency; retry=retry)` is called recursively.
        b. If this recursive call returns `true` (meaning `f` processed at least one sub-dependency of the 
           intermediate one) AND `retry` is `true`, then `f(dependency)` is called again.
- The function tracks whether `f` returned `true` for any dependency it was applied to, at any level of 
  recursion (for intermediate dependencies) or direct application, and returns this aggregated result.
"""
function process_dependencies!(f::F, signal::Signal; retry::Bool = false) where {F}
    dependencies = get_dependencies(signal)
    processed_at_least_once = false
    for i in eachindex(dependencies)
        @inbounds dependency = dependencies[i]
        # We first try to process the dependency itself
        processed = f(dependency)
        # If it wasn't processed, we check if it is an intermediate dependency or not 
        # and if it is, we process its dependencies recursively
        if !processed
            if is_dependency_intermediate(signal.dependencies_props, i)
                intermediate_processed_at_least_once = process_dependencies!(f, dependency; retry = retry)
                # If we processed the recursive dependencies, and the retry flag is set,
                # we try to process the dependency itself again
                if intermediate_processed_at_least_once && retry
                    processed = f(dependency)
                end
                processed_at_least_once = processed_at_least_once || intermediate_processed_at_least_once
            end
        end
        processed_at_least_once = processed_at_least_once || processed
    end

    return processed_at_least_once
end

# --- Lowlevel Interface of SignalDependenciesProps ---

function Base.show(io::IO, props::SignalDependenciesProps)
    print(io, "SignalDependenciesProps(length=", props.length, ", deps=[")
    for i in 1:(props.length)
        print(io, "(")
        print(io, ifelse(is_dependency_weak(props, i), "w,", "!w,"))
        print(io, ifelse(is_dependency_intermediate(props, i), "i,", "!i,"))
        print(io, ifelse(is_dependency_computed(props, i), "c,", "!c,"))
        print(io, ifelse(is_dependency_fresh(props, i), "f", "!f"))
        print(io, ")")
    end
    print("])")
end

const SignalDependenciesProps_IsIntermediateMask_SingleNibble::UInt64 = UInt64(0x1) # 0001
const SignalDependenciesProps_IsWeakMask_SingleNibble::UInt64 = UInt64(0x2)         # 0010
const SignalDependenciesProps_IsComputedMask_SingleNibble::UInt64 = UInt64(0x4)     # 0100
const SignalDependenciesProps_IsFreshMask_SingleNibble::UInt64 = UInt64(0x8)        # 1000

const SignalDependenciesProps_IsIntermediateMask_AllNibbles::UInt64 = UInt64(0x1111_1111_1111_1111)
const SignalDependenciesProps_IsWeakMask_AllNibbles::UInt64 = UInt64(0x2222_2222_2222_2222)
const SignalDependenciesProps_IsComputedMask_AllNibbles::UInt64 = UInt64(0x4444_4444_4444_4444)
const SignalDependenciesProps_IsFreshMask_AllNibbles::UInt64 = UInt64(0x8888_8888_8888_8888)

# Target pattern if all dependency checks (C & (W | F)) pass for all 16 nibbles in a full chunk,
# assuming the result (0 or 1 for each nibble) is aligned to the LSB of its conceptual 4-bit slot.
const SignalDependenciesProps_AllNibblesPassTarget::UInt64 = UInt64(0x1111_1111_1111_1111)

# This function returns the chunk index and the offset within the chunk for the given index
@inline function signal_dependencies_props_get_offset(index::Int)
    chunk_index = div(index - 1, 16) + 1
    offset_within_chunk = mod(index - 1, 16) << 2
    return (chunk_index, offset_within_chunk)
end

# This function adds a dependency to the signal dependencies props with a default (zeroed) nibble
function add_dependency!(props::SignalDependenciesProps)
    newlength = (props.length += 1)
    chunks = props.chunks

    # we need 4 bits per nibble
    nrequiredbits = 4 * newlength
    # we have 64 bits per chunk
    nrequiredchunks = div(nrequiredbits - 1, 64) + 1

    nchunks = length(chunks)
    if nchunks < nrequiredchunks
        push!(chunks, UInt64(0))
    end

    return newlength
end

@inline function is_dependency(props::SignalDependenciesProps, index::Int, mask::UInt64)::Bool
    chunk_index, offset_within_chunk = signal_dependencies_props_get_offset(index)
    return @inbounds(props.chunks[chunk_index] & (mask << offset_within_chunk)) != 0
end

@inline is_dependency_intermediate(props::SignalDependenciesProps, index::Int)::Bool = is_dependency(
    props, index, SignalDependenciesProps_IsIntermediateMask_SingleNibble
)

@inline is_dependency_weak(props::SignalDependenciesProps, index::Int)::Bool = is_dependency(
    props, index, SignalDependenciesProps_IsWeakMask_SingleNibble
)

@inline is_dependency_computed(props::SignalDependenciesProps, index::Int)::Bool = is_dependency(
    props, index, SignalDependenciesProps_IsComputedMask_SingleNibble
)

@inline is_dependency_fresh(props::SignalDependenciesProps, index::Int)::Bool = is_dependency(
    props, index, SignalDependenciesProps_IsFreshMask_SingleNibble
)

@inline function set_dependency!(props::SignalDependenciesProps, index::Int, mask::UInt64)
    chunk_index, offset_within_chunk = signal_dependencies_props_get_offset(index)
    @inbounds props.chunks[chunk_index] |= (mask << offset_within_chunk)
    return nothing
end

@inline set_dependency_intermediate!(props::SignalDependenciesProps, index::Int) = set_dependency!(
    props, index, SignalDependenciesProps_IsIntermediateMask_SingleNibble
)

@inline set_dependency_weak!(props::SignalDependenciesProps, index::Int) = set_dependency!(
    props, index, SignalDependenciesProps_IsWeakMask_SingleNibble
)

@inline set_dependency_computed!(props::SignalDependenciesProps, index::Int) = set_dependency!(
    props, index, SignalDependenciesProps_IsComputedMask_SingleNibble
)

@inline set_dependency_fresh!(props::SignalDependenciesProps, index::Int) = set_dependency!(
    props, index, SignalDependenciesProps_IsFreshMask_SingleNibble
)

@inline function unset_dependency!(props::SignalDependenciesProps, index::Int, mask::UInt64)
    chunk_index, offset_within_chunk = signal_dependencies_props_get_offset(index)
    @inbounds props.chunks[chunk_index] &= ~(mask << offset_within_chunk)
    return nothing
end

@inline unset_dependency_intermediate!(props::SignalDependenciesProps, index::Int) = unset_dependency!(
    props, index, SignalDependenciesProps_IsIntermediateMask_SingleNibble
)

@inline unset_dependency_weak!(props::SignalDependenciesProps, index::Int) = unset_dependency!(
    props, index, SignalDependenciesProps_IsWeakMask_SingleNibble
)

@inline unset_dependency_computed!(props::SignalDependenciesProps, index::Int) = unset_dependency!(
    props, index, SignalDependenciesProps_IsComputedMask_SingleNibble
)

@inline unset_dependency_fresh!(props::SignalDependenciesProps, index::Int) = unset_dependency!(
    props, index, SignalDependenciesProps_IsFreshMask_SingleNibble
)

@inline function set_all_dependencies!(props::SignalDependenciesProps, mask::UInt64)
    for i in eachindex(props.chunks)
        @inbounds props.chunks[i] |= mask
    end
    return nothing
end

@inline set_all_dependencies_intermediate!(props::SignalDependenciesProps) = set_all_dependencies!(
    props, SignalDependenciesProps_IsIntermediateMask_AllNibbles
)

@inline set_all_dependencies_weak!(props::SignalDependenciesProps) = set_all_dependencies!(
    props, SignalDependenciesProps_IsWeakMask_AllNibbles
)

@inline set_all_dependencies_computed!(props::SignalDependenciesProps) = set_all_dependencies!(
    props, SignalDependenciesProps_IsComputedMask_AllNibbles
)

@inline set_all_dependencies_fresh!(props::SignalDependenciesProps) = set_all_dependencies!(
    props, SignalDependenciesProps_IsFreshMask_AllNibbles
)

@inline function unset_all_dependencies!(props::SignalDependenciesProps, mask::UInt64)
    for i in eachindex(props.chunks)
        @inbounds props.chunks[i] &= ~mask
    end
    return nothing
end

@inline unset_all_dependencies_intermediate!(props::SignalDependenciesProps) = unset_all_dependencies!(
    props, SignalDependenciesProps_IsIntermediateMask_AllNibbles
)

@inline unset_all_dependencies_weak!(props::SignalDependenciesProps) = unset_all_dependencies!(
    props, SignalDependenciesProps_IsWeakMask_AllNibbles
)

@inline unset_all_dependencies_computed!(props::SignalDependenciesProps) = unset_all_dependencies!(
    props, SignalDependenciesProps_IsComputedMask_AllNibbles
)

@inline unset_all_dependencies_fresh!(props::SignalDependenciesProps) = unset_all_dependencies!(
    props, SignalDependenciesProps_IsFreshMask_AllNibbles
)

# is_meeting_pending_criteria(props::SignalDependenciesProps) -> Bool
#
# Checks if the set of dependencies represented by `props` meets the criteria for the owning signal to be pending.
# Returns `true` if and only if for **every** dependency `dep_i` tracked in `props`:
#
# `(IsComputed(dep_i) AND (IsWeak(dep_i) OR IsFresh(dep_i)))` is true.
#
# If `props.length` is 0, it returns `false` (as a signal with no dependencies cannot be pending based on them).
#
# The check is performed efficiently using bitwise operations on `UInt64` chunks, where each chunk stores
# the properties for 16 dependencies.
@inline function is_meeting_pending_criteria(props::SignalDependenciesProps)
    ndependencies = props.length

    if ndependencies == 0
        return false
    end

    chunks = props.chunks
    nchunks = length(chunks)

    for i in 1:(nchunks - 1)
        @inbounds chunk = chunks[i]
        # These shifts align the specific property bit (W, C, or F) from each of the 16 nibbles
        # to the LSB position of where a conceptual 4-bit status group would start (e.g., bit 0, 4, 8,...).
        # This allows for parallel bitwise operations across all nibbles.
        # Original nibble structure within the chunk: F C W I (MSB to LSB: b3 b2 b1 b0)
        # After (chunk & MASK_W) >> 1 : all W bits are effectively at b0 of their group.
        # After (chunk & MASK_C) >> 2 : all C bits are effectively at b0 of their group.
        # After (chunk & MASK_F) >> 3 : all F bits are effectively at b0 of their group.
        W_bits = (chunk & SignalDependenciesProps_IsWeakMask_AllNibbles) >> 1
        C_bits = (chunk & SignalDependenciesProps_IsComputedMask_AllNibbles) >> 2
        F_bits = (chunk & SignalDependenciesProps_IsFreshMask_AllNibbles) >> 3

        # For each dependency i: Pass_i = C_i & (W_i | F_i).
        # This is performed for all 16 dependencies in the chunk in parallel.
        # If all pass, pass_results_for_chunk will equal SignalDependenciesProps_AllNibblesPassTarget.
        pass_results_for_chunk = C_bits & (W_bits | F_bits)
        if pass_results_for_chunk != SignalDependenciesProps_AllNibblesPassTarget
            return false
        end
    end

    # --- Handle the last chunk (which might be partially filled) ---
    # The strategy is to create a temporary version of the last chunk where all unused
    # higher-order nibbles are forced to a state that passes the C & (W | F) check.
    # This allows the use of SignalDependenciesProps_AllNibblesPassTarget for the final comparison.

    # Get the bit offset of the LSB of the last *used* nibble in the last chunk.
    # If length = 1, offset_of_last_nibble_lsb = 0.
    # If length = 16 (full chunk), offset_of_last_nibble_lsb = 60.
    _chunk_idx_of_last_dep, offset_of_last_nibble_lsb = signal_dependencies_props_get_offset(ndependencies)

    # Create a mask that, when ORed, sets all bits of unused higher nibbles to 1.
    # (offset_of_last_nibble_lsb + 4) is the bit position immediately *after* the last used nibble.
    # Shifting 0xFFFF... left by this amount makes all higher bits 1 (and lower bits 0).
    # Example: For 1 dependency, offset_of_last_nibble_lsb = 0. Mask sets bits from position 4 upwards.
    # If the chunk is full (e.g., 16 dependencies), offset_of_last_nibble_lsb = 60.
    # Then (offset_of_last_nibble_lsb + 4) = 64. (0xFFFF... << 64) = 0. So, no change for a full chunk.
    mask_to_make_unused_nibbles_pass = 0xffff_ffff_ffff_ffff << (offset_of_last_nibble_lsb + 4)
    @inbounds modified_last_chunk = chunks[_chunk_idx_of_last_dep] | mask_to_make_unused_nibbles_pass

    # Apply the same parallel check logic to the modified last chunk.
    W_bits_last = (modified_last_chunk & SignalDependenciesProps_IsWeakMask_AllNibbles) >> 1
    C_bits_last = (modified_last_chunk & SignalDependenciesProps_IsComputedMask_AllNibbles) >> 2
    F_bits_last = (modified_last_chunk & SignalDependenciesProps_IsFreshMask_AllNibbles) >> 3
    pass_results_last_chunk = C_bits_last & (W_bits_last | F_bits_last)

    if pass_results_last_chunk != SignalDependenciesProps_AllNibblesPassTarget
        return false
    end

    return true
end
