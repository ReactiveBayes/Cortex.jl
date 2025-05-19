"""
    InferenceEngineWarning

A warning message generated during inference execution.

## Fields

- `description::String`: A human-readable description of the warning.
- `context::Any`: Additional context or data related to the warning.
"""
struct InferenceEngineWarning
    description::String
    context::Any
end

"""
    InferenceEngine{M}

Core structure for managing and executing probabilistic inference.

## Fields

- `model_backend::M`: The underlying model backend (e.g., a `BipartiteFactorGraph`).
- `dependency_resolver`: Resolves dependencies between signals during inference.
- `inference_request_processor`: Processes inference requests and manages computation order.
- `tracer`: Optional tracer for monitoring inference execution.
- `warnings`: Collection of [`InferenceEngineWarning`](@ref)s generated during inference.

## Constructor

```julia
InferenceEngine(;
    model_backend::M,
    dependency_resolver = DefaultDependencyResolver(),
    inference_request_processor = InferenceRequestScanner(),
    prepare_signals_metadata::Bool = true,
    resolve_dependencies::Bool = true,
    trace::Bool = false
) where {M}
```

### Arguments

- `model_backend`: An instance of a supported model backend.
- `dependency_resolver`: Custom dependency resolver (optional).
- `inference_request_processor`: Custom request processor (optional).
- `prepare_signals_metadata`: Whether to initialize signal types and metadata.
- `resolve_dependencies`: Whether to resolve signal dependencies on creation.
- `trace`: Whether to enable inference execution tracing.

See also: [`get_model_backend`](@ref), [`update_marginals!`](@ref), [`request_inference_for`](@ref)
"""
mutable struct InferenceEngine{M, D, P, T}
    model_backend::M
    dependency_resolver::D
    inference_request_processor::P
    tracer::T
    warnings::Vector{InferenceEngineWarning}

    function InferenceEngine(;
        model_backend::M,
        dependency_resolver::D = DefaultDependencyResolver(),
        inference_request_processor::P = InferenceRequestScanner(),
        prepare_signals_metadata::Bool = true,
        resolve_dependencies::Bool = true,
        trace::Bool = false
    ) where {M, D, P}
        checked_backend = throw_if_backend_unsupported(model_backend)::M
        checked_dependency_resolver = convert(AbstractDependencyResolver, dependency_resolver)
        checked_processor = convert(AbstractInferenceRequestProcessor, inference_request_processor)
        tracer = trace ? InferenceEngineTracer() : nothing
        warnings = InferenceEngineWarning[]

        engine = new{
            typeof(checked_backend), typeof(checked_dependency_resolver), typeof(checked_processor), typeof(tracer)
        }(
            checked_backend, checked_dependency_resolver, checked_processor, tracer, warnings
        )

        if prepare_signals_metadata
            prepare_signals_metadata!(engine)
        end

        if resolve_dependencies
            resolve_dependencies!(checked_dependency_resolver, engine)
        end

        return engine
    end
end

function Base.show(io::IO, engine::InferenceEngine)
    print(io, "InferenceEngine(")
    if !isnothing(get_trace(engine))
        print(io, "trace = true")
    else
        print(io, "trace = false")
    end
    print(io, ")")
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

get_warnings(engine::InferenceEngine) = engine.warnings

function add_warning!(engine::InferenceEngine, description::String, context::Any)
    push!(engine.warnings, InferenceEngineWarning(description, context))
end

# This is needed to make the engine broadcastable
Base.broadcastable(engine::InferenceEngine) = Ref(engine)

"""
    get_variable_data(engine::InferenceEngine, variable_id)

Alias for `get_variable_data(get_model_backend(engine), variable_id)`.
"""
get_variable_data(engine::InferenceEngine, variable_id) = get_variable_data(get_model_backend(engine), variable_id)

"""
    get_variable_ids(engine::InferenceEngine)

Alias for `get_variable_ids(get_model_backend(engine))`.
"""
get_variable_ids(engine::InferenceEngine) = get_variable_ids(get_model_backend(engine))

"""
    get_marginal(engine::InferenceEngine, variable_id) -> Cortex.Signal

Alias for `get_marginal(get_variable_data(engine, variable_id))`.
"""
get_marginal(engine::InferenceEngine, variable_id) = get_marginal(get_variable_data(engine, variable_id))

"""
    get_factor_data(engine::InferenceEngine, factor_id)

Alias for `get_factor_data(get_model_backend(engine), factor_id)`.
"""
get_factor_data(engine::InferenceEngine, factor_id) = get_factor_data(get_model_backend(engine), factor_id)

"""
    get_factor_ids(engine::InferenceEngine)

Alias for `get_factor_ids(get_model_backend(engine))`.
"""
get_factor_ids(engine::InferenceEngine) = get_factor_ids(get_model_backend(engine))

"""
    get_connection(engine::InferenceEngine, variable_id, factor_id)

Alias for `get_connection(get_model_backend(engine), variable_id, factor_id)`.
"""
get_connection(engine::InferenceEngine, variable_id, factor_id) =
    get_connection(get_model_backend(engine), variable_id, factor_id)

"""
    get_connection_label(engine::InferenceEngine, variable_id, factor_id) -> Symbol

Alias for `get_connection_label(get_connection(engine, variable_id, factor_id))`.
"""
get_connection_label(engine::InferenceEngine, variable_id, factor_id) =
    get_connection_label(get_connection(engine, variable_id, factor_id))

"""
    get_connection_index(engine::InferenceEngine, variable_id, factor_id) -> Int

Alias for `get_connection_index(get_connection(engine, variable_id, factor_id))`.
"""
get_connection_index(engine::InferenceEngine, variable_id, factor_id) =
    get_connection_index(get_connection(engine, variable_id, factor_id))

"""
    get_message_to_variable(engine::InferenceEngine, variable_id, factor_id) -> Cortex.Signal

Alias for `get_message_to_variable(get_connection(engine, variable_id, factor_id))`.
"""
get_message_to_variable(engine::InferenceEngine, variable_id, factor_id) =
    get_message_to_variable(get_connection(engine, variable_id, factor_id))

"""
    get_message_to_factor(engine::InferenceEngine, variable_id, factor_id) -> Cortex.Signal

Alias for `get_message_to_factor(get_connection(engine, variable_id, factor_id))`.
"""
get_message_to_factor(engine::InferenceEngine, variable_id, factor_id) =
    get_message_to_factor(get_connection(engine, variable_id, factor_id))

"""
    get_connected_variable_ids(engine::InferenceEngine, factor_id)

Alias for `get_connected_variable_ids(get_model_backend(engine), factor_id)`.
"""
get_connected_variable_ids(engine::InferenceEngine, factor_id) =
    get_connected_variable_ids(get_model_backend(engine), factor_id)

"""
    get_connected_factor_ids(engine::InferenceEngine, variable_id)

Alias for `get_connected_factor_ids(get_model_backend(engine), variable_id)`.
"""
get_connected_factor_ids(engine::InferenceEngine, variable_id) =
    get_connected_factor_ids(get_model_backend(engine), variable_id)

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

function to_string(type::UInt8)
    if type === 0x00
        return ""
    elseif type === MessageToVariable
        return "MessageToVariable"
    elseif type === MessageToFactor
        return "MessageToFactor"
    elseif type === ProductOfMessages
        return "ProductOfMessages"
    elseif type === IndividualMarginal
        return "IndividualMarginal"
    elseif type === JointMarginal
        return "JointMarginal"
    else
        return "UnknownType($(repr(type)))"
    end
end
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

"""
    InferenceRequest{E,V,M}

Internal structure representing a request to perform inference for a set of variables.

## Fields

- `engine::E`: The inference engine instance.
- `variable_ids::V`: Collection of variable identifiers to compute marginals for.
- `marginals::M`: Collection of marginal signals corresponding to the variables.
- `readines_status::BitVector`: Tracks which variables have been processed.

See also: [`request_inference_for`](@ref), [`update_marginals!`](@ref)
"""
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

    for variable_id in variable_ids
        for dependency in get_joint_dependencies(engine.dependency_resolver, engine, variable_id)
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

Base.convert(::Type{AbstractInferenceRequestProcessor}, f::F) where {F <: Function} =
    CallbackInferenceRequestProcessor{F}(f)

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

    trace_inference_request(engine.tracer, engine, request) do inference_request_trace
        indices         = 1:1:length(variable_ids)
        indices_reverse = reverse(indices)::typeof(indices)

        # We begin with a forward pass
        # After each pass, we alternate the order
        is_reverse = false

        while should_continue
            _should_continue = false

            current_order = is_reverse ? indices_reverse : indices

            # These rounds compute mostly the messages needed to compute the marginals
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

        trace_inference_round(inference_request_trace) do inference_round_trace
            for (variable_id, marginal) in zip(request.variable_ids, request.marginals)
                if is_pending(marginal)
                    trace_inference_execution(inference_round_trace, variable_id, marginal) do
                        process!(processor, request.engine, variable_id, marginal)
                    end
                end

                for joint_dependency in get_joint_dependencies(engine.dependency_resolver, engine, variable_id)
                    # Here it is fine to skip the joint dependency if it is not pending
                    # because several variables might attempt to update the same joint dependency
                    if !is_pending(joint_dependency)
                        continue
                    end
                    trace_inference_execution(inference_round_trace, variable_id, joint_dependency) do
                        process!(processor, request.engine, variable_id, joint_dependency)
                    end
                end
            end
        end
    end

    return nothing
end

## -- Inference tracing -- ##

"""
    TracedInferenceExecution

A record of a single signal computation during inference.

## Fields

- `engine::InferenceEngine`: The inference engine instance.
- `variable_id`: The identifier of the variable being processed.
- `signal::Signal`: The signal that was computed.
- `total_time_in_ns::UInt64`: Total computation time in nanoseconds.
- `value_before_execution`: Signal value before computation.
- `value_after_execution`: Signal value after computation.
"""
struct TracedInferenceExecution
    engine::InferenceEngine
    variable_id::Any
    signal::Cortex.Signal
    total_time_in_ns::UInt64
    value_before_execution::Any
    value_after_execution::Any
end

function Base.show(io::IO, execution::TracedInferenceExecution)
    variable_data = get_variable_data(execution.engine, execution.variable_id)

    signal = execution.signal
    signal_type = signal.type

    print(io, "TracedInferenceExecution(for = $(variable_data), type = ")

    if signal_type === Cortex.InferenceSignalTypes.MessageToVariable
        (v_id, f_id) = signal.metadata
        v_data = get_variable_data(execution.engine, v_id)
        f_data = get_factor_data(execution.engine, f_id)
        print(io, "MessageToVariable(from = $(f_data), to = $(v_data))")
    elseif signal_type === Cortex.InferenceSignalTypes.MessageToFactor
        (v_id, f_id) = signal.metadata
        v_data = get_variable_data(execution.engine, v_id)
        f_data = get_factor_data(execution.engine, f_id)
        print(io, "MessageToFactor(from = $(v_data), to = $(f_data))")
    elseif signal_type === Cortex.InferenceSignalTypes.ProductOfMessages
        print(io, "ProductOfMessages(?)")
    elseif signal_type === Cortex.InferenceSignalTypes.IndividualMarginal
        (v_id,) = signal.metadata
        v_data = get_variable_data(execution.engine, v_id)
        print(io, "IndividualMarginal($(v_data))")
    elseif signal_type === Cortex.InferenceSignalTypes.JointMarginal
        print(io, "JointMarginal(?)")
    end

    print(
        io,
        ", total_time = ",
        format_time_ns(execution.total_time_in_ns),
        ", value_before_execution = ",
        execution.value_before_execution,
        ", value_after_execution = ",
        execution.value_after_execution
    )

    print(io, ")")
end

"""
    TracedInferenceRound

A record of a single round of inference computations.

## Fields

- `engine::InferenceEngine`: The inference engine instance.
- `total_time_in_ns::UInt64`: Total round time in nanoseconds.
- `executions::Vector{TracedInferenceExecution}`: List of signal computations performed.
"""
struct TracedInferenceRound
    engine::InferenceEngine
    total_time_in_ns::UInt64
    executions::Vector{TracedInferenceExecution}
end

"""
    TracedInferenceRequest

A complete record of an inference request execution.

## Fields

- `engine::InferenceEngine`: The inference engine instance.
- `total_time_in_ns::UInt64`: Total request processing time in nanoseconds.
- `request::InferenceRequest`: The original inference request.
- `rounds::Vector{TracedInferenceRound}`: List of inference rounds performed.
"""
struct TracedInferenceRequest
    engine::InferenceEngine
    total_time_in_ns::UInt64
    request::InferenceRequest
    rounds::Vector{TracedInferenceRound}
end

"""
    InferenceEngineTracer

Tracer for monitoring and debugging inference execution.

## Fields

- `inference_requests::Vector{TracedInferenceRequest}`: History of traced inference requests.

The tracer records:
- Signal computations and their timing
- Value changes during inference
- Execution order of computations
"""
struct InferenceEngineTracer
    inference_requests::Vector{TracedInferenceRequest}

    InferenceEngineTracer() = new(TracedInferenceRequest[])
end

# If the tracer is not provided, we just execute the function
function trace_inference_request(f::F, ::Nothing, engine::InferenceEngine, request::InferenceRequest) where {F}
    return f(nothing)
end

function trace_inference_request(
    f::F, tracer::InferenceEngineTracer, engine::InferenceEngine, request::InferenceRequest
) where {F}
    # We collect the rounds of the inference request
    rounds = Vector{TracedInferenceRound}()

    # Inference request begins at time `begin_time_in_ns`
    begin_time_in_ns = time_ns()

    # We execute the function and pass the tracer and the rounds to the function
    # The function `f` should not assume that the tracer and the rounds are passed to it
    # Instead it uses opaque `trace` object to pass it further down the call stack
    f((engine, tracer, rounds))

    # Inference request ends at time `end_time_in_ns`
    end_time_in_ns = time_ns()

    # We compute the total time of the inference request
    total_time_in_ns = end_time_in_ns - begin_time_in_ns

    # We add the inference request to the tracer
    push!(tracer.inference_requests, TracedInferenceRequest(engine, total_time_in_ns, request, rounds))

    return nothing
end

function trace_inference(tracer::InferenceEngineTracer, processor::AbstractInferenceRequestProcessor)
    return tracer
end

# If the tracer is not provided, we just execute the function
function trace_inference_round(f::F, trace::Nothing) where {F}
    return f(nothing)
end

function trace_inference_round(
    f::F, trace::Tuple{InferenceEngine, InferenceEngineTracer, Vector{TracedInferenceRound}}
) where {F}
    engine, tracer, rounds = trace

    executions = Vector{TracedInferenceExecution}()

    # We begin the round at time `begin_time_in_ns`
    begin_time_in_ns = time_ns()

    # We execute the function and pass the tracer and the rounds to the function
    # The function `f` should not assume that the tracer and the rounds are passed to it
    # Instead it uses opaque `trace` object to pass it further down the call stack
    f((engine, tracer, executions))

    # We end the round at time `end_time_in_ns`
    end_time_in_ns = time_ns()

    # We compute the total time of the round
    total_time_in_ns = end_time_in_ns - begin_time_in_ns

    # We add the round to the tracer only if there are executions
    if length(executions) > 0
        push!(rounds, TracedInferenceRound(engine, total_time_in_ns, executions))
    end

    return nothing
end

function trace_inference_execution(f::F, ::Nothing, variable_id, dependency::Signal) where {F}
    return f()
end

function trace_inference_execution(
    f::F,
    trace::Tuple{InferenceEngine, InferenceEngineTracer, Vector{TracedInferenceExecution}},
    variable_id,
    dependency::Signal
) where {F}
    engine, tracer, executions = trace

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
            engine, variable_id, dependency, total_time_in_ns, value_before_execution, value_after_execution
        )
    )

    return nothing
end
