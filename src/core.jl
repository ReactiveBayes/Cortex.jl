
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
- `ispending`: whether the value can be updated
- `iscomputed`: whether the value has been computed and can be accessed

If the value is not yet computed, it is represented as [`UndefValue()`](@ref).

See also: [`ispending`](@ref), [`iscomputed`](@ref)
"""
mutable struct Value 
    value::Any
    ispending::Bool
    iscomputed::Bool
end

Value() = Value(UndefValue(), false, false)
Value(value) = Value(value, false, true)

"""
    ispending(value::Value)

Returns `true` if the value is pending, `false` otherwise.

See also: [`iscomputed`](@ref)
"""
ispending(value::Value) = value.ispending

"""
    iscomputed(value::Value)

Returns `true` if the value has been computed, `false` otherwise.

See also: [`ispending`](@ref)
"""
iscomputed(value::Value) = value.iscomputed

"""
    setpending!(value::Value)

Sets the value to pending.

See also: [`ispending`](@ref), [`iscomputed`](@ref)
"""
function setpending!(value::Value)
    value.ispending = true
    value.iscomputed = false
end

"""
    setvalue!(value::Value, value)

Sets the value of the value.

See also: [`ispending`](@ref), [`iscomputed`](@ref)
"""
function setvalue!(value::Value, @nospecialize(val))
    value.value = val
    value.ispending = false
    value.iscomputed = true
end

function Base.show(io::IO, value::Value)
    print(io, "Value(", value.value, ", pending=", value.ispending, ", computed=", value.iscomputed, ")")
end
