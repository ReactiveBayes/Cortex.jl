
"""
    InterfaceNotImplementedError(object, interface, method)

An error that is thrown when an `object` does not implement a required `method`, enforced by the `interface`.
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
    AbstractVariable

An interface for a variable in a probabilistic graphical model. 
All subtypes must implement the following methods:
- [`get_name`](@ref)
- [`get_index`](@ref)
- [`get_display_name`](@ref)
- [`get_marginal`](@ref)

See the description of each individual method for more details.
"""
abstract type AbstractVariable end

"""
    get_name(v::AbstractVariable)

Get the name of the variable. 
This function must be implemented by all subtypes of `AbstractVariable`.

See also: [`AbstractVariable`](@ref), [`get_display_name`](@ref), [`get_index`](@ref), [`get_marginal`](@ref)
"""
get_name(v::AbstractVariable) = throw(InterfaceNotImplementedError(v, AbstractVariable, :get_name))

"""
    get_index(v::AbstractVariable)

Get the index of the variable. 
This function must be implemented by all subtypes of `AbstractVariable`.

See also: [`AbstractVariable`](@ref), [`get_display_name`](@ref), [`get_index`](@ref), [`get_marginal`](@ref)
"""
get_index(v::AbstractVariable) = throw(InterfaceNotImplementedError(v, AbstractVariable, :get_index))

"""
    get_display_name(v::AbstractVariable)

Get the display name of the variable. 
This function must be implemented by all subtypes of `AbstractVariable`.

See also: [`AbstractVariable`](@ref), [`get_name`](@ref), [`get_index`](@ref), [`get_marginal`](@ref)
"""
get_display_name(v::AbstractVariable) = throw(InterfaceNotImplementedError(v, AbstractVariable, :get_display_name))

"""
    get_marginal(v::AbstractVariable)::Value

Get the marginal distribution of the variable.
This function must be implemented by all subtypes of `AbstractVariable`.
Must return a [`Value`](@ref) object.

See also: [`Value`](@ref), [`AbstractVariable`](@ref), [`get_name`](@ref), [`get_index`](@ref), [`get_display_name`](@ref)
"""
get_marginal(v::AbstractVariable) = throw(InterfaceNotImplementedError(v, AbstractVariable, :get_marginal))

"""
    AbstractFactor

An interface for a factor in a probabilistic graphical model.
All subtypes must implement the following methods:
- [`get_function`](@ref)
- [`get_display_name`](@ref)
"""
abstract type AbstractFactor end

"""
    get_function(f::AbstractFactor)

Get the function of the factor.
This function must be implemented by all subtypes of `AbstractFactor`.

!!! note
    The function does not necessarily returns a `Function` object, but rather a "function" associated with the factor.
    For example, it can also be a type of a distribution.
"""
get_function(f::AbstractFactor) = throw(InterfaceNotImplementedError(f, AbstractFactor, :get_function))

"""
    get_display_name(f::AbstractFactor)

Get the display name of the factor.
This function must be implemented by all subtypes of `AbstractFactor`.
"""
get_display_name(f::AbstractFactor) = throw(InterfaceNotImplementedError(f, AbstractFactor, :get_display_name))



"""
    AbstractEdge

An interface for an edge in a probabilistic graphical model.
All subtypes must implement the following methods:
- [`get_message_to_variable`](@ref)
- [`get_message_to_node`](@ref)

The following methods are optional and derived automatically from the above methods:
- [`get_message_from_variable`](@ref)
- [`get_message_from_node`](@ref)
"""
abstract type AbstractEdge end

"""
    get_message_to_variable(e::AbstractEdge)::Value

Get the message to the variable.
This function must be implemented by all subtypes of `AbstractEdge`.
Must return a [`Value`](@ref) object.

See also: [`Value`](@ref), [`AbstractEdge`](@ref), [`get_message_to_node`](@ref), [`get_message_from_variable`](@ref)
"""
get_message_to_variable(e::AbstractEdge) = throw(InterfaceNotImplementedError(e, AbstractEdge, :get_message_to_variable))

"""
    get_message_to_node(e::AbstractEdge)::Value

Get the message to the node.
This function must be implemented by all subtypes of `AbstractEdge`.
Must return a [`Value`](@ref) object.

See also: [`Value`](@ref), [`AbstractEdge`](@ref), [`get_message_to_variable`](@ref), [`get_message_from_node`](@ref)
"""
get_message_to_node(e::AbstractEdge) = throw(InterfaceNotImplementedError(e, AbstractEdge, :get_message_to_node))


"""
    get_message_from_variable(e::AbstractEdge)::Value

Get the message from the variable.
This function is optional for subtypes of `AbstractEdge`. If not implemented, it will be equivalent to [`get_message_to_node(e)`](@ref).
Must return a [`Value`](@ref) object.

See also: [`Value`](@ref), [`AbstractEdge`](@ref), [`get_message_to_node`](@ref), [`get_message_to_variable`](@ref)
"""
get_message_from_variable(e::AbstractEdge) = get_message_to_node(e)


"""
    get_message_from_node(e::AbstractEdge)::Value

Get the message from the node.
This function is optional for subtypes of `AbstractEdge`. If not implemented, it will be equivalent to [`get_message_to_variable(e)`](@ref).
Must return a [`Value`](@ref) object.

See also: [`Value`](@ref), [`AbstractEdge`](@ref), [`get_message_to_variable`](@ref), [`get_message_from_variable`](@ref)
"""
get_message_from_node(e::AbstractEdge) = get_message_to_variable(e)

