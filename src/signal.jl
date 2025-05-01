# A singleton type to represent an undefined value in a Signal
struct UndefValue end

mutable struct Signal
    value::Any
    is_pending::Bool
    age::UInt64

    weakmask::BitVector
    dependencies::Vector{Signal}

    listeners::Vector{Signal}

    # Constructor for creating an empty signal
    function Signal()
        # Initialize with the UndefValue() singleton, age 0
        new(UndefValue(), false, 0, falses(0), Vector{Signal}(), Vector{Signal}())
    end

    # Constructor for creating a new signal with a value
    function Signal(value::Any)
        # Initialize with the given value, age 1
        new(value, false, 1, falses(0), Vector{Signal}(), Vector{Signal}())
    end
end

function set_pending!(s::Signal)
    s.is_pending = true
end

function unset_pending!(s::Signal)
    s.is_pending = false
end

function is_pending(s::Signal)
    return s.is_pending
end

function is_computed(s::Signal)
    return s.age > 0
end

"""
    get_value(s::Signal)

Get the current value of the signal.
"""
function get_value(s::Signal)
    return s.value
end

"""
    get_age(s::Signal)

Get the current age of the signal (number of times its value has been set).
"""
function get_age(s::Signal)
    return s.age
end

"""
    get_dependencies(s::Signal)

Get the list of signals that this signal depends on.
"""
function get_dependencies(s::Signal)
    return s.dependencies
end

"""
    get_listeners(s::Signal)

Get the list of signals that listen to this signal (i.e., depend on it).
"""
function get_listeners(s::Signal)
    return s.listeners
end

"""
    set_value!(s::Signal, value::Any)

Set the value of a signal.
"""
function set_value!(s::Signal, value::Any)
    # We update the age of the signal to the maximum age of its dependencies plus 1
    # If the signal has no dependencies, we simply take the age of the signal and add 2
    # Interpret it as if the signal had actually a "ghost" dependency with an age equal to the `s.age + 1` 
    # thus the new age becomes `(s.age + 1) + 1`
    next_age = isempty(get_dependencies(s)) ? s.age + 2 : maximum(d -> get_age(d), s.dependencies) + 1
    s.age = next_age

    # We update the value of the signal
    s.value = value

    # We unset the pending flag
    s.is_pending = false

    # We notify all the signals that listen to this signal that it has been updated
    for listener in s.listeners
        check_and_set_pending!(s, listener)
    end

    return nothing
end

function add_dependency!(s::Signal, dependency::Signal; weak::Bool = false)
    # We check that the dependency is not the same signal
    if s === dependency
        return nothing
    end

    # If the dependency is weak, we store `true` in the weakmask, `false` otherwise
    if weak
        push!(s.weakmask, true)
    else
        push!(s.weakmask, false)
    end

    push!(s.dependencies, dependency)
    push!(dependency.listeners, s)

    # If a new dependency has been added and this new dependency has already been computed,
    # we immediately notify the current signal `s` as if it was already subscribed to the changes
    if is_computed(dependency)
        check_and_set_pending!(dependency, s)
    end

    return nothing
end

function check_and_set_pending!(notifier::Signal, listener::Signal)
    listener_age = get_age(listener)
    # If notified, the listener will check its own dependencies 
    # to see if it needs to update its own `pending` state
    # The condition is that all weak dependencies are computed,
    # and all non-weak dependencies are older than the listener
    should_update_pending = all(zip(listener.weakmask, listener.dependencies)) do (is_weak, dependency)
        return !is_computed(dependency) ? false : (is_weak ? true : get_age(dependency) > listener_age)
    end
    if should_update_pending
        set_pending!(listener)
    end
    return nothing
end
