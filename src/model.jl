"""
    CortexModelInterfaceNotImplementedError(method::Symbol, model, args)

Custom exception thrown when a required interface method is not implemented for a given model type.

# Arguments
- `method::Symbol`: The name of the method that was called but not implemented.
- `model`: The model object for which the method was called.
- `args`: A tuple of arguments passed to the method, excluding the model itself.

# Returns
Throws an exception with a detailed error message indicating the missing method and argument types.

# Example
```julia
throw(CortexModelInterfaceNotImplementedError(:get_variable_marginal, mymodel, (variable,)))
```
"""
struct CortexModelInterfaceNotImplementedError <: Exception
    method::Symbol
    model
    args
end

function Base.showerror(io::IO, e::CortexModelInterfaceNotImplementedError)
    print(io, "The method `$(e.method)` is not implemented for the model object of type `$(typeof(e.model))`. The arguments passed to the method were: ")
    foreach(e.args) do arg
        print(io, arg, " (", typeof(arg), ")")
    end
end

"""
    get_factor_display_name(model, factor)

A part of the interface of `CortexModel`.
Must return a "displayable" object (e.g. a string) that can be used to display the factor when necessary (e.g. in error messages).

# Arguments
- `model`: The model object.
- `factor`: The factor whose display name is requested.

# Returns
A displayable object (typically a `String`) representing the factor.
"""
function get_factor_display_name(model, factor)
    throw(CortexModelInterfaceNotImplementedError(:get_factor_display_name, model, (factor,)))
end

"""
    get_variable_display_name(model, variable)

A part of the interface of `CortexModel`.
Must return a "displayable" object (e.g. a string) that can be used to display the variable when necessary (e.g. in error messages).

# Arguments
- `model`: The model object.
- `variable`: The variable whose display name is requested.

# Returns
A displayable object (typically a `String`) representing the variable.
"""
function get_variable_display_name(model, variable)
    throw(CortexModelInterfaceNotImplementedError(:get_variable_display_name, model, (variable,)))
end

"""
    get_edge_display_name(model, variable, factor)

A part of the interface of `CortexModel`.
Must return a "displayable" object (e.g. a string) that can be used to display the edge when necessary (e.g. in error messages).

# Arguments
- `model`: The model object.
- `variable`: The variable node of the edge.
- `factor`: The factor node of the edge.

# Returns
A displayable object (typically a `String`) representing the edge.
"""
function get_edge_display_name(model, variable, factor)
    throw(CortexModelInterfaceNotImplementedError(:get_edge_display_name, model, (variable, factor)))
end

"""
    get_variable_marginal(model, variable)

A part of the interface of `CortexModel`.
Must return the marginal distribution or value associated with the given variable.

# Arguments
- `model`: The model object.
- `variable`: The variable whose marginal is requested.

# Returns
A `Cortex.Slot` object representing the marginal distribution or value for the variable.
"""
function get_variable_marginal(model, variable)
    throw(CortexModelInterfaceNotImplementedError(:get_variable_marginal, model, (variable,)))
end

"""
    get_factor_local_marginal(model, factor)

A part of the interface of `CortexModel`.
Must return the local marginal distribution or value associated with the given factor.

# Arguments
- `model`: The model object.
- `factor`: The factor whose local marginal is requested.

# Returns
A `Cortex.Slot` object representing the local marginal distribution or value for the factor.
"""
function get_factor_local_marginal(model, factor)
    throw(CortexModelInterfaceNotImplementedError(:get_factor_local_marginal, model, (factor,)))
end

"""
    get_edge_message_to_variable(model, edge)

A part of the interface of `CortexModel`.
Must return the message sent along the edge to the variable node.

# Arguments
- `model`: The model object.
- `edge`: The edge for which the message is requested.

# Returns
A `Cortex.Slot` object representing the message sent to the variable node along the edge.
"""
function get_edge_message_to_variable(model, variable, factor)
    throw(CortexModelInterfaceNotImplementedError(:get_edge_message_to_variable, model, (variable, factor)))
end

"""
    get_edge_message_to_factor(model, variable, factor)

A part of the interface of `CortexModel`.
Must return the message sent along the edge to the factor node.

# Arguments
- `model`: The model object.
- `variable`: The variable node of the edge.
- `factor`: The factor node of the edge.

# Returns
A `Cortex.Slot` object representing the message sent to the factor node along the edge.
"""
function get_edge_message_to_factor(model, variable, factor)
    throw(CortexModelInterfaceNotImplementedError(:get_edge_message_to_factor, model, (variable, factor)))
end

"""
    get_factor_neighbors(model, factor)

A part of the interface of `CortexModel`.
Must return the neighbors of the given factor.

# Arguments
- `model`: The model object.
- `factor`: The factor whose neighbors are requested.

# Returns
A collection of nodes that are neighbors of the given factor.
"""
function get_factor_neighbors(model, factor)
    throw(CortexModelInterfaceNotImplementedError(:get_factor_neighbors, model, (factor,)))
end

"""
    get_variable_neighbors(model, variable)

A part of the interface of `CortexModel`.
Must return the neighbors of the given variable.

# Arguments
- `model`: The model object.
- `variable`: The variable whose neighbors are requested.

# Returns
A collection of nodes that are neighbors of the given variable.
"""
function get_variable_neighbors(model, variable)
    throw(CortexModelInterfaceNotImplementedError(:get_variable_neighbors, model, (variable,)))
end