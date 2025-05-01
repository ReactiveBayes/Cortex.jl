
module InferenceSignalTypes
const MessageToVariable = UInt8(0x01)
const MessageToFactor = UInt8(0x02)
const IndividualMarginal = UInt8(0x03)
const JointMarginal = UInt8(0x04)
end

struct InferenceRound{M}
    model::M
    marginal::Signal
end

function create_inference_round(model, variable)
    return InferenceRound(model, Cortex.get_variable_marginal(model, variable))
end

function process_inference_round(processor::P, round::InferenceRound) where {P}
    processed_at_least_once = false
    # For each direct dependency of the marginal, we try to process it
    for dependency_of_marginal in get_dependencies(round.marginal)
        processed = process_dependency(processor, round, dependency_of_marginal)
        # If the dependency cannot be processed, we try its first direct dependency
        if !processed
            immediate_first_dependencies = get_dependencies(dependency_of_marginal)
            for dependency_of_dependency in immediate_first_dependencies
                if process_dependency(processor, round, dependency_of_dependency)
                    processed_at_least_once = true
                end
            end
        else
            processed_at_least_once = true
        end
    end
    return processed_at_least_once
end

function process_dependency(processor::P, round::InferenceRound, signal::Signal) where {P}
    if is_pending(signal)
        processor(round, signal)
        return true
    end
    return false
end

struct InferenceRoundCollector
    signals::Vector{Signal}

    InferenceRoundCollector() = new(Signal[])
end

function (collector::InferenceRoundCollector)(::InferenceRound, signal::Signal)
    push!(collector.signals, signal)
end

function Base.collect(round::InferenceRound)
    collector = InferenceRoundCollector()
    process_inference_round(collector, round)
    return collector.signals
end

struct InferenceRoundComputer{F}
    computer::F
end

function (computer::InferenceRoundComputer)(round::InferenceRound, signal::Signal)
    compute!(computer.computer, signal)
end

function update_posterior!(model::AbstractCortexModel, computer::InferenceRoundComputer, variable::VariableId) where {P}
    should_continue = true

    round = create_inference_round(model, variable)

    while should_continue
        should_continue = process_inference_round(computer, round)
    end

    compute!(computer.computer, round.marginal)
    
    return nothing
end