
"""
    Variable

A data structure representing a probabilistic variable in a model.

A `Variable` encapsulates the essential components of a probabilistic variable, including its 
identity, current marginal belief (as a reactive signal), and any signals that should be 
automatically updated when the variable's marginal changes.

## Fields

- `name::Symbol`: The symbolic name of the variable, used for identification and display.
- `index::Any = nothing`: An optional index for the variable, useful for indexed variable families 
  (e.g., `x[1]`, `x[2]`, etc.). Can be any type that makes sense for the specific use case.
- `marginal::Signal = Signal()`: A reactive signal representing the current marginal belief 
  over this variable. Updated automatically during inference.
- `linked_signals::Vector{Signal} = Signal[]`: A collection of signals that should be 
  automatically updated when this variable's marginal changes. These might represent joint 
  marginals around factors, or any other derived quantities that depend on this variable.

## See Also

- [`get_variable_name`](@ref): Retrieve the variable's name
- [`get_variable_index`](@ref): Retrieve the variable's index  
- [`get_variable_marginal`](@ref): Retrieve the variable's marginal signal
- [`get_variable_linked_signals`](@ref): Retrieve the variable's linked signals
- [`link_signal_to_variable!`](@ref): Link additional signals to the variable
"""
Base.@kwdef struct Variable
    name::Symbol
    index::Any = nothing
    marginal::Signal = Signal()
    linked_signals::Vector{Signal} = Signal[]
end

"""
    get_variable_name(variable::Variable)

Retrieves the name of a variable.
"""
function get_variable_name(variable::Variable)
    return variable.name
end

"""
    get_variable_index(variable::Variable)

Retrieves the index of a variable.
"""
function get_variable_index(variable::Variable)
    return variable.index
end

"""
    get_variable_marginal(variable::Variable)

Retrieves the marginal of a variable.
"""
function get_variable_marginal(variable::Variable)
    return variable.marginal
end

"""
    get_variable_linked_signals(variable::Variable)

Retrieves the linked signals of a variable. 
The linked signals are the signals that should be updated when the marginal (which is a signal) of the variable is updated.
Those may, for example, represent joint marginals around certain factors, but any other signal can be linked as well.
"""
function get_variable_linked_signals(variable::Variable)
    return variable.linked_signals
end

"""
    link_signal_to_variable!(variable::Variable, signal::Signal)

Links a signal to a variable. The linked signal will be updated automatically when the marginal of the variable is updated.
"""
function link_signal_to_variable!(variable::Variable, signal::Signal)
    push!(variable.linked_signals, signal)
    return nothing
end

"""
    UnsupportedModelBackendError{B}

An error thrown when attempting to use an unsupported model backend.

This error is typically thrown by [`throw_if_backend_unsupported`](@ref) when [`is_backend_supported`](@ref)
returns [`UnsupportedModelBackend`](@ref).

## Fields

- `model_backend::B`: The unsupported model backend instance.

## See Also

- [`is_backend_supported`](@ref)
- [`throw_if_backend_unsupported`](@ref)
- [`UnsupportedModelBackend`](@ref)
"""
struct UnsupportedModelBackendError{B} <: Exception
    model_backend::B
end

function Base.showerror(io::IO, e::UnsupportedModelBackendError)
    print(io, "The model backend of type `$(typeof(e.model_backend))` is not supported.")
end

"A trait object indicating a supported model backend. Use this as a return value of [`Cortex.is_backend_supported`](@ref)."
struct SupportedModelBackend end

"A trait object indicating an unsupported model backend. Used as a default return value of [`Cortex.is_backend_supported`](@ref)."
struct UnsupportedModelBackend end

"""
    is_backend_supported(backend::Any) -> Union{SupportedModelBackend, UnsupportedModelBackend}

Checks if a given `backend` is supported by the `InferenceEngine`.

This function should be extended by specific backend implementations.

## Arguments

- `backend::Any`: The model backend instance to check.

## Returns

- `SupportedModelBackend()` if the backend is supported.
- `UnsupportedModelBackend()` otherwise.

## Example 

```jldoctest
julia> struct CustomModelBackend end

julia> Cortex.is_backend_supported(::CustomModelBackend) = Cortex.SupportedModelBackend();
```

```jldoctest
julia> struct SomeOtherDataStructure end

julia> Cortex.is_backend_supported(::SomeOtherDataStructure) = Cortex.UnsupportedModelBackend();
```

## See Also

- [`SupportedModelBackend`](@ref)
- [`UnsupportedModelBackend`](@ref)
- [`throw_if_backend_unsupported`](@ref)
"""
is_backend_supported(::Any) = UnsupportedModelBackend()

"""
    throw_if_backend_unsupported(backend::Any)

Throws an [`UnsupportedModelBackendError`](@ref) if the backend is unsupported.
"""
function throw_if_backend_unsupported end

throw_if_backend_unsupported(backend::Any) = throw_if_backend_unsupported(is_backend_supported(backend), backend)
throw_if_backend_unsupported(::UnsupportedModelBackend, backend::Any) = throw(UnsupportedModelBackendError(backend))
throw_if_backend_unsupported(::SupportedModelBackend, backend::Any) = backend

"""
    get_variable_data(model_backend, variable_id)

Retrieves the data structure representing a specific variable from the model backend.

This function must be implemented by specific model backends. The returned object must implement
`get_marginal(variable_data_object) -> Cortex.Signal`.

## Arguments

- `model_backend`: The model backend instance.
- `variable_id`: The identifier of the variable to retrieve.

## Returns

A model backend-specific data structure for the variable.

## See Also

- [`get_marginal`](@ref)
- [`get_variable_ids`](@ref)
"""
function get_variable_data end

"""
    get_marginal(variable_data)

Retrieves the marginal [`Signal`](@ref Cortex.Signal) associated with a variable data structure.

This function must be implemented for any variable data structure returned by [`get_variable_data`](@ref).

## Arguments

- `variable_data`: The model backend-specific data structure representing a variable.

## Returns

- `Cortex.Signal`: The reactive signal representing the variable's marginal.

## See Also

- [`get_variable_data`](@ref)
"""
function get_marginal end

"""
    get_factor_data(model_backend, factor_id)

Retrieves the data structure representing a specific factor from the model backend.

This function must be implemented by specific model backends.

## Arguments

- `model_backend`: The model backend instance.
- `factor_id`: The identifier of the factor to retrieve.

## Returns

A model backend-specific data structure for the factor.

## See Also

- [`get_factor_ids`](@ref)
"""
function get_factor_data end

"""
    get_variable_ids(model_backend)

Retrieves an iterator over all variable identifiers in the model backend.

This function must be implemented by specific model backends.

## Arguments

- `model_backend`: The model backend instance.

## Returns

An iterator of variable identifiers.

## See Also

- [`get_variable_data`](@ref)
"""
function get_variable_ids end

"""
    get_factor_ids(model_backend)

Retrieves an iterator over all factor identifiers in the model backend.

This function must be implemented by specific model backends.

## Arguments

- `model_backend`: The model backend instance.

## Returns

An iterator of factor identifiers.

## See Also

- [`get_factor_data`](@ref)
"""
function get_factor_ids end

"""
    get_connection(model_backend, variable_id, factor_id)

Retrieves the data structure representing the connection between a specified variable and factor.

This function must be implemented by specific model backends. The returned object must implement:
- `get_connection_label(connection_object) -> Symbol`
- `get_connection_index(connection_object) -> Int`
- `get_message_to_variable(connection_object) -> Cortex.Signal`
- `get_message_to_factor(connection_object) -> Cortex.Signal`

## Arguments

- `model_backend`: The model backend instance.
- `variable_id`: The identifier of the variable in the connection.
- `factor_id`: The identifier of the factor in the connection.

## Returns

A model backend-specific data structure for the connection.

## See Also

- [`get_connection_label`](@ref)
- [`get_connection_index`](@ref)
- [`get_message_to_variable`](@ref)
- [`get_message_to_factor`](@ref)
"""
function get_connection end

"""
    get_connected_variable_ids(model_backend, factor_id)

Retrieves an iterator over the identifiers of variables connected to a given factor.

This function must be implemented by specific model backends.

## Arguments

- `model_backend`: The model backend instance.
- `factor_id`: The identifier of the factor.

## Returns

An iterator of connected variable identifiers.

## See Also

- [`get_connected_factor_ids`](@ref)
- [`get_connection`](@ref)
"""
function get_connected_variable_ids end

"""
    get_connected_factor_ids(model_backend, variable_id)

Retrieves an iterator over the identifiers of factors connected to a given variable.

This function must be implemented by specific model backends.

## Arguments

- `model_backend`: The model backend instance.
- `variable_id`: The identifier of the variable.

## Returns

An iterator of connected factor identifiers.

## See Also

- [`get_connected_variable_ids`](@ref)
- [`get_connection`](@ref)
"""
function get_connected_factor_ids end
