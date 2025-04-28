
"""
    InterfaceNotImplementedError(object, interface, method)

An error that is thrown when an `object` does not implement a required `method`, required by the `interface`.
"""
struct InterfaceNotImplementedError <: Exception
    object
    interface
    method
end

function Base.showerror(io::IO, e::InterfaceNotImplementedError)
    print(
        io,
        "An object of type `$(typeof(e.object))` does not implement the method `$(e.method)`, which is required by the interface of `$(e.interface)`."
    )
end

"""

Required methods to implement: 
- `getname`
- `getindex`
- `getdisplayname`
- `getmarginal`

"""
abstract type AbstractVariable end

"""
    getname(v::AbstractVariable)

Get the name of the variable. This function must be implemented by all subtypes of `AbstractVariable`.

See also: [`AbstractVariable`](@ref), [`getdisplayname`](@ref), [`getindex`](@ref), [`getmarginal`](@ref)
"""
getname(v::AbstractVariable) = throw(InterfaceNotImplementedError(v, AbstractVariable, :getname))

"""
    getindex(v::AbstractVariable)

Get the index of the variable. This function must be implemented by all subtypes of `AbstractVariable`.

See also: [`AbstractVariable`](@ref), [`getdisplayname`](@ref), [`getindex`](@ref), [`getmarginal`](@ref)
"""
getindex(v::AbstractVariable) = throw(InterfaceNotImplementedError(v, AbstractVariable, :getindex))

"""
    getdisplayname(v::AbstractVariable)

Get the display name of the variable. This function must be implemented by all subtypes of `AbstractVariable`.

See also: [`AbstractVariable`](@ref), [`getname`](@ref), [`getindex`](@ref), [`getmarginal`](@ref)
"""
getdisplayname(v::AbstractVariable) = throw(InterfaceNotImplementedError(v, AbstractVariable, :getdisplayname))

"""
    getmarginal(v::AbstractVariable)::Value

Get the marginal distribution of the variable. This function must be implemented by all subtypes of `AbstractVariable`.
Must return a [`Value`](@ref) object.

See also: [`Value`](@ref), [`AbstractVariable`](@ref), [`getname`](@ref), [`getindex`](@ref), [`getdisplayname`](@ref)
"""
getmarginal(v::AbstractVariable) = throw(InterfaceNotImplementedError(v, AbstractVariable, :getmarginal))

struct VariableData
    # The variable data includes the latest computed marginal distribution of the variable
    # As well as the pending state of the variable (which was previously reffered to as `EqualityNodeChain`)
    # The purpose of the pending group is to track which messages are pending for the variable (both inbound and outbound, hence dual)
    marginal::Value
    pending::DualPendingGroup

    VariableData() = new(Value(), DualPendingGroup(0))
end

function Base.show(io::IO, vd::VariableData)
    print(io, "VariableData(marginal=$(vd.marginal))")
end

struct FactorNodeData
end

struct EdgeData
    # The edge data includes the message from the factor to the variable and the message from the variable to the factor
    # For convenience, the struct also provides methods `message_from_variable` and `message_from_factor` that mirror 
    # the `message_to_factor` and `message_to_variable` properties, respectively.
    message_to_variable::Value
    message_to_factor::Value
end