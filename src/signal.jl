"""
    UndefValue

A singleton type used to represent an undefined or uninitialized state within a [`Signal`](@ref).
This indicates that the signal has not yet been computed or has been invalidated.
"""
struct UndefValue end

"""
    UndefMetadata

A singleton type used to represent undefined metadata within a [`Signal`](@ref).
"""
struct UndefMetadata end

# Stores properties of a `Signal`'s dependencies in a bit-packed format.
#
# Each dependency's properties are stored in 4 bits within a `UInt64` chunk. Therefore, each `UInt64` chunk can store properties for 16 dependencies.
#
# The 4 bits for each dependency are used as follows (from LSB to MSB):
# - Bit 1 (Mask `0x1`): `IsIntermediate` - Indicates if the dependency is intermediate.
# - Bit 2 (Mask `0x2`): `IsWeak` - Indicates if the dependency is weak.
# - Bit 3 (Mask `0x4`): `IsComputed` - Indicates if the dependency's value has been computed.
# - Bit 4 (Mask `0x8`): `IsFresh` - Indicates if the dependency has a new, fresh value.
#
# !!! warning
#     This is an internal type and should not be used directly. Use the functions defined in the `Signal` structure instead.
#     This structure can be removed in the future.
mutable struct SignalDependenciesProps
    ndependencies::Int
    const chunks::Vector{UInt64}
end

function SignalDependenciesProps()
    return SignalDependenciesProps(0, UInt64[])
end

const SignalDependenciesProps_IsIntermediateMask_SingleNibble::UInt64 = 0x1 # 0001
const SignalDependenciesProps_IsWeakMask_SingleNibble::UInt64 = 0x2         # 0010
const SignalDependenciesProps_IsComputedMask_SingleNibble::UInt64 = 0x4     # 0100
const SignalDependenciesProps_IsFreshMask_SingleNibble::UInt64 = 0x8        # 1000

const SignalDependenciesProps_IsIntermediateMask_AllNibbles::UInt64 = 0x1111_1111_1111_1111
const SignalDependenciesProps_IsWeakMask_AllNibbles::UInt64 = 0x2222_2222_2222_2222
const SignalDependenciesProps_IsComputedMask_AllNibbles::UInt64 = 0x4444_4444_4444_4444
const SignalDependenciesProps_IsFreshMask_AllNibbles::UInt64 = 0x8888_8888_8888_8888

function signal_dependencies_props_get_offset(index::Int)
    chunk_index = div(index - 1, 16) + 1
    offset_within_chunk = mod(index - 1, 16) << 2
    return (chunk_index, offset_within_chunk)
end

function add_dependency!(props::SignalDependenciesProps)
    props.ndependencies += 1

    # we need 4 bits per nibble
    nrequiredbits = 4 * props.ndependencies
    # we have 64 bits per chunk
    nrequiredchunks = div(nrequiredbits - 1, 64) + 1

    nchunks = length(props.chunks)
    if nchunks < nrequiredchunks
        push!(props.chunks, UInt64(0))
    end

    return props.ndependencies
end

function is_dependency_intermediate(props::SignalDependenciesProps, index::Int)
    chunk_index, offset_within_chunk = signal_dependencies_props_get_offset(index)
    return (
        props.chunks[chunk_index] & (SignalDependenciesProps_IsIntermediateMask_SingleNibble << offset_within_chunk)
    ) != 0
end

function is_dependency_weak(props::SignalDependenciesProps, index::Int)
    chunk_index, offset_within_chunk = signal_dependencies_props_get_offset(index)
    return (props.chunks[chunk_index] & (SignalDependenciesProps_IsWeakMask_SingleNibble << offset_within_chunk)) != 0
end

function is_dependency_computed(props::SignalDependenciesProps, index::Int)
    chunk_index, offset_within_chunk = signal_dependencies_props_get_offset(index)
    return (props.chunks[chunk_index] & (SignalDependenciesProps_IsComputedMask_SingleNibble << offset_within_chunk)) !=
           0
end

function is_dependency_fresh(props::SignalDependenciesProps, index::Int)
    chunk_index, offset_within_chunk = signal_dependencies_props_get_offset(index)
    return (props.chunks[chunk_index] & (SignalDependenciesProps_IsFreshMask_SingleNibble << offset_within_chunk)) != 0
end

function set_dependency_intermediate!(props::SignalDependenciesProps, index::Int)
    chunk_index, offset_within_chunk = signal_dependencies_props_get_offset(index)
    props.chunks[chunk_index] |= (SignalDependenciesProps_IsIntermediateMask_SingleNibble << offset_within_chunk)
    return nothing
end

function set_dependency_weak!(props::SignalDependenciesProps, index::Int)
    chunk_index, offset_within_chunk = signal_dependencies_props_get_offset(index)
    props.chunks[chunk_index] |= (SignalDependenciesProps_IsWeakMask_SingleNibble << offset_within_chunk)
    return nothing
end

function set_dependency_computed!(props::SignalDependenciesProps, index::Int)
    chunk_index, offset_within_chunk = signal_dependencies_props_get_offset(index)
    props.chunks[chunk_index] |= (SignalDependenciesProps_IsComputedMask_SingleNibble << offset_within_chunk)
    return nothing
end

function set_dependency_fresh!(props::SignalDependenciesProps, index::Int)
    chunk_index, offset_within_chunk = signal_dependencies_props_get_offset(index)
    props.chunks[chunk_index] |= (SignalDependenciesProps_IsFreshMask_SingleNibble << offset_within_chunk)
    return nothing
end

function unset_dependency_intermediate!(props::SignalDependenciesProps, index::Int)
    chunk_index, offset_within_chunk = signal_dependencies_props_get_offset(index)
    props.chunks[chunk_index] &= ~(SignalDependenciesProps_IsIntermediateMask_SingleNibble << offset_within_chunk)
    return nothing
end

function unset_dependency_weak!(props::SignalDependenciesProps, index::Int)
    chunk_index, offset_within_chunk = signal_dependencies_props_get_offset(index)
    props.chunks[chunk_index] &= ~(SignalDependenciesProps_IsWeakMask_SingleNibble << offset_within_chunk)
    return nothing
end

function unset_dependency_computed!(props::SignalDependenciesProps, index::Int)
    chunk_index, offset_within_chunk = signal_dependencies_props_get_offset(index)
    props.chunks[chunk_index] &= ~(SignalDependenciesProps_IsComputedMask_SingleNibble << offset_within_chunk)
    return nothing
end

function unset_dependency_fresh!(props::SignalDependenciesProps, index::Int)
    chunk_index, offset_within_chunk = signal_dependencies_props_get_offset(index)
    props.chunks[chunk_index] &= ~(SignalDependenciesProps_IsFreshMask_SingleNibble << offset_within_chunk)
    return nothing
end

function unset_all_fresh!(props::SignalDependenciesProps)
    for i in eachindex(props.chunks)
        props.chunks[i] &= ~SignalDependenciesProps_IsFreshMask_AllNibbles
    end
    return nothing
end

function is_pending(props::SignalDependenciesProps)
    if props.ndependencies == 0
        return false
    end

    for i in 1:(length(props.chunks) - 1)
        @inbounds chunk = props.chunks[i]
        chunk_Weak = (chunk & SignalDependenciesProps_IsWeakMask_AllNibbles) >> 1
        chunk_Computed = (chunk & SignalDependenciesProps_IsComputedMask_AllNibbles) >> 2
        chunk_Fresh = (chunk & SignalDependenciesProps_IsFreshMask_AllNibbles) >> 3
        chunk_Result = chunk_Computed & (chunk_Weak | chunk_Fresh)
        if chunk_Result != 0x1111_1111_1111_1111
            return false
        end
    end

    _, last_offset = signal_dependencies_props_get_offset(props.ndependencies)
    last_chunk_mask = 0xffff_ffff_ffff_ffff << (last_offset + 4)
    last_chunk = props.chunks[end] | last_chunk_mask

    last_chunk_Weak = (last_chunk & SignalDependenciesProps_IsWeakMask_AllNibbles) >> 1
    last_chunk_Computed = (last_chunk & SignalDependenciesProps_IsComputedMask_AllNibbles) >> 2
    last_chunk_Fresh = (last_chunk & SignalDependenciesProps_IsFreshMask_AllNibbles) >> 3
    last_chunk_Result = last_chunk_Computed & (last_chunk_Weak | last_chunk_Fresh)
    if last_chunk_Result != 0x1111_1111_1111_1111
        return false
    end

    return true
end

"""
    Signal()
    Signal(value; type::UInt8 = 0x00, metadata::Any = UndefMetadata())

A reactive signal that holds a value and tracks dependencies as well as notifies listeners when the value changes.
If created without an initial value, the signal is initialized with [`UndefValue()`](@ref).

A signal is said to be 'pending' if it is ready for potential recomputation (due to updated dependencies).
However, a signal is not recomputed immediately when it becomes pending. Moreover, a Signal does not know 
how to recompute itself. The recomputation logic is defined separately with the [`compute!`](@ref) function.

Signals form a directed graph where edges represent dependencies.
When a signal's value is updated via [`set_value!`](@ref), it notifies its active listeners.

A signal may become 'pending' if all its dependencies meet the following criteria:
- all its weak dependencies have computed values, AND
- all its strong dependencies have computed values and are older than the listener.

A signal can depend on another signal without listening to it, see [`add_dependency!`](@ref) for more details.

See also:
- [`add_dependency!`](@ref): Establishes a dependency relationship between signals.
- [`set_value!`](@ref): Updates the signal's value and notifies listeners.
- [`compute!`](@ref): Function responsible for recomputing a signal's value.
- [`is_pending`](@ref): Checks if the signal is marked for potential recomputation.
- [`is_computed`](@ref): Checks if the signal currently holds a computed value (not `UndefValue`).
- [`get_value`](@ref): Retrieves the current value stored in the signal.
- [`get_type`](@ref): Retrieves the type identifier of the signal.
- [`get_metadata`](@ref): Retrieves the metadata associated with the signal.
- [`get_age`](@ref): Gets the computation age of the signal.
- [`get_dependencies`](@ref): Returns the list of signals this signal depends on.
- [`get_listeners`](@ref): Returns the list of signals that listen to this signal.
"""
mutable struct Signal
    value::Any
    metadata::Any

    type::UInt8
    is_potentially_pending::Bool
    is_pending::Bool

    dependencies_props::SignalDependenciesProps
    dependencies::Vector{Signal}

    listenmask::BitVector
    listeners::Vector{Signal}

    # Constructor for creating an empty signal
    function Signal(; type::UInt8 = 0x00, metadata::Any = UndefMetadata())
        return new(
            UndefValue(),
            metadata,
            type,
            false,
            false,
            SignalDependenciesProps(),
            Vector{Signal}(),
            trues(0),
            Vector{Signal}()
        )
    end

    # Constructor for creating a new signal with a value
    function Signal(value::Any; type::UInt8 = 0x00, metadata::Any = UndefMetadata())
        return new(
            value, metadata, type, false, false, SignalDependenciesProps(), Vector{Signal}(), trues(0), Vector{Signal}()
        )
    end
end

"""
    is_pending(s::Signal) -> Bool

Check if the signal `s` is marked as pending.
"""
function is_pending(s::Signal)::Bool
    # In case if the signal is potentially pending, we need to check if it is actually pending or not
    # and reset the potential pending state
    if s.is_potentially_pending
        s.is_pending = is_pending(s.dependencies_props)
        s.is_potentially_pending = false
    end
    return s.is_pending
end

"""
    is_computed(s::Signal) -> Bool

Check if the signal `s` has been computed (i.e., its value has been set at least once).
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
Defaults to `UndefMetadata()` if not specified during construction.
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
"""
function set_value!(signal::Signal, @nospecialize(value))

    # We update the value of the signal
    signal.value = value
    signal.is_potentially_pending = false
    signal.is_pending = false

    unset_all_fresh!(signal.dependencies_props)

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
        signal.is_potentially_pending = true
        signal.is_pending = false
    elseif check_computed && !is_computed(dependency)
        signal.is_potentially_pending = false
        signal.is_pending = false
    end

    return nothing
end

function notify_listener!(listener::Signal, signal::Signal; update_potentially_pending::Bool = false)
    if update_potentially_pending
        listener.is_potentially_pending = true
    end

    # Technically we can stop early here, but we allow duplicate dependencies
    # and also test against it, we can relax this?
    for i in 1:length(listener.dependencies)
        @inbounds dependency = listener.dependencies[i]
        if (dependency === signal)
            set_dependency_fresh!(listener.dependencies_props, i)
            set_dependency_computed!(listener.dependencies_props, i)
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
    if meta !== UndefMetadata()                                     # Check against UndefMetadata
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
    if !is_pending(signal) && !force
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

function process_dependencies!(f::F, signal::Signal; retry::Bool = false) where {F}
    dependencies = get_dependencies(signal)
    processed_at_least_once = false
    for index in 1:length(dependencies)
        dependency = @inbounds dependencies[index]
        is_intermediate = is_dependency_intermediate(signal.dependencies_props, index)
        processed = f(dependency)
        if is_intermediate && !processed
            intermediate_processed_at_least_once = process_dependencies!(f, dependency; retry = retry)
            if intermediate_processed_at_least_once && retry
                processed = f(dependency)
            end
            processed_at_least_once = processed_at_least_once || intermediate_processed_at_least_once
        end
        processed_at_least_once = processed_at_least_once || processed
    end
    return processed_at_least_once
end
