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

- `model_engine::M`: The underlying model engine (e.g., a `BipartiteFactorGraph`).
- `dependency_resolver`: Resolves dependencies between signals during inference.
- `inference_request_processor`: Processes inference requests and manages computation order.
- `tracer`: Optional tracer for monitoring inference execution.
- `warnings`: Collection of [`InferenceEngineWarning`](@ref)s generated during inference.

## Constructor

```julia
InferenceEngine(;
    model_engine::M,
    dependency_resolver = DefaultDependencyResolver(),
    inference_request_processor = InferenceRequestScanner(),
    prepare_signals_metadata::Bool = true,
    resolve_dependencies::Bool = true,
    trace::Bool = false
) where {M}
```

### Arguments

- `model_engine`: An instance of a supported model engine.
- `dependency_resolver`: Custom dependency resolver (optional).
- `inference_request_processor`: Custom request processor (optional).
- `prepare_signals_metadata`: Whether to initialize signal variants.
- `resolve_dependencies`: Whether to resolve signal dependencies on creation.
- `trace`: Whether to enable inference execution tracing.

See also: [`get_model_engine`](@ref), [`update_marginals!`](@ref), [`request_inference_for`](@ref)
"""
mutable struct InferenceEngine{M, D, P, T}
    model_engine::M
    dependency_resolver::D
    inference_request_processor::P
    tracer::T
    warnings::Vector{InferenceEngineWarning}

    function InferenceEngine(;
        model_engine::M,
        dependency_resolver::D = DefaultDependencyResolver(),
        inference_request_processor::P = InferenceRequestScanner(),
        prepare_signals_metadata::Bool = true,
        resolve_dependencies::Bool = true,
        trace::Bool = false
    ) where {M, D, P}
        checked_engine = throw_if_engine_unsupported(model_engine)::M
        checked_dependency_resolver = convert(AbstractDependencyResolver, dependency_resolver)
        checked_processor = convert(AbstractInferenceRequestProcessor, inference_request_processor)
        tracer = trace ? InferenceEngineTracer() : nothing
        warnings = InferenceEngineWarning[]

        engine = new{
            typeof(checked_engine), typeof(checked_dependency_resolver), typeof(checked_processor), typeof(tracer)
        }(
            checked_engine, checked_dependency_resolver, checked_processor, tracer, warnings
        )

        if prepare_signals_metadata
            set_signals_variants!(engine)
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
    get_model_engine(engine::InferenceEngine)

Retrieves the underlying model engine from the `InferenceEngine`.

## Arguments

- `engine::InferenceEngine`: The inference engine instance.

## Returns

The model engine object stored within the engine.

## See Also

- [`InferenceEngine`](@ref)
"""
get_model_engine(engine::InferenceEngine) = engine.model_engine

get_inference_request_processor(engine::InferenceEngine) = engine.inference_request_processor

get_trace(engine::InferenceEngine) = engine.tracer

get_warnings(engine::InferenceEngine) = engine.warnings

function add_warning!(engine::InferenceEngine, description::String, context::Any)
    push!(engine.warnings, InferenceEngineWarning(description, context))
end

# This is needed to make the engine broadcastable
Base.broadcastable(engine::InferenceEngine) = Ref(engine)

"""
    get_variable(engine::InferenceEngine, variable_id::Int)

Alias for `get_variable(get_model_engine(engine), variable_id)`.
"""
get_variable(engine::InferenceEngine, variable_id::Int) = get_variable(get_model_engine(engine), variable_id)::Variable

"""
    get_variable_ids(engine::InferenceEngine)

Alias for `get_variable_ids(get_model_engine(engine))`.
"""
get_variable_ids(engine::InferenceEngine) = get_variable_ids(get_model_engine(engine))

"""
    get_factor(engine::InferenceEngine, factor_id::Int)

Alias for `get_factor(get_model_engine(engine), factor_id)`.
"""
get_factor(engine::InferenceEngine, factor_id::Int) = get_factor(get_model_engine(engine), factor_id)::Factor

"""
    get_factor_ids(engine::InferenceEngine)

Alias for `get_factor_ids(get_model_engine(engine))`.
"""
get_factor_ids(engine::InferenceEngine) = get_factor_ids(get_model_engine(engine))

"""
    get_connection(engine::InferenceEngine, variable_id::Int, factor_id::Int)

Alias for `get_connection(get_model_engine(engine), variable_id, factor_id)`.
"""
get_connection(engine::InferenceEngine, variable_id::Int, factor_id::Int) =
    get_connection(get_model_engine(engine), variable_id, factor_id)::Connection

"""
    get_connection_message_to_variable(engine::InferenceEngine, variable_id::Int, factor_id::Int)

Alias for `get_connection_message_to_variable(get_connection(engine, variable_id, factor_id)::Connection)::InferenceSignal`.
"""
get_connection_message_to_variable(engine::InferenceEngine, variable_id::Int, factor_id::Int) =
    get_connection_message_to_variable(get_connection(engine, variable_id, factor_id)::Connection)::InferenceSignal

"""
    get_connection_message_to_factor(engine::InferenceEngine, variable_id::Int, factor_id::Int)

Alias for `get_connection_message_to_factor(get_connection(engine, variable_id, factor_id)::Connection)::InferenceSignal`.
"""
get_connection_message_to_factor(engine::InferenceEngine, variable_id::Int, factor_id::Int) =
    get_connection_message_to_factor(get_connection(engine, variable_id, factor_id)::Connection)::InferenceSignal

"""
    get_connected_variable_ids(engine::InferenceEngine, factor_id::Int)

Alias for `get_connected_variable_ids(get_model_engine(engine), factor_id)`.
"""
get_connected_variable_ids(engine::InferenceEngine, factor_id::Int) =
    get_connected_variable_ids(get_model_engine(engine), factor_id)

"""
    get_connected_factor_ids(engine::InferenceEngine, variable_id::Int)

Alias for `get_connected_factor_ids(get_model_engine(engine), variable_id)`.
"""
get_connected_factor_ids(engine::InferenceEngine, variable_id::Int) =
    get_connected_factor_ids(get_model_engine(engine), variable_id)

"""
    set_signals_variants!(engine::InferenceEngine)

Initializes the `variant` field for relevant signals within the `InferenceEngine`.

This function iterates through variables and factors in the model backend, setting:
- Marginals: `variant` to [`IndividualMarginal`](@ref Cortex.InferenceSignalVariants).
- Messages to Factors: `variant` to [`MessageToFactor`](@ref Cortex.InferenceSignalVariants).
- Messages to Variables: `variant` to [`MessageToVariable`](@ref Cortex.InferenceSignalVariants).

This setup is typically done once upon engine creation and is crucial for dispatching appropriate computation rules during inference.

## Arguments

- `engine::InferenceEngine`: The inference engine instance whose signals are to be prepared.

## See Also

- [`InferenceEngine`](@ref)
- [`InferenceSignalVariants`](@ref)
"""
function set_signals_variants!(engine::InferenceEngine)
    for variable_id in get_variable_ids(engine)
        variable = get_variable(engine, variable_id)
        marginal = get_variable_marginal(variable)
        set_variant!(marginal, InferenceSignalVariants.IndividualMarginal(variable_id))
    end

    for factor_id in get_factor_ids(engine)
        variable_ids = get_connected_variable_ids(engine, factor_id)
        for variable_id in variable_ids
            connection = get_connection(engine, variable_id, factor_id)

            message_to_factor = get_connection_message_to_factor(connection)
            set_variant!(message_to_factor, InferenceSignalVariants.MessageToFactor(variable_id, factor_id))

            message_to_variable = get_connection_message_to_variable(connection)
            set_variant!(message_to_variable, InferenceSignalVariants.MessageToVariable(variable_id, factor_id))
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

    # Initialize the container for the marginals
    marginals = Vector{InferenceSignal}(undef, length(variable_ids))

    # For each variable, we flip the `is_potentially_pending` flag to `true`
    # for all of the dependencies of its marginal and the corresponding linked signals
    @inbounds for (i, variable_id) in enumerate(variable_ids)
        variable = get_variable(engine, variable_id)
        marginal = get_variable_marginal(variable)

        for dependency in get_dependencies(marginal)
            dependency.props = SignalProps(is_potentially_pending = true, is_pending = false)
        end

        for linked_signal in get_variable_linked_signals(variable)
            linked_signal.props = SignalProps(is_potentially_pending = true, is_pending = false)
        end

        marginals[i] = marginal
    end

    readines_status = falses(length(variable_ids))

    return InferenceRequest(engine, variable_ids, marginals, readines_status)
end

"""
    AbstractInferenceRequestProcessor

Abstract type for inference request processors that handle different types of inference signals.
Subtypes must implement methods for processing various signal variants.
"""
abstract type AbstractInferenceRequestProcessor end

"""
    compute_message_to_variable!(processor, engine, variant, signal, dependencies)

Compute a message from a factor to a variable.

# Arguments
- `processor::AbstractInferenceRequestProcessor`: The processor instance
- `engine::InferenceEngine`: The inference engine
- `variant::InferenceSignalVariants.MessageToVariable`: The message variant
- `signal::InferenceSignal`: The signal to compute
- `dependencies`: The dependencies of the signal

# Returns
The computed message value.

# Throws
Error if not implemented by the processor.
"""
function compute_message_to_variable!(
    processor::AbstractInferenceRequestProcessor,
    engine::InferenceEngine,
    variant::InferenceSignalVariants.MessageToVariable,
    signal::InferenceSignal,
    dependencies
)
    error(
        "The function `compute_message_to_variable!` is not implemented for the processor of type $(typeof(processor))"
    )
end

"""
    compute_message_to_factor!(processor, engine, variant, signal, dependencies)

Compute a message from a variable to a factor.

# Arguments
- `processor::AbstractInferenceRequestProcessor`: The processor instance
- `engine::InferenceEngine`: The inference engine
- `variant::InferenceSignalVariants.MessageToFactor`: The message variant
- `signal::InferenceSignal`: The signal to compute
- `dependencies`: The dependencies of the signal

# Returns
The computed message value.

# Throws
Error if not implemented by the processor.
"""
function compute_message_to_factor!(
    processor::AbstractInferenceRequestProcessor,
    engine::InferenceEngine,
    variant::InferenceSignalVariants.MessageToFactor,
    signal::InferenceSignal,
    dependencies
)
    error("The function `compute_message_to_factor!` is not implemented for the processor of type $(typeof(processor))")
end

"""
    compute_individual_marginal!(processor, engine, variant, signal, dependencies)

Compute an individual marginal for a variable.

# Arguments
- `processor::AbstractInferenceRequestProcessor`: The processor instance
- `engine::InferenceEngine`: The inference engine
- `variant::InferenceSignalVariants.IndividualMarginal`: The marginal variant
- `signal::InferenceSignal`: The signal to compute
- `dependencies`: The dependencies of the signal

# Returns
The computed marginal value.

# Throws
Error if not implemented by the processor.
"""
function compute_individual_marginal!(
    processor::AbstractInferenceRequestProcessor,
    engine::InferenceEngine,
    variant::InferenceSignalVariants.IndividualMarginal,
    signal::InferenceSignal,
    dependencies
)
    error(
        "The function `compute_individual_marginal!` is not implemented for the processor of type $(typeof(processor))"
    )
end

"""
    compute_product_of_messages!(processor, engine, variant, signal, dependencies)

Compute the product of multiple messages.

# Arguments
- `processor::AbstractInferenceRequestProcessor`: The processor instance
- `engine::InferenceEngine`: The inference engine
- `variant::InferenceSignalVariants.ProductOfMessages`: The product variant
- `signal::InferenceSignal`: The signal to compute
- `dependencies`: The dependencies of the signal

# Returns
The computed product value.

# Throws
Error if not implemented by the processor.
"""
function compute_product_of_messages!(
    processor::AbstractInferenceRequestProcessor,
    engine::InferenceEngine,
    variant::InferenceSignalVariants.ProductOfMessages,
    signal::InferenceSignal,
    dependencies
)
    error(
        "The function `compute_product_of_messages!` is not implemented for the processor of type $(typeof(processor))"
    )
end

"""
    compute_joint_marginal!(processor, engine, variant, signal, dependencies)

Compute a joint marginal for multiple variables.

# Arguments
- `processor::AbstractInferenceRequestProcessor`: The processor instance
- `engine::InferenceEngine`: The inference engine
- `variant::InferenceSignalVariants.JointMarginal`: The joint marginal variant
- `signal::InferenceSignal`: The signal to compute
- `dependencies`: The dependencies of the signal

# Returns
The computed joint marginal value.

# Throws
Error if not implemented by the processor.
"""
function compute_joint_marginal!(
    processor::AbstractInferenceRequestProcessor,
    engine::InferenceEngine,
    variant::InferenceSignalVariants.JointMarginal,
    signal::InferenceSignal,
    dependencies
)
    error("The function `compute_joint_marginal!` is not implemented for the processor of type $(typeof(processor))")
end

function process!(
    processor::AbstractInferenceRequestProcessor, engine::InferenceEngine, variable_id, dependency::InferenceSignal
)
    compute!(dependency) do signal, dependencies
        variant = signal.variant::InferenceSignalVariant

        if isa(variant, InferenceSignalVariants.MessageToVariable)
            compute_message_to_variable!(
                processor, engine, variant::InferenceSignalVariants.MessageToVariable, signal, dependencies
            )
        elseif isa(variant, InferenceSignalVariants.MessageToFactor)
            compute_message_to_factor!(
                processor, engine, variant::InferenceSignalVariants.MessageToFactor, signal, dependencies
            )
        elseif isa(variant, InferenceSignalVariants.IndividualMarginal)
            compute_individual_marginal!(
                processor, engine, variant::InferenceSignalVariants.IndividualMarginal, signal, dependencies
            )
        elseif isa(variant, InferenceSignalVariants.ProductOfMessages)
            compute_product_of_messages!(
                processor, engine, variant::InferenceSignalVariants.ProductOfMessages, signal, dependencies
            )
        elseif isa(variant, InferenceSignalVariants.JointMarginal)
            compute_joint_marginal!(
                processor, engine, variant::InferenceSignalVariants.JointMarginal, signal, dependencies
            )
        else
            error(lazy"Unprocessed signal variant: $(signal.variant)")
        end
    end
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
    signals::Vector{InferenceSignal}

    InferenceRequestScanner() = new(InferenceSignal[])
end

"Internal functor for `InferenceTaskScanner` to collect dependencies."
function process!(scanner::InferenceRequestScanner, engine::InferenceEngine, variable_id, dependency::InferenceSignal)
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

"""
    update_marginals!(engine::InferenceEngine, variable_id_or_ids)

Updates the marginals for the specified `variable_id_or_ids`.
"""
function update_marginals! end

function update_marginals!(engine::InferenceEngine, variable_ids)
    return update_marginals!(engine, (variable_ids,))
end

function update_marginals!(engine::InferenceEngine, variable_ids::Union{AbstractVector, Tuple})
    # This is a reference because we create a lambda callback with the `trace_inference_round`
    # JET reports an type-unstable capture error otherwise
    should_continue::Base.RefValue{Bool} = Ref(true)

    request = request_inference_for(engine, variable_ids)
    processor = get_inference_request_processor(engine)

    trace_inference_request(engine.tracer, engine, request) do inference_request_trace
        indices         = 1:1:length(variable_ids)
        indices_reverse = reverse(indices)::typeof(indices)

        # We begin with a forward pass
        # After each pass, we alternate the order
        is_reverse = false

        while should_continue[]
            _should_continue::Base.RefValue{Bool} = Ref(false)

            current_order = is_reverse ? indices_reverse : indices

            # These rounds compute mostly the messages needed to compute the marginals
            trace_inference_round(inference_request_trace) do inference_round_trace
                __should_continue = false

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

                        __should_continue = __should_continue || has_been_processed_at_least_once
                    end
                end

                _should_continue[] = __should_continue::Bool
            end

            # Alternate between forward and backward order
            is_reverse = !is_reverse

            should_continue[] = _should_continue[]::Bool
        end

        trace_inference_round(inference_request_trace) do inference_round_trace
            for (variable_id, marginal) in zip(request.variable_ids, request.marginals)
                if is_pending(marginal)
                    trace_inference_execution(inference_round_trace, variable_id, marginal) do
                        process!(processor, request.engine, variable_id, marginal)
                    end
                end

                for linked_signal in get_variable_linked_signals(get_variable(engine, variable_id))
                    # We skip the linked signal if it is not pending
                    if !is_pending(linked_signal)
                        continue
                    end
                    trace_inference_execution(inference_round_trace, variable_id, linked_signal) do
                        process!(processor, request.engine, variable_id, linked_signal)
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
- `signal::InferenceSignal`: The signal that was computed.
- `total_time_in_ns::UInt64`: Total computation time in nanoseconds.
- `value_before_execution`: Signal value before computation.
- `value_after_execution`: Signal value after computation.
"""
struct TracedInferenceExecution
    engine::InferenceEngine
    variable_id::Any
    signal::InferenceSignal
    total_time_in_ns::UInt64
    value_before_execution::Any
    value_after_execution::Any
end

function Base.show(io::IO, execution::TracedInferenceExecution)
    variable_data = get_variable(execution.engine, execution.variable_id)

    signal = execution.signal

    print(io, "TracedInferenceExecution(for = $(variable_data), variant = ")

    if isa(signal.variant, InferenceSignalVariants.MessageToVariable)
        v_data = get_variable(execution.engine, signal.variant.variable_id)
        f_data = get_factor(execution.engine, signal.variant.factor_id)
        print(io, "MessageToVariable(from = $(f_data), to = $(v_data))")
    elseif isa(signal.variant, InferenceSignalVariants.MessageToFactor)
        v_data = get_variable(execution.engine, signal.variant.variable_id)
        f_data = get_factor(execution.engine, signal.variant.factor_id)
        print(io, "MessageToFactor(from = $(v_data), to = $(f_data))")
    elseif isa(signal.variant, InferenceSignalVariants.ProductOfMessages)
        print(io, "ProductOfMessages(?)")
    elseif isa(signal.variant, InferenceSignalVariants.IndividualMarginal)
        v_data = get_variable(execution.engine, signal.variant.variable_id)
        print(io, "IndividualMarginal($(v_data))")
    elseif isa(signal.variant, InferenceSignalVariants.JointMarginal)
        print(io, "JointMarginal(?)")
    else
        error("Unknown signal variant: $(signal.variant)")
    end

    print(io, ")")

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

function trace_inference_execution(f::F, ::Nothing, variable_id, dependency::InferenceSignal) where {F}
    return f()
end

function trace_inference_execution(
    f::F,
    trace::Tuple{InferenceEngine, InferenceEngineTracer, Vector{TracedInferenceExecution}},
    variable_id,
    dependency::InferenceSignal
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
