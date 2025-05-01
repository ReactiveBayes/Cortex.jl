
Base.show(io::IO, ::UndefValue) = print(io, "#undef")

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
    return value
end

function Base.show(io::IO, value::Value)
    print(io, "Value(", value.value, ", pending=", value.is_pending, ", computed=", value.is_computed, ")")
end
