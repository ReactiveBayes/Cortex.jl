
"""
    InferenceEngine{M}

Core structure for managing and executing inference tasks on a given model backend.

## Fields

- `model_backend::M`: The underlying model backend (e.g., a `BipartiteFactorGraph`) on which inference is performed. It must conform to the Cortex.jl backend interface.

## Constructor

```julia
InferenceEngine(; model_backend::M, prepare_signals_metadata::Bool = true) where {M}
```

- `model_backend`: An instance of a supported model backend.
- `prepare_signals_metadata::Bool` (default: `true`): If `true`, calls [`prepare_signals_metadata!`](@ref) upon construction to initialize signal types and metadata. This is typically required for inference algorithms.

## Overview

The `InferenceEngine` orchestrates message passing and marginal computation within a probabilistic model using the [`Signal`](@ref Cortex.Signal) reactivity system.
It provides a standardized API for:
- Accessing model components (variables, factors, connections).
- Retrieving reactive signals for marginals and messages.
- Managing inference execution via [`update_marginals!`](@ref) and [`request_inference_for`](@ref).

The engine interacts with the `model_backend` through a defined interface (e.g., `Cortex.get_variable_data(backend, id)`), implemented by backend-specific extensions.

## See Also

- [`get_model_backend`](@ref)
- [`prepare_signals_metadata!`](@ref)
- [`is_backend_supported`](@ref)
- [`update_marginals!`](@ref)
- [`request_inference_for`](@ref)
- [`Signal`](@ref Cortex.Signal)
"""
struct InferenceEngine{M, P, T}
    model_backend::M
    inference_request_processor::P
    tracer::T

    function InferenceEngine(;
        model_backend::M,
        inference_request_processor::P = InferenceRequestScanner(),
        prepare_signals_metadata::Bool = true,
        trace::Bool = false
    ) where {M, P}
        checked_backend = throw_if_backend_unsupported(model_backend)::M
        checked_processor = convert(AbstractInferenceRequestProcessor, inference_request_processor)
        tracer = trace ? InferenceEngineTracer() : nothing

        engine = new{typeof(checked_backend), typeof(checked_processor), typeof(tracer)}(
            checked_backend, checked_processor, tracer
        )

        if prepare_signals_metadata
            prepare_signals_metadata!(engine)
        end

        return engine
    end
end

"""
    get_model_backend(engine::InferenceEngine)

Retrieves the underlying model backend from the `InferenceEngine`.

## Arguments

- `engine::InferenceEngine`: The inference engine instance.

## Returns

The model backend object stored within the engine.

## See Also

- [`InferenceEngine`](@ref)
"""
get_model_backend(engine::InferenceEngine) = engine.model_backend

get_inference_request_processor(engine::InferenceEngine) = engine.inference_request_processor

get_trace(engine::InferenceEngine) = engine.tracer

# This is needed to make the engine broadcastable
Base.broadcastable(engine::InferenceEngine) = Ref(engine)

struct UnsupportedModelBackendError{B} <: Exception
    backend::B
end

function Base.showerror(io::IO, e::UnsupportedModelBackendError)
    print(io, "The model backend of type `$(typeof(e.backend))` is not supported.")
end

"A trait object indicating a supported model backend."
struct SupportedModelBackend end

"A trait object indicating an unsupported model backend."
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
    get_variable_data(engine::InferenceEngine, variable_id)

Retrieves the data structure representing a specific variable from the engine's model backend.

This function dispatches to the `get_variable_data(backend, variable_id)` method of the specific model backend.
The returned object must implement `get_marginal(variable_data_object) -> Cortex.Signal`.

## Arguments

- `engine::InferenceEngine`: The inference engine instance.
- `variable_id`: The identifier of the variable to retrieve.

## Returns

A backend-specific data structure for the variable.

## See Also

- [`get_marginal`](@ref)
- [`get_variable_ids`](@ref)
- [`InferenceEngine`](@ref)
"""
get_variable_data(engine::InferenceEngine, variable_id) = get_variable_data(get_model_backend(engine), variable_id)

"""
    get_variable_ids(engine::InferenceEngine)

Retrieves an iterator over all variable identifiers in the engine's model backend.

This function dispatches to the `get_variable_ids(backend)` method of the specific model backend.

## Arguments

- `engine::InferenceEngine`: The inference engine instance.

## Returns

An iterator of variable identifiers.

## See Also

- [`get_variable_data`](@ref)
- [`InferenceEngine`](@ref)
"""
get_variable_ids(engine::InferenceEngine) = get_variable_ids(get_model_backend(engine))

"""
    get_marginal(variable_data_object) -> Cortex.Signal

Retrieves the marginal [`Signal`](@ref Cortex.Signal) associated with a `variable_data_object`.

This function must be implemented by specific model backends for their variable data structures.

## Arguments

- `variable_data_object`: The backend-specific data structure representing a variable (obtained via [`get_variable_data`](@ref)).

## Returns

- `Cortex.Signal`: The reactive signal representing the variable's marginal.

## See Also

- [`get_variable_data`](@ref)
- [`get_marginal(::InferenceEngine, ::Any)`](@ref)
"""
get_marginal(any) = throw(MethodError(get_marginal, (any,)))

"""
    get_marginal(engine::InferenceEngine, variable_id) -> Cortex.Signal

Retrieves the marginal [`Signal`](@ref Cortex.Signal) for a given `variable_id` from the `InferenceEngine`.

This is a convenience function calling `get_marginal(get_variable_data(engine, variable_id))`.

## Arguments

- `engine::InferenceEngine`: The inference engine instance.
- `variable_id`: The identifier of the variable.

## Returns

- `Cortex.Signal`: The reactive signal representing the variable's marginal.

## See Also

- [`get_variable_data`](@ref)
- [`get_marginal(::Any)`](@ref)
- [`InferenceEngine`](@ref)
"""
get_marginal(engine::InferenceEngine, variable_id) = get_marginal(get_variable_data(engine, variable_id))

"""
    get_factor_data(engine::InferenceEngine, factor_id)

Retrieves the data structure representing a specific factor from the engine's model backend.

This function dispatches to the `get_factor_data(backend, factor_id)` method of the specific model backend.

## Arguments

- `engine::InferenceEngine`: The inference engine instance.
- `factor_id`: The identifier of the factor to retrieve.

## Returns

A backend-specific data structure for the factor.

## See Also

- [`get_factor_ids`](@ref)
- [`InferenceEngine`](@ref)
"""
get_factor_data(engine::InferenceEngine, factor_id) = get_factor_data(get_model_backend(engine), factor_id)

"""
    get_factor_ids(engine::InferenceEngine)

Retrieves an iterator over all factor identifiers in the engine's model backend.

This function dispatches to the `get_factor_ids(backend)` method of the specific model backend.

## Arguments

- `engine::InferenceEngine`: The inference engine instance.

## Returns

An iterator of factor identifiers.

## See Also

- [`get_factor_data`](@ref)
- [`InferenceEngine`](@ref)
"""
get_factor_ids(engine::InferenceEngine) = get_factor_ids(get_model_backend(engine))

"""
    get_connection(engine::InferenceEngine, variable_id, factor_id)

Retrieves the data structure representing the connection between a specified `variable_id` and `factor_id`.

This function dispatches to the `get_connection(backend, variable_id, factor_id)` method of the specific model backend.
The returned object must implement:
- `get_connection_label(connection_object) -> Symbol`
- `get_connection_index(connection_object) -> Int`
- `get_message_to_variable(connection_object) -> Cortex.Signal`
- `get_message_to_factor(connection_object) -> Cortex.Signal`

## Arguments

- `engine::InferenceEngine`: The inference engine instance.
- `variable_id`: The identifier of the variable in the connection.
- `factor_id`: The identifier of the factor in the connection.

## Returns

A backend-specific data structure for the connection.

## See Also

- [`get_connection_label`](@ref)
- [`get_connection_index`](@ref)
- [`get_message_to_variable`](@ref)
- [`get_message_to_factor`](@ref)
- [`InferenceEngine`](@ref)
"""
get_connection(engine::InferenceEngine, variable_id, factor_id) = get_connection(
    get_model_backend(engine), variable_id, factor_id
)

"""
    get_connection_label(connection_object)

Retrieves the label (e.g., `:out`, `:in`, interface name) of a `connection_object`.

This function must be implemented by specific model backends for their connection data structures.

## Arguments

- `connection_object`: The backend-specific data structure representing a connection.

## Returns

- `Symbol`: The label of the connection.

## See Also

- [`get_connection`](@ref)
- [`get_connection_label(::InferenceEngine, ::Any, ::Any)`](@ref)
"""
get_connection_label(any) = throw(MethodError(get_connection_label, (any,)))

"""
    get_connection_label(engine::InferenceEngine, variable_id, factor_id) -> Symbol

Retrieves the label of the connection between `variable_id` and `factor_id`.

This is a convenience function calling `get_connection_label(get_connection(engine, variable_id, factor_id))`.

## Arguments

- `engine::InferenceEngine`: The inference engine instance.
- `variable_id`: The identifier of the variable.
- `factor_id`: The identifier of the factor.

## Returns

- `Symbol`: The label of the connection.

## See Also

- [`get_connection`](@ref)
- [`get_connection_label(::Any)`](@ref)
- [`InferenceEngine`](@ref)
"""
get_connection_label(engine::InferenceEngine, variable_id, factor_id) = get_connection_label(
    get_connection(engine, variable_id, factor_id)
)

"""
    get_connection_index(connection_object) -> Int

Retrieves the index of a `connection_object`, if applicable (e.g., for multi-edges).

This function must be implemented by specific model backends for their connection data structures.
Defaults to 0 if not explicitly indexed.

## Arguments

- `connection_object`: The backend-specific data structure representing a connection.

## Returns

- `Int`: The index of the connection.

## See Also

- [`get_connection`](@ref)
- [`get_connection_index(::InferenceEngine, ::Any, ::Any)`](@ref)
"""
get_connection_index(any) = throw(MethodError(get_connection_index, (any,)))

"""
    get_connection_index(engine::InferenceEngine, variable_id, factor_id) -> Int

Retrieves the index of the connection between `variable_id` and `factor_id`.

This is a convenience function calling `get_connection_index(get_connection(engine, variable_id, factor_id))`.

## Arguments

- `engine::InferenceEngine`: The inference engine instance.
- `variable_id`: The identifier of the variable.
- `factor_id`: The identifier of the factor.

## Returns

- `Int`: The index of the connection.

## See Also

- [`get_connection`](@ref)
- [`get_connection_index(::Any)`](@ref)
- [`InferenceEngine`](@ref)
"""
get_connection_index(engine::InferenceEngine, variable_id, factor_id) = get_connection_index(
    get_connection(engine, variable_id, factor_id)
)

"""
    get_message_to_variable(connection_object) -> Cortex.Signal

Retrieves the message [`Signal`](@ref Cortex.Signal) flowing from a factor to a variable along the given `connection_object`.

This function must be implemented by specific model backends for their connection data structures.

## Arguments

- `connection_object`: The backend-specific data structure representing a connection.

## Returns

- `Cortex.Signal`: The reactive signal for the message to the variable.

## See Also

- [`get_connection`](@ref)
- [`get_message_to_variable(::InferenceEngine, ::Any, ::Any)`](@ref)
"""
get_message_to_variable(any) = throw(MethodError(get_message_to_variable, (any,)))

"""
    get_message_to_variable(engine::InferenceEngine, variable_id, factor_id) -> Cortex.Signal

Retrieves the message [`Signal`](@ref Cortex.Signal) from `factor_id` to `variable_id`.

This is a convenience function calling `get_message_to_variable(get_connection(engine, variable_id, factor_id))`.

## Arguments

- `engine::InferenceEngine`: The inference engine instance.
- `variable_id`: The identifier of the target variable.
- `factor_id`: The identifier of the source factor.

## Returns

- `Cortex.Signal`: The reactive signal for the message.

## See Also

- [`get_connection`](@ref)
- [`get_message_to_variable(::Any)`](@ref)
- [`InferenceEngine`](@ref)
"""
get_message_to_variable(engine::InferenceEngine, variable_id, factor_id) = get_message_to_variable(
    get_connection(engine, variable_id, factor_id)
)

"""
    get_message_to_factor(connection_object) -> Cortex.Signal

Retrieves the message [`Signal`](@ref Cortex.Signal) flowing from a variable to a factor along the given `connection_object`.

This function must be implemented by specific model backends for their connection data structures.

## Arguments

- `connection_object`: The backend-specific data structure representing a connection.

## Returns

- `Cortex.Signal`: The reactive signal for the message to the factor.

## See Also

- [`get_connection`](@ref)
- [`get_message_to_factor(::InferenceEngine, ::Any, ::Any)`](@ref)
"""
get_message_to_factor(any) = throw(MethodError(get_message_to_factor, (any,)))

"""
    get_message_to_factor(engine::InferenceEngine, variable_id, factor_id) -> Cortex.Signal

Retrieves the message [`Signal`](@ref Cortex.Signal) from `variable_id` to `factor_id`.

This is a convenience function calling `get_message_to_factor(get_connection(engine, variable_id, factor_id))`.

## Arguments

- `engine::InferenceEngine`: The inference engine instance.
- `variable_id`: The identifier of the source variable.
- `factor_id`: The identifier of the target factor.

## Returns

- `Cortex.Signal`: The reactive signal for the message.

## See Also

- [`get_connection`](@ref)
- [`get_message_to_factor(::Any)`](@ref)
- [`InferenceEngine`](@ref)
"""
get_message_to_factor(engine::InferenceEngine, variable_id, factor_id) = get_message_to_factor(
    get_connection(engine, variable_id, factor_id)
)

"""
    get_connected_variable_ids(engine::InferenceEngine, factor_id)

Retrieves an iterator over the identifiers of variables connected to a given `factor_id`.

This function dispatches to the `get_connected_variable_ids(backend, factor_id)` method of the specific model backend.

## Arguments

- `engine::InferenceEngine`: The inference engine instance.
- `factor_id`: The identifier of the factor.

## Returns

An iterator of connected variable identifiers.

## See Also

- [`get_connected_factor_ids`](@ref)
- [`get_connection`](@ref)
- [`InferenceEngine`](@ref)
"""
get_connected_variable_ids(engine::InferenceEngine, factor_id) = get_connected_variable_ids(
    get_model_backend(engine), factor_id
)

"""
    get_connected_factor_ids(engine::InferenceEngine, variable_id)

Retrieves an iterator over the identifiers of factors connected to a given `variable_id`.

This function dispatches to the `get_connected_factor_ids(backend, variable_id)` method of the specific model backend.

## Arguments

- `engine::InferenceEngine`: The inference engine instance.
- `variable_id`: The identifier of the variable.

## Returns

An iterator of connected factor identifiers.

## See Also

- [`get_connected_variable_ids`](@ref)
- [`get_connection`](@ref)
- [`InferenceEngine`](@ref)
"""
get_connected_factor_ids(engine::InferenceEngine, variable_id) = get_connected_factor_ids(
    get_model_backend(engine), variable_id
)

"""
    InferenceSignalTypes

Module defining constants for different types of signals used within the inference engine.
These types help in dispatching computation rules and managing signal metadata.

## Constants

- [`MessageToVariable`](@ref Cortex.InferenceSignalTypes.MessageToVariable): Signal representing a message from a factor to a variable.
- [`MessageToFactor`](@ref Cortex.InferenceSignalTypes.MessageToFactor): Signal representing a message from a variable to a factor.
- [`ProductOfMessages`](@ref Cortex.InferenceSignalTypes.ProductOfMessages): Signal representing an intermediate product of messages, often a dependency for an `IndividualMarginal`.
- [`IndividualMarginal`](@ref Cortex.InferenceSignalTypes.IndividualMarginal): Signal representing the marginal distribution of a single variable.
- [`JointMarginal`](@ref Cortex.InferenceSignalTypes.JointMarginal): Signal representing the joint marginal distribution of a set of variables.

## See Also

- [`prepare_signals_metadata!`](@ref)
- [`Signal`](@ref Cortex.Signal)
"""
module InferenceSignalTypes

"Type constant for a [`Signal`](@ref Cortex.Signal) representing a message from a factor to a variable."
const MessageToVariable = UInt8(0x01)

"Type constant for a [`Signal`](@ref Cortex.Signal) representing a message from a variable to a factor."
const MessageToFactor = UInt8(0x02)

"Type constant for a [`Signal`](@ref Cortex.Signal) representing an intermediate product of messages."
const ProductOfMessages = UInt8(0x03)

"Type constant for a [`Signal`](@ref Cortex.Signal) representing the marginal distribution of a single variable."
const IndividualMarginal = UInt8(0x04)

"Type constant for a [`Signal`](@ref Cortex.Signal) representing the joint marginal distribution of a set of variables."
const JointMarginal = UInt8(0x05)
end

"""
    prepare_signals_metadata!(engine::InferenceEngine)

Initializes the `type` and `metadata` fields for relevant signals within the `InferenceEngine`.

This function iterates through variables and factors in the model backend, setting:
- Marginals: `type` to [`IndividualMarginal`](@ref Cortex.InferenceSignalTypes.IndividualMarginal) and `metadata` to `(variable_id,)`.
- Messages to Factors: `type` to [`MessageToFactor`](@ref Cortex.InferenceSignalTypes.MessageToFactor) and `metadata` to `(variable_id, factor_id)`.
- Messages to Variables: `type` to [`MessageToVariable`](@ref Cortex.InferenceSignalTypes.MessageToVariable) and `metadata` to `(variable_id, factor_id)`.

This setup is typically done once upon engine creation and is crucial for dispatching appropriate computation rules during inference.

## Arguments

- `engine::InferenceEngine`: The inference engine instance whose signals are to be prepared.

## See Also

- [`InferenceEngine`](@ref)
- [`InferenceSignalTypes`](@ref)
"""
function prepare_signals_metadata!(engine::InferenceEngine)
    for variable_id in get_variable_ids(engine)
        marginal = get_marginal(engine, variable_id)::Cortex.Signal
        marginal.type = Cortex.InferenceSignalTypes.IndividualMarginal
        marginal.metadata = (variable_id,)
    end

    for factor_id in get_factor_ids(engine)
        variable_ids = get_connected_variable_ids(engine, factor_id)
        for variable_id in variable_ids
            message_to_factor = get_message_to_factor(engine, variable_id, factor_id)::Cortex.Signal
            message_to_factor.type = Cortex.InferenceSignalTypes.MessageToFactor
            message_to_factor.metadata = (variable_id, factor_id)

            message_to_variable = get_message_to_variable(engine, variable_id, factor_id)::Cortex.Signal
            message_to_variable.type = Cortex.InferenceSignalTypes.MessageToVariable
            message_to_variable.metadata = (variable_id, factor_id)
        end
    end
end

## -- Inference requests -- ##

"Internal struct representing a request to perform inference for a set of variables."
struct InferenceRequest{E, V, M}
    engine::E
    variable_ids::V
    marginals::M
    readines_status::BitVector
end

"""
    request_inference_for(engine::InferenceEngine, variable_id_or_ids)

Creates an `InferenceRequest` to compute the marginals for the specified `variable_id_or_ids`.

This function prepares the necessary signals by marking their dependencies as potentially pending.
It supports requesting inference for a single variable ID or a collection (Tuple or AbstractVector) of variable IDs.

## Arguments

- `engine::InferenceEngine`: The inference engine instance.
- `variable_id_or_ids`: A single variable identifier or a collection of variable identifiers.

## Returns

- `InferenceRequest`: An internal structure representing the inference request.

## See Also

- [`update_marginals!`](@ref)
- [`InferenceEngine`](@ref)
"""
function request_inference_for(engine::InferenceEngine, variable_id)
    return request_inference_for(engine, (variable_id,))
end

function request_inference_for(engine::InferenceEngine, variable_ids::Union{AbstractVector, Tuple})
    marginals = map(variable_id -> get_marginal(engine, variable_id)::Cortex.Signal, variable_ids)

    for marginal in marginals
        for dependency in get_dependencies(marginal)
            dependency.props = SignalProps(is_potentially_pending = true, is_pending = false)
        end
    end

    readines_status = falses(length(variable_ids))

    return InferenceRequest(engine, variable_ids, marginals, readines_status)
end

abstract type AbstractInferenceRequestProcessor end

function process!(
    processor::AbstractInferenceRequestProcessor, engine::InferenceEngine, variable_id, dependency::Signal
)
    throw(MethodError(process!, (processor, engine, variable_id, dependency)))
end

"Internal function to process dependencies for an inference request."
function process_inference_request(
    processor::AbstractInferenceRequestProcessor, request::InferenceRequest, variable_id, marginal; trace = nothing
)
    processed_at_least_once = process_dependencies!(marginal; retry = true) do dependency
        if is_pending(dependency)
            trace_inference_execution(trace, variable_id, dependency) do
                process!(processor, request.engine, variable_id, dependency)
            end
            return true
        end
        return false
    end
    return processed_at_least_once
end

"Internal struct used to scan and collect pending signals from an inference request."
struct InferenceRequestScanner <: AbstractInferenceRequestProcessor
    signals::Vector{Signal}

    InferenceRequestScanner() = new(Signal[])
end

"Internal functor for `InferenceTaskScanner` to collect dependencies."
function process!(scanner::InferenceRequestScanner, engine::InferenceEngine, variable_id, dependency::Signal)
    push!(scanner.signals, dependency)
end

"Internal function to scan an `InferenceRequest` and return all pending (dependent) signals."
function scan_inference_request(request::InferenceRequest)
    scanner = InferenceRequestScanner()
    for (variable_id, marginal) in zip(request.variable_ids, request.marginals)
        process_inference_request(scanner, request, variable_id, marginal)
    end
    return scanner.signals
end

"Internal struct that wraps a user-provided computation function for processing by `update_marginals!`."
struct CallbackInferenceRequestProcessor{F} <: AbstractInferenceRequestProcessor
    f::F
end

Base.convert(::Type{AbstractInferenceRequestProcessor}, f::F) where {F <: Function} = CallbackInferenceRequestProcessor{
    F
}(
    f
)

"Internal functor for `InferenceRequestProcessor` to apply the computation logic."
function process!(
    processor::CallbackInferenceRequestProcessor, engine::InferenceEngine, variable_id, dependency::Signal
)
    compute!(dependency) do signal, dependencies
        processor.f(engine, signal, dependencies)
    end
end

function update_marginals!(engine::InferenceEngine, variable_ids)
    return update_marginals!(engine, (variable_ids,))
end

function update_marginals!(engine::InferenceEngine, variable_ids::Union{AbstractVector, Tuple})
    should_continue = true

    request = request_inference_for(engine, variable_ids)
    processor = get_inference_request_processor(engine)

    trace_inference_request(engine.tracer, request) do inference_request_trace
        indices         = 1:1:length(variable_ids)
        indices_reverse = reverse(indices)::typeof(indices)

        # We begin with a forward pass
        # After each pass, we alternate the order
        is_reverse = false

        while should_continue
            _should_continue = false

            current_order = is_reverse ? indices_reverse : indices

            trace_inference_round(inference_request_trace) do inference_round_trace
                @inbounds for i in current_order
                    if !request.readines_status[i]
                        variable_id = variable_ids[i]
                        marginal = request.marginals[i]

                        has_been_processed_at_least_once = process_inference_request(
                            processor, request, variable_id, marginal; trace = inference_round_trace
                        )

                        if is_pending(marginal)
                            request.readines_status[i] = true
                        end

                        _should_continue = _should_continue || has_been_processed_at_least_once
                    end
                end
            end

            # Alternate between forward and backward order
            is_reverse = !is_reverse

            should_continue = _should_continue
        end

        for (variable_id, marginal) in zip(request.variable_ids, request.marginals)
            process!(processor, request.engine, variable_id, marginal)
        end
    end

    return nothing
end

## -- Inference tracing -- ##

struct TracedInferenceExecution
    variable_id::Any
    signal::Cortex.Signal
    total_time_in_ns::UInt64
    value_before_execution::Any
    value_after_execution::Any
end

struct TracedInferenceRound
    total_time_in_ns::UInt64
    executions::Vector{TracedInferenceExecution}
end

struct TracedInferenceRequest
    total_time_in_ns::UInt64
    request::InferenceRequest
    rounds::Vector{TracedInferenceRound}
end

struct InferenceEngineTracer
    inference_requests::Vector{TracedInferenceRequest}

    InferenceEngineTracer() = new(TracedInferenceRequest[])
end

# If the tracer is not provided, we just execute the function
function trace_inference_request(f::F, ::Nothing, request::InferenceRequest) where {F}
    return f(nothing)
end

function trace_inference_request(f::F, tracer::InferenceEngineTracer, request::InferenceRequest) where {F}
    # We collect the rounds of the inference request
    rounds = Vector{TracedInferenceRound}()

    # Inference request begins at time `begin_time_in_ns`
    begin_time_in_ns = time_ns()

    # We execute the function and pass the tracer and the rounds to the function
    # The function `f` should not assume that the tracer and the rounds are passed to it
    # Instead it uses opaque `trace` object to pass it further down the call stack
    f((tracer, rounds))

    # Inference request ends at time `end_time_in_ns`
    end_time_in_ns = time_ns()

    # We compute the total time of the inference request
    total_time_in_ns = end_time_in_ns - begin_time_in_ns

    # We add the inference request to the tracer
    push!(tracer.inference_requests, TracedInferenceRequest(total_time_in_ns, request, rounds))
end

function trace_inference(tracer::InferenceEngineTracer, processor::AbstractInferenceRequestProcessor)
    return tracer
end

# If the tracer is not provided, we just execute the function
function trace_inference_round(f::F, trace::Nothing) where {F}
    return f(nothing)
end

function trace_inference_round(f::F, trace::Tuple{InferenceEngineTracer, Vector{TracedInferenceRound}}) where {F}
    tracer, rounds = trace

    executions = Vector{TracedInferenceExecution}()

    # We begin the round at time `begin_time_in_ns`
    begin_time_in_ns = time_ns()

    # We execute the function and pass the tracer and the rounds to the function
    # The function `f` should not assume that the tracer and the rounds are passed to it
    # Instead it uses opaque `trace` object to pass it further down the call stack
    f((tracer, executions))

    # We end the round at time `end_time_in_ns`
    end_time_in_ns = time_ns()

    # We compute the total time of the round
    total_time_in_ns = end_time_in_ns - begin_time_in_ns

    # We add the round to the tracer only if there are executions
    if length(executions) > 0
        push!(rounds, TracedInferenceRound(total_time_in_ns, executions))
    end

    return f(trace)
end

function trace_inference_execution(f::F, ::Nothing, variable_id, dependency::Signal) where {F}
    return f()
end

function trace_inference_execution(
    f::F, trace::Tuple{InferenceEngineTracer, Vector{TracedInferenceExecution}}, variable_id, dependency::Signal
) where {F}
    tracer, executions = trace

    value_before_execution = get_value(dependency)

    # We begin the execution at time `begin_time_in_ns`
    begin_time_in_ns = time_ns()

    # Here we do not pass the tracer and the executions to the function
    # since it is not required for the tracer
    f()

    # We end the execution at time `end_time_in_ns`
    end_time_in_ns = time_ns()

    # We compute the total time of the execution
    total_time_in_ns = end_time_in_ns - begin_time_in_ns

    value_after_execution = get_value(dependency)

    push!(
        executions,
        TracedInferenceExecution(
            variable_id, dependency, total_time_in_ns, value_before_execution, value_after_execution
        )
    )
end
