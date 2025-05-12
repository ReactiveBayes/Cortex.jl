struct InferenceEngine{M}
    model_backend::M

    function InferenceEngine(; model_backend::M) where {M}
        return new{M}(throw_if_backend_unsupported(model_backend))
    end
end

get_model_backend(engine::InferenceEngine) = engine.model_backend

struct UnsupportedModelBackendError{B} <: Exception
    backend::B
end

function Base.showerror(io::IO, e::UnsupportedModelBackendError)
    print(io, "The model backend of type `$(typeof(e.backend))` is not supported.")
end

struct SupportedModelBackend end
struct UnsupportedModelBackend end

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
get_connection(engine::InferenceEngine, variable_id, factor_id) =
    get_connection(get_model_backend(engine), variable_id, factor_id)

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
get_connection_label(engine::InferenceEngine, variable_id, factor_id) =
    get_connection_label(get_connection(engine, variable_id, factor_id))

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
get_connection_index(engine::InferenceEngine, variable_id, factor_id) =
    get_connection_index(get_connection(engine, variable_id, factor_id))

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
get_message_to_variable(engine::InferenceEngine, variable_id, factor_id) =
    get_message_to_variable(get_connection(engine, variable_id, factor_id))

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
get_message_to_factor(engine::InferenceEngine, variable_id, factor_id) =
    get_message_to_factor(get_connection(engine, variable_id, factor_id))

"""
    get_connected_variable_ids(engine::InferenceEngine, factor_id)

Get an iterator over ids of variables connected to a factor.
This function must be implemented for each model backend as it simply calls the `get_connections_by_factor_id` function of the engine's backend.

See also: [`get_connection`](@ref)
"""
get_connected_variable_ids(engine::InferenceEngine, factor_id) =
    get_connected_variable_ids(get_model_backend(engine), factor_id)

"""
    get_connected_factor_ids(engine::InferenceEngine, variable_id)

Get an iterator over ids of factors connected to a variable.
This function must be implemented for each model backend as it simply calls the `get_connections_by_variable_id` function of the engine's backend.

See also: [`get_connection`](@ref)
"""
get_connected_factor_ids(engine::InferenceEngine, variable_id) =
    get_connected_factor_ids(get_model_backend(engine), variable_id)

module InferenceSignalTypes
const MessageToVariable = UInt8(0x01)
const MessageToFactor = UInt8(0x02)
const IndividualMarginal = UInt8(0x03)
const JointMarginal = UInt8(0x04)
end

struct InferenceTask{E}
    engine::E
    marginal::Cortex.Signal
end

function create_inference_task(engine::InferenceEngine, variable)
    marginal = get_marginal(engine, variable)
    for dependency in get_dependencies(marginal)
        dependency.props = SignalProps(is_potentially_pending = true, is_pending = false)
    end
    return InferenceTask(engine, marginal)
end

function process_inference_task(callback::F, task::InferenceTask) where {F}
    processed_at_least_once = process_dependencies!(task.marginal; retry = true) do dependency
        if is_pending(dependency)
            callback(task, dependency)
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

function (scanner::InferenceTaskScanner)(::InferenceTask, signal::Signal)
    push!(scanner.signals, signal)
end

function scan_inference_task(task::InferenceTask)
    scanner = InferenceTaskScanner()
    process_inference_task(scanner, task)
    return scanner.signals
end

struct InferenceTaskComputer{F}
    f::F
end

function (computer::InferenceTaskComputer)(task::InferenceTask, signal::Signal; force = false)
    compute!(signal; force = force) do signal, dependencies
        computer.f(task.engine, signal, dependencies)
    end
end

struct VerboseTaskComputer{F}
    f::F
end

function update_posterior!(f::F, engine::InferenceEngine, variable_id) where {F <: Function}
    should_continue = true

    callback = InferenceTaskComputer(f)
    task = create_inference_task(engine, variable_id)

    while should_continue
        should_continue = process_inference_task(callback, task)
    end

    callback(task, task.marginal)

    return nothing
end

function update_posterior!(f::F, engine::InferenceEngine, variable_ids::AbstractVector) where {F <: Function}
    should_continue = true

    callback = InferenceTaskComputer(f)

    tasks = [create_inference_task(engine, variable) for variable in variable_ids]
    tmask = falses(length(tasks))

    indices         = 1:1:length(tasks)
    indices_reverse = reverse(indices)::typeof(indices)

    # We begin with a forward pass
    # After each pass, we alternate the order
    is_reverse = false

    while should_continue
        _should_continue = false

        current_order = is_reverse ? indices_reverse : indices

        @inbounds for i in current_order
            if !tmask[i]
                task = tasks[i]
                task_has_been_processed_at_least_once = process_inference_task(callback, task)

                if is_pending(task.marginal)
                    tmask[i] = true
                end

                _should_continue = _should_continue || task_has_been_processed_at_least_once
            end
        end

        # Alternate between forward and backward order
        is_reverse = !is_reverse

        should_continue = _should_continue
    end

    for task in tasks
        callback(task, task.marginal; force = true)
    end

    return nothing
end
