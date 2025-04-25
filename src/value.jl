"""
    UndefValue

A placeholder value that represents a value that is not yet computed.
"""
struct UndefValue end

Base.show(io::IO, value::UndefValue) = print(io, "#undef")

"""
    Value([ value ])

A data structure that can hold any value. 
Additionally, holds metadata about the value, such as
- `is_pending`: whether the value can be updated
- `is_computed`: whether the value has been computed and can be accessed

If the value is not yet computed, it is represented as [`UndefValue()`](@ref).

See also: [`is_pending`](@ref), [`is_computed`](@ref)
"""
mutable struct Value
    value::Any
    is_pending::Bool
    is_computed::Bool
end

Value() = Value(UndefValue())
Value(value) = Value(value, false, true)
Value(::UndefValue) = Value(UndefValue(), false, false)

"""
    is_pending(value::Value)

Returns `true` if the value is pending, `false` otherwise.

See also: [`is_computed`](@ref)
"""
is_pending(value::Value) = value.is_pending

"""
    is_computed(value::Value)

Returns `true` if the value has been computed, `false` otherwise.

See also: [`is_pending`](@ref)
"""
is_computed(value::Value) = value.is_computed

"""
    set_pending!(value::Value)

Sets the value to pending.

See also: [`is_pending`](@ref), [`is_computed`](@ref)
"""
function set_pending!(value::Value)
    value.is_pending = true
    value.is_computed = false
end

"""
    unset_pending!(value::Value)

Unsets the pending status of the value.

See also: [`set_pending!`](@ref), [`is_pending`](@ref)
"""
function unset_pending!(value::Value)
    value.is_pending = false
end

"""
    set_value!(value::Value, value)

Sets the value of the value.

See also: [`is_pending`](@ref), [`is_computed`](@ref)
"""
function set_value!(value::Value, @nospecialize(val))
    value.value = val
    value.is_pending = false
    value.is_computed = true
end

function Base.show(io::IO, value::Value)
    print(io, "Value(", value.value, ", pending=", value.is_pending, ", computed=", value.is_computed, ")")
end

"""
    DualPendingGroup

A data structure designed to efficiently track and manage dual pending states in a message-passing style system.

# Concept
Each value in the group maintains two distinct pending states:
- Inbound pending: directly set from outside (like receiving a message)
- Outbound pending: automatically determined based on other values' states (like sending a message)

# Behavior
The dual pending states follow these rules:
- Inbound pending is explicitly set for each value
- Outbound pending for a value becomes true when ALL OTHER values are inbound pending
- A value's outbound state cannot be directly set, it is derived from others' inbound states

# Example
Consider a group of 3 values [A, B, C] with their states as (inbound, outbound):
```
Initial: 
A: (false, false), B: (false, false), C: (false, false)

Set A and B inbound pending:
A: (true, false), B: (true, false), C: (false, true)

Set C inbound pending:
A: (true, true), B: (true, true), C: (true, true)
```

This structure is particularly useful in message-passing algorithms where each node needs to track both 
incoming and outgoing message states, similar to variable nodes in factor graphs.
"""
mutable struct DualPendingGroup
    # The actual implementation operates on a series of chunks, each chunk is a UInt64
    # Inside of the chunk, we divide regions of 4 bits for each Value
    # UInt64 = [ 0000 ] [ 0100 ] [ 1100 ] ... and so on
    # The first bit is the `i` (inbound pending) state of the actual value
    # The second bit, which is `l`, reflects the combination of the `i` and `l` states of the previous value
    #     - if `i` of the previous value is false, then `l` is false
    #     - if `l` of the previous value is false, then `l` is false
    #     - if both `i` and `l` of the previous value are true, then `l` is true
    # The third bit, which is `r`, reflects the combination of the `i` and `r` states of the next value
    #     - if `i` of the next value is false, then `r` is false
    #     - if `r` of the next value is false, then `r` is false
    #     - if both `i` and `r` of the next value are true, then `r` is true
    # The fourth bit is reserved and is not used currently
    #    l     r  l     r  l     r  
    # ----| = |----| = |----| = |---- 
    #       |        |        |
    #      i        i        i
    # The outbound pending state `o` is computed as true, when both `l` and `r` are true
    # - for the first and last values, we assume that there is an imaginary value that is always true
    # The `o` is set to true, when the value is set to inbound pending
    len::Int
    groups::Vector{UInt64}
end

const _mask_inbound::UInt64 = UInt64(0b1000)
const _mask_left::UInt64 = UInt64(0b0100)
const _mask_right::UInt64 = UInt64(0b0010)

function DualPendingGroup(len::Int)
    len <= 1 && throw(ArgumentError("Length must be at least 2"))
    nrequiredbits = 4 * len
    nintegers = div(nrequiredbits, 64) + 1
    groups = zeros(UInt64, nintegers)
    return DualPendingGroup(len, groups)
end

Base.length(dpg::DualPendingGroup) = dpg.len

# Returns the index of the chunk for the value at index k
dpg_index(k::Int) = (((k << 2) - 1) >> 6) + 1
# Returns the offset within the chunk for the value at index k
dpg_offset(k::Int) = (((k << 2) - 1) & 63) - 3

# Returns the index of the chunk for the value at index k and the offset within the chunk
dpg_index_offset(k::Int) = (dpg_index(k), dpg_offset(k))

"""
    is_pending_in(dpg::DualPendingGroup, i::Int)

Check if the value at index i has its inbound pending state set.
"""
function is_pending_in(dpg::DualPendingGroup, k::Int)
    i, o = dpg_index_offset(k)
    mask = _mask_inbound << o
    return (dpg.groups[i] & mask) == mask
end

"""
    is_pending_out(dpg::DualPendingGroup, i::Int)

Check if the value at index i has its outbound pending state set.
The outbound state is true when all other values are inbound pending.
"""
function is_pending_out(dpg::DualPendingGroup, k::Int)
    i, o = dpg_index_offset(k)

    _ml = k == 1 ? UInt64(0) : _mask_left << o
    _mr = k == dpg.len ? UInt64(0) : _mask_right << o

    mask = _ml | _mr

    return (dpg.groups[i] & mask) == mask
end

"""
    set_pending!(dpg::DualPendingGroup, i::Int)

Set the inbound pending state for value i and update outbound states accordingly.
When a value is set to inbound pending, we need to check if this causes any other
values to become outbound pending (when all their other values are inbound pending).
"""
function set_pending!(dpg::DualPendingGroup, k::Int)
    # Get the index and offset for the current value
    i, o = dpg_index_offset(k)

    # Set the inbound pending bit for the current value
    dpg.groups[i] |= (_mask_inbound << o)

    # Propagate pending state to the right (higher indices)
    # This handles the case where setting this value to pending
    # causes values to its right to become outbound pending
    lk_index = k
    lk_marking = true
    while lk_marking
        lk_marking = mark_next_left(dpg, lk_index)
        lk_index += 1
    end

    # Propagate pending state to the left (lower indices)
    # This handles the case where setting this value to pending
    # causes values to its left to become outbound pending
    rk_index = k
    rk_marking = true
    while rk_marking
        rk_marking = mark_next_right(dpg, rk_index)
        rk_index -= 1
    end

    return dpg
end

# Marks the next `l`, returns true if it was marked, false otherwise
# the rules are the following:
# - if current `i` is false, then next `l` should not be marked
# - if current `l` is false, then next `l` should not be marked
# - if both current `i` and `l` are true, then next `l` should be marked as `true`
# The first index is special and does not check its current `l` state as there is no previous `l`
# Also returns false if the value has been marked already
function mark_next_left(dpg::DualPendingGroup, k::Int)
    # If we reached the last element, there is nothing to mark
    k == dpg.len && return false
    i, o = dpg_index_offset(k)
    
    _ml = k == 1 ? UInt64(0) : _mask_left << o
    _mi = _mask_inbound << o
    _m = _ml | _mi

    # If both `i` and `l` are true, then we need to mark the next `l`
    if (dpg.groups[i] & _m) == _m
        i_next, o_next = dpg_index_offset(k + 1)

        # First check if the next `l` has already been marked
        # If it has, then we do not need to mark it again and can return false
        _mask_left_next = _mask_left << o_next
        if (dpg.groups[i_next] & _mask_left_next) == _mask_left_next
            return false
        end

        # If the next `l` has not been marked, then mark it and return true
        dpg.groups[i_next] |= (_mask_left << o_next)
        return true
    end

    # Either one of `i` or `l` is false, so we do not need to mark anything
    return false
end

# Marks the next `r`, returns true if it was marked, false otherwise
# The rules are the following:
# - if current `i` is false, then previous `r` should not be marked
# - if current `r` is false, then previous `r` should not be marked
# - if both current `i` and `r` are true, then previous `r` should be marked as `true`
# The last index is special and does not check its current `r` state as there is no next `r`
# Also returns false if the value has been marked already
function mark_next_right(dpg::DualPendingGroup, k::Int)
    k == 1 && return false
    i, o = dpg_index_offset(k)

    _mr = k == dpg.len ? UInt64(0) : _mask_right << o
    _mi = _mask_inbound << o
    _m = _mr | _mi

    # If both `i` and `r` are true, then we need to mark the previous `r`
    if (dpg.groups[i] & _m) == _m
        i_next, o_next = dpg_index_offset(k - 1)

        # First check if the previous `r` has already been marked
        # If it has, then we do not need to mark it again and can return false
        _mask_right_next = _mask_right << o_next
        if (dpg.groups[i_next] & _mask_right_next) == _mask_right_next
            return false
        end

        # If the previous `r` has not been marked, then mark it and return true
        dpg.groups[i_next] |= (_mask_right << o_next)
        return true
    end

    # Either one of `i` or `r` is false, so we do not need to mark anything
    return false
end