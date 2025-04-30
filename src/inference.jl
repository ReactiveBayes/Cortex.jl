
struct InferenceRound{M}
    model::M
    marginal::Slot
end

function create_inference_round(model, variable)
    return InferenceRound(model, Cortex.get_variable_marginal(model, variable))
end

function process_inference_round(processor::P, round::InferenceRound) where {P}
    # For each direct dependency of the marginal, we try to process it
    for md in round.marginal.dependencies
        processed = process_dependency(processor, round, md)
        # If the dependency cannot be processed, we try its first direct dependency
        if !processed 
            slot, _ = md
            for sd in slot.dependencies
                process_dependency(processor, round, sd)
            end
        end
    end
end

function process_dependency(processor::P, round::InferenceRound, t::Tuple{Slot, Dependency}) where {P}
    slot, dependency = t
    if !is_computed(slot) && is_pending(slot)   
        if dependency.type == DependencyType.MessageToFactor
            processor(round, slot, dependency.wrapped::MessageToFactor)
        elseif dependency.type == DependencyType.MessageToVariable
            processor(round, slot, dependency.wrapped::MessageToVariable)
        else
            processor(round, slot, dependency.wrapped::AbstractDependency)
        end
        return true
    end
    return false
end

struct CollectedInferenceStep{M}
    round::InferenceRound{M}
    slot::Slot
    dependency::AbstractDependency
end

struct InferenceRoundCollector{M}
    steps::Vector{CollectedInferenceStep{M}}

    InferenceRoundCollector(::Type{M}) where {M} = new{M}(CollectedInferenceStep{M}[])
end

function (collector::InferenceRoundCollector{M})(round::InferenceRound{M}, slot::Slot, dependency::AbstractDependency) where {M}
    push!(collector.steps, CollectedInferenceStep{M}(round, slot, dependency))
end

function Base.collect(round::InferenceRound)
    collector = InferenceRoundCollector(typeof(round.model))
    process_inference_round(collector, round)
    return collector.steps
end
