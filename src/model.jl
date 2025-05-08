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
    print(
        io,
        "The method `$(e.method)` is not implemented for the model object of type `$(typeof(e.model))`. The arguments passed to the method were: "
    )
    foreach(e.args) do arg
        print(io, arg, " (", typeof(arg), ")")
    end
end

abstract type AbstractCortexModel end

Base.broadcastable(m::AbstractCortexModel) = Ref(m)

struct FactorId{T}
    id::T
end

struct VariableId{T}
    id::T
end

struct EdgeId{T}
    variable::VariableId{T}
    factor::FactorId{T}
end

function add_factor_to_model!(model::AbstractCortexModel, args...)
    throw(CortexModelInterfaceNotImplementedError(:add_factor_to_model!, model, args))
end

function add_variable_to_model!(model::AbstractCortexModel, args...)
    throw(CortexModelInterfaceNotImplementedError(:add_variable_to_model!, model, args))
end

function add_edge_to_model!(model::AbstractCortexModel, variable::VariableId, factor::FactorId)
    throw(CortexModelInterfaceNotImplementedError(:add_edge_to_model!, model, (variable, factor)))
end

function get_factor_display_name(model::AbstractCortexModel, factor::FactorId)
    throw(CortexModelInterfaceNotImplementedError(:get_factor_display_name, model, (factor,)))
end

function get_variable_display_name(model::AbstractCortexModel, variable::VariableId)
    throw(CortexModelInterfaceNotImplementedError(:get_variable_display_name, model, (variable,)))
end

function get_edge_display_name(model::AbstractCortexModel, variable::VariableId, factor::FactorId)
    throw(CortexModelInterfaceNotImplementedError(:get_edge_display_name, model, (variable, factor)))
end

function get_variable_marginal(model::AbstractCortexModel, variable::VariableId)
    throw(CortexModelInterfaceNotImplementedError(:get_variable_marginal, model, (variable,)))
end

function get_edge_message_to_variable(model::AbstractCortexModel, variable::VariableId, factor::FactorId)
    throw(CortexModelInterfaceNotImplementedError(:get_edge_message_to_variable, model, (variable, factor)))
end

function get_edge_message_to_factor(model::AbstractCortexModel, variable::VariableId, factor::FactorId)
    throw(CortexModelInterfaceNotImplementedError(:get_edge_message_to_factor, model, (variable, factor)))
end

function get_factor_neighbors(model::AbstractCortexModel, factor::FactorId)
    throw(CortexModelInterfaceNotImplementedError(:get_factor_neighbors, model, (factor,)))
end

function get_variable_neighbors(model::AbstractCortexModel, variable::VariableId)
    throw(CortexModelInterfaceNotImplementedError(:get_variable_neighbors, model, (variable,)))
end

function get_variables(model::AbstractCortexModel)
    throw(CortexModelInterfaceNotImplementedError(:get_variables, model, ()))
end

function get_factors(model::AbstractCortexModel)
    throw(CortexModelInterfaceNotImplementedError(:get_factors, model, ()))
end
