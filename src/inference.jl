struct InferenceEngine{M}
    model_backend::M

    function InferenceEngine(; model_backend::M, prepare_signals_metadata::Bool = true) where {M}
        checked_backend = throw_if_backend_unsupported(model_backend)::M
        engine = new{M}(checked_backend)

        if prepare_signals_metadata
            prepare_signals_metadata!(engine)
        end

        return engine
    end
end

"""
    get_model_backend(engine::InferenceEngine)

Get the model backend of the inference engine.

See also: [`InferenceEngine`](@ref)
"""
get_model_backend(engine::InferenceEngine) = engine.model_backend

# This is needed to make the engine broadcastable
Base.broadcastable(engine::InferenceEngine) = Ref(engine)

struct UnsupportedModelBackendError{B} <: Exception
    backend::B
end

function Base.showerror(io::IO, e::UnsupportedModelBackendError)
    print(io, "The model backend of type `$(typeof(e.backend))` is not supported.")
end

"A trait object that represents a supported model backend."
struct SupportedModelBackend end

"A trait object that represents an unsupported model backend."
struct UnsupportedModelBackend end

"""
    is_backend_supported(backend::Any) -> SupportedModelBackend | UnsupportedModelBackend

Check if the model backend is supported. 
Returns a `SupportedModelBackend()` if the backend is supported, otherwise a `UnsupportedModelBackend()`.

See also: [`throw_if_backend_unsupported`](@ref), [`SupportedModelBackend`](@ref), [`UnsupportedModelBackend`](@ref)
"""
is_backend_supported(::Any) = UnsupportedModelBackend()

throw_if_backend_unsupported(backend::Any) = throw_if_backend_unsupported(is_backend_supported(backend), backend)
throw_if_backend_unsupported(::UnsupportedModelBackend, backend::Any) = throw(UnsupportedModelBackendError(backend))
throw_if_backend_unsupported(::SupportedModelBackend, backend::Any) = backend

"""
    get_variable_data(engine::InferenceEngine, variable_id)

Get a variable from the model backend. 
This function must be implemented for each model backend as it simply calls the `get_variable_data` function of the engine's backend.
Must return an object which implements the following functions:
- `get_marginal() -> Signal` - Returns the marginal of the variable in the form of a `Signal` object.

See also: [`get_marginal`](@ref), [`Signal`](@ref), [`get_variables`](@ref)
"""
get_variable_data(engine::InferenceEngine, variable_id) = get_variable_data(get_model_backend(engine), variable_id)

"""
    get_variable_ids(engine::InferenceEngine)

Get all variable ids from the model backend.
This function must be implemented for each model backend as it simply calls the `get_variable_ids` function of the engine's backend.

See also: [`get_variable_data`](@ref)
"""
get_variable_ids(engine::InferenceEngine) = get_variable_ids(get_model_backend(engine))

"""
    get_marginal(variable) -> Cortex.Signal

Get the marginal of a variable. A backend may return any structure that represents a `variable`. 
The `get_marginal` function is used to retrieve the marginal of the variable from such a structure.

See also: [`get_variable_data`](@ref), [`Signal`](@ref)
"""
get_marginal(any) = throw(MethodError(get_marginal, (any,)))

"""
    get_marginal(engine::InferenceEngine, variable_id) -> Cortex.Signal

An alias function that simply calls `get_marginal(get_variable_data(engine, variable_id))`.

See also: [`get_variable_data`](@ref), [`Signal`](@ref)
"""
get_marginal(engine::InferenceEngine, variable_id) = get_marginal(get_variable_data(engine, variable_id))

"""
    get_factor_data(engine::InferenceEngine, factor_id)

Get a factor from the model backend.
This function must be implemented for each model backend as it simply calls the `get_factor_data` function of the engine's backend.

See also: [`get_marginal`](@ref), [`Signal`](@ref)
"""
get_factor_data(engine::InferenceEngine, factor_id) = get_factor_data(get_model_backend(engine), factor_id)

"""
    get_factor_ids(engine::InferenceEngine)

Get all factor ids from the model backend.
This function must be implemented for each model backend as it simply calls the `get_factor_ids` function of the engine's backend.

See also: [`get_factor_data`](@ref)
"""
get_factor_ids(engine::InferenceEngine) = get_factor_ids(get_model_backend(engine))

"""
    get_connection(engine::InferenceEngine, variable_id, factor_id)

Get the connection between a variable and a factor.
This function must be implemented for each model backend as it simply calls the `get_connection` function of the engine's backend.
Must return an object which implements the following functions:
- `get_connection_label() -> Symbol` - Returns the label of the connection.
- `get_connection_index() -> Int` - Returns the index of the connection.
- `get_message_to_variable() -> Signal` - Returns the message to the variable in the form of a `Signal` object.
- `get_message_to_factor() -> Signal` - Returns the message to the factor in the form of a `Signal` object.

See also: [`get_message_to_variable`](@ref), [`get_message_to_factor`](@ref), [`Signal`](@ref)
"""
get_connection(engine::InferenceEngine, variable_id, factor_id) = get_connection(
    get_model_backend(engine), variable_id, factor_id
)

"""
    get_connection_label(connection)

Get the label of a connection. A backend may return any structure that represents a `connection`.
The `get_connection_label` function is used to retrieve the label of the connection from such a structure.

See also: [`get_connection`](@ref)
"""
get_connection_label(any) = throw(MethodError(get_connection_label, (any,)))

"""
    get_connection_label(engine::InferenceEngine, variable_id, factor_id)

An alias function that simply calls `get_connection_label(get_connection(engine, variable_id, factor_id))`.

See also: [`get_connection`](@ref)
"""
get_connection_label(engine::InferenceEngine, variable_id, factor_id) = get_connection_label(
    get_connection(engine, variable_id, factor_id)
)

"""
    get_connection_index(connection) -> Int

Get the index of a connection. A backend may return any structure that represents a `connection`.
The `get_connection_index` function is used to retrieve the index of the connection from such a structure.

See also: [`get_connection`](@ref)
"""
get_connection_index(any) = throw(MethodError(get_connection_index, (any,)))

"""
    get_connection_index(engine::InferenceEngine, variable_id, factor_id) -> Int

An alias function that simply calls `get_connection_index(get_connection(engine, variable_id, factor_id))`.

See also: [`get_connection`](@ref)
"""
get_connection_index(engine::InferenceEngine, variable_id, factor_id) = get_connection_index(
    get_connection(engine, variable_id, factor_id)
)

"""
    get_message_to_variable(connection) -> Cortex.Signal

Get the message to the variable from the factor. A backend may return any structure that represents a `connection`.
The `get_message_to_variable` function is used to retrieve the message to the variable from such a structure.

See also: [`get_connection`](@ref), [`Cortex.Signal`](@ref)
"""
get_message_to_variable(any) = throw(MethodError(get_message_to_variable, (any,)))

"""
    get_message_to_variable(engine::InferenceEngine, variable_id, factor_id) -> Cortex.Signal

An alias function that simply calls `get_message_to_variable(get_connection(engine, variable_id, factor_id))`.

See also: [`get_connection`](@ref), [`Cortex.Signal`](@ref)
"""
get_message_to_variable(engine::InferenceEngine, variable_id, factor_id) = get_message_to_variable(
    get_connection(engine, variable_id, factor_id)
)

"""
    get_message_to_factor(connection) -> Cortex.Signal

Get the message to the factor from the variable. A backend may return any structure that represents a `connection`.
The `get_message_to_factor` function is used to retrieve the message to the factor from such a structure.

See also: [`get_connection`](@ref), [`Cortex.Signal`](@ref)
"""
get_message_to_factor(any) = throw(MethodError(get_message_to_factor, (any,)))

"""
    get_message_to_factor(engine::InferenceEngine, variable_id, factor_id) -> Cortex.Signal

An alias function that simply calls `get_message_to_factor(get_connection(engine, variable_id, factor_id))`.

See also: [`get_connection`](@ref), [`Cortex.Signal`](@ref)
"""
get_message_to_factor(engine::InferenceEngine, variable_id, factor_id) = get_message_to_factor(
    get_connection(engine, variable_id, factor_id)
)

"""
    get_connected_variable_ids(engine::InferenceEngine, factor_id)

Get an iterator over ids of variables connected to a factor.
This function must be implemented for each model backend as it simply calls the `get_connections_by_factor_id` function of the engine's backend.

See also: [`get_connection`](@ref)
"""
get_connected_variable_ids(engine::InferenceEngine, factor_id) = get_connected_variable_ids(
    get_model_backend(engine), factor_id
)

"""
    get_connected_factor_ids(engine::InferenceEngine, variable_id)

Get an iterator over ids of factors connected to a variable.
This function must be implemented for each model backend as it simply calls the `get_connections_by_variable_id` function of the engine's backend.

See also: [`get_connection`](@ref)
"""
get_connected_factor_ids(engine::InferenceEngine, variable_id) = get_connected_factor_ids(
    get_model_backend(engine), variable_id
)

"""
    InferenceSignalTypes

A module that contains constants for the types of signals used in the inference engine.
Available types are:
- `MessageToVariable` - A signal that represents a message to a variable from a factor.
- `MessageToFactor` - A signal that represents a message to a factor from a variable.
- `ProductOfMessages` - A signal that represents the product of messages. Usually used as an intermediate dependency to `IndividualMarginal`.
- `IndividualMarginal` - A signal that represents the marginal of a variable.
- `JointMarginal` - A signal that represents the joint marginal of a set of variables.

See also: [`prepare_signals_metadata!`](@ref)
"""
module InferenceSignalTypes

"A signal that represents a message to a variable from a factor."
const MessageToVariable = UInt8(0x01)

"A signal that represents a message to a factor from a variable."
const MessageToFactor = UInt8(0x02)

"A signal that represents the product of messages. Usually used as an intermediate dependency to `IndividualMarginal`."
const ProductOfMessages = UInt8(0x03)

"A signal that represents the marginal of a variable."
const IndividualMarginal = UInt8(0x04)

"A signal that represents the joint marginal of a set of variables."
const JointMarginal = UInt8(0x05)
end

"""
    prepare_signals_metadata!(engine::InferenceEngine)

Prepare the signals metadata for the inference engine.
This function will set appropriate types and metadata for each signal in the engine.

See also: [`InferenceSignalTypes`](@ref)
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

struct InferenceRequest{E, V, M}
    engine::E
    variable_ids::V
    marginals::M
    readines_status::BitVector
end

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

function process_inference_request(callback::F, request::InferenceRequest, variable_id, marginal) where {F}
    processed_at_least_once = process_dependencies!(marginal; retry = true) do dependency
        if is_pending(dependency)
            callback(request.engine, variable_id, marginal, dependency)
            return true
        end
        return false
    end
    return processed_at_least_once
end

struct InferenceTaskScanner
    signals::Vector{Signal}

    InferenceTaskScanner() = new(Signal[])
end

function (scanner::InferenceTaskScanner)(engine::InferenceEngine, variable_id, marginal::Signal, dependency::Signal)
    push!(scanner.signals, dependency)
end

function scan_inference_request(request::InferenceRequest)
    scanner = InferenceTaskScanner()
    for (variable_id, marginal) in zip(request.variable_ids, request.marginals)
        process_inference_request(scanner, request, variable_id, marginal)
    end
    return scanner.signals
end

struct InferenceRequestProcessor{F}
    f::F
end

Base.convert(::Type{InferenceRequestProcessor}, f::F) where {F <: Function} = InferenceRequestProcessor{F}(f)
Base.convert(::Type{InferenceRequestProcessor}, f::InferenceRequestProcessor) = f

function (processor::InferenceRequestProcessor)(
    engine::InferenceEngine, variable_id, marginal::Signal, dependency::Signal; force = false
)
    compute!(dependency; force = force) do signal, dependencies
        processor.f(engine, signal, dependencies)
    end
end

function update_marginals!(f::F, engine::InferenceEngine, variable_ids) where {F <: Function}
    return update_marginals!(f, engine, (variable_ids,))
end

function update_marginals!(
    f::F, engine::InferenceEngine, variable_ids::Union{AbstractVector, Tuple}
) where {F <: Function}
    should_continue = true

    callback = convert(InferenceRequestProcessor, f)

    request = request_inference_for(engine, variable_ids)

    indices         = 1:1:length(variable_ids)
    indices_reverse = reverse(indices)::typeof(indices)

    # We begin with a forward pass
    # After each pass, we alternate the order
    is_reverse = false

    while should_continue
        _should_continue = false

        current_order = is_reverse ? indices_reverse : indices

        @inbounds for i in current_order
            if !request.readines_status[i]
                variable_id = variable_ids[i]
                marginal = request.marginals[i]

                has_been_processed_at_least_once = process_inference_request(callback, request, variable_id, marginal)

                if is_pending(marginal)
                    request.readines_status[i] = true
                end

                _should_continue = _should_continue || has_been_processed_at_least_once
            end
        end

        # Alternate between forward and backward order
        is_reverse = !is_reverse

        should_continue = _should_continue
    end

    for (variable_id, marginal) in zip(request.variable_ids, request.marginals)
        callback(request.engine, variable_id, marginal, marginal; force = true)
    end

    return nothing
end
