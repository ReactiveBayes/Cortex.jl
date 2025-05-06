
module InferenceSignalTypes
const MessageToVariable = UInt8(0x01)
const MessageToFactor = UInt8(0x02)
const IndividualMarginal = UInt8(0x03)
const JointMarginal = UInt8(0x04)
end

struct InferenceTask{M}
    model::M
    marginal::Signal
end

function create_inference_task(model, variable)
    return InferenceTask(model, Cortex.get_variable_marginal(model, variable))
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

function (computer::InferenceTaskComputer)(task::InferenceTask, signal::Signal)
    compute!(signal) do signal, dependencies
        computer.f(task.model, signal, dependencies)
    end
end

struct VerboseTaskComputer{F}
    f::F
end

function update_posterior!(f::F, model::AbstractCortexModel, variable::VariableId) where {F <: Function}
    should_continue = true

    callback = InferenceTaskComputer(f)
    task = create_inference_task(model, variable)

    while should_continue
        should_continue = process_inference_task(callback, task)
    end

    callback(task, task.marginal)

    return nothing
end

function update_posterior!(
    f::F, model::AbstractCortexModel, variables::Vector{V}
) where {F <: Function, V <: VariableId}
    should_continue = true

    callback = InferenceTaskComputer(f)

    tasks = [create_inference_task(model, variable) for variable in variables]
    tmask = falses(length(tasks))

    indices         = 1:1:length(tasks)
    indices_reverse = reverse(indices)

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

                if !task_has_been_processed_at_least_once
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
        callback(task, task.marginal)
    end

    return nothing
end
