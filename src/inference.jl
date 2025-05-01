
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
    # For each direct dependency of the marginal, we try to process it
    for dependency_of_marginal in get_dependencies(round.marginal)
        processed = process_dependency(processor, round, dependency_of_marginal)
        # If the dependency cannot be processed, we try its first direct dependency
        if !processed
            immediate_first_dependencies = get_dependencies(dependency_of_marginal)
            for dependency_of_dependency in immediate_first_dependencies
                process_dependency(processor, round, dependency_of_dependency)
            end
        end
    end
end

function process_dependency(processor::P, round::InferenceRound, signal::Signal) where {P}
    if is_pending(signal)
        if signal.type === InferenceSignalTypes.MessageToFactor
            processor(round, signal, signal.metadata::Tuple{Int, Int})
        elseif signal.type == InferenceSignalTypes.MessageToVariable
            processor(round, signal, signal.metadata::Tuple{Int, Int})
        else
            processor(round, signal, signal.metadata)
        end
        return true
    end
    return false
end

struct CollectedInferenceStep{M}
    round::InferenceRound{M}
    slot::Any
    dependency::Any
end

struct InferenceRoundCollector{M}
    steps::Vector{CollectedInferenceStep{M}}

    InferenceRoundCollector(::Type{M}) where {M} = new{M}(CollectedInferenceStep{M}[])
end

function (collector::InferenceRoundCollector{M})(
    round::InferenceRound{M}, slot::Signal, dependency::Any
) where {M}
    push!(collector.steps, CollectedInferenceStep{M}(round, slot, dependency))
end

function Base.collect(round::InferenceRound)
    collector = InferenceRoundCollector(typeof(round.model))
    process_inference_round(collector, round)
    return collector.steps
end
