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