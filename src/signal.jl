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
    age::UInt64

    weakmask::BitVector
    intermediatemask::BitVector
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
            UInt64(0),
            falses(0),
            falses(0),
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
            false,
            false,
            UInt64(1),
            falses(0),
            falses(0),
            Vector{Signal}(),
            trues(0),
            Vector{Signal}()
        )
    end
end

"""
    is_pending(s::Signal) -> Bool

Check if the signal `s` is marked as pending.
"""
function is_pending(s::Signal)::Bool
    check_and_set_pending!(s)
    return s.is_pending
end

"""
    is_computed(s::Signal) -> Bool

Check if the signal `s` has been computed (i.e., its value has been set at least once).
This is determined by checking if `get_age(s) > 0`.
"""
function is_computed(s::Signal)::Bool
    return s.age > 0
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
    get_age(s::Signal) -> UInt64

Get the current age of the signal `s`.
The age increments each time `set_value!` is called. 
However, the amount of the increment is not fixed and should not be relied upon.
"""
function get_age(s::Signal)::UInt64
    return s.age
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
Some of the active listeners might become pending.
"""
function set_value!(s::Signal, @nospecialize(value))
    # We update the age of the signal to the maximum age of its dependencies plus 1
    # If the signal has no dependencies, we simply take the age of the signal and add 2
    # Interpret it as if the signal had actually a "ghost" dependency with an age equal to the `s.age + 1` 
    # thus the new age becomes `(s.age + 1) + 1`
    next_age = isempty(get_dependencies(s)) ? s.age + UInt64(2) : maximum(d -> get_age(d), s.dependencies) + UInt64(1)
    s.age = next_age

    # We update the value of the signal
    s.value = value

    # We unset the pending flag
    s.is_pending = false
    s.is_potentially_pending = false

    # We notify all the signals that listen to this signal that it has been updated
    # We only notify the signals that are listening to the current signal
    for (is_listening, listener) in zip(s.listenmask, s.listeners)
        if is_listening
            set_potentially_pending!(listener)
        end
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

    # If the dependency is weak, 
    # we store `true` in the weakmask, `false` otherwise
    if weak
        push!(signal.weakmask, true)
    else
        push!(signal.weakmask, false)
    end

    # If the dependency is intermediate, 
    # we store `true` in the intermediatemask, `false` otherwise
    if intermediate
        push!(signal.intermediatemask, true)
    else
        push!(signal.intermediatemask, false)
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
    is_dependency_computed = is_computed(dependency)
    if check_computed && is_dependency_computed
        set_potentially_pending!(signal)
    elseif check_computed && !is_dependency_computed
        signal.is_pending = false
    end

    return nothing
end

function set_potentially_pending!(signal::Signal)
    signal.is_potentially_pending = true
end

function check_and_set_pending!(signal::Signal)
    # If the listener is not potentially pending, we do nothing
    # as there is nothing to check and set
    if !signal.is_potentially_pending
        return nothing
    end

    # If it was potentially pending, we set it to false
    # since no matter what the outcome of the check is, 
    # it will either be set pending to true and if not, 
    # then it is not potentially pending anyway
    signal.is_potentially_pending = false

    listener_age = get_age(signal)
    # If notified, the listener will check its own dependencies 
    # to see if it needs to update its own `pending` state
    # The condition is that all weak dependencies are computed,
    # and all non-weak dependencies are older than the listener
    should_update_pending = all(zip(signal.weakmask, signal.dependencies)) do (is_weak, dependency)
        return !is_computed(dependency) ? false : (is_weak ? true : get_age(dependency) > listener_age)
    end

    if should_update_pending
        signal.is_pending = true
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
    all_processed = true
    for (is_intermediate, dependency) in zip(signal.intermediatemask, dependencies)
        processed = f(dependency)
        if is_intermediate && !processed
            intermediate_all_processed = process_dependencies!(f, dependency; retry = retry)
            if intermediate_all_processed && retry
                processed = f(dependency)
            end
        end
        all_processed = all_processed && processed
    end
    return all_processed
end
