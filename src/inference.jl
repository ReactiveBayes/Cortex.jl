
struct InferenceRound{M}
    model::M
    variable::Int
end

function create_inference_round(model, variable)
    return InferenceRound(model, variable)
end

function process_inference_round(processor::P, round::InferenceRound) where {P}
    vi = round.variable
    # In order to compute a posterior over a variable, we need to compute all messages pointing to it
    # from its neighboring factors
    for fi in get_variable_neighbors(round.model, vi)
        # First we check if directly required slots are pending and not computed
        slot = Cortex.get_edge_message_to_variable(round.model, vi, fi)
        if is_pending(slot) && !is_computed(slot)
            # If they are, we need to process them
            processor(round, MessageToVariable(vi, fi))
        else
            # If they are not, we need to check if any of the dependencies of the slot are pending
            for dependency in slot.dependencies
                if is_pending(round.model, dependency) && !is_computed(round.model, dependency)
                    # If they are, we need to process them
                    # Here we also manually dispatch on the type of dependency in order to avoid 
                    # expensive runtime dispatch
                    if dependency.type == DependencyType.MessageToFactor
                        processor(round, dependency.wrapped::MessageToFactor)
                    elseif dependency.type == DependencyType.MessageToVariable
                        processor(round, dependency.wrapped::MessageToVariable)
                    else
                        processor(round, dependency.wrapped::AbstractDependency)
                    end
                end
            end
        end
    end
end

struct InferenceRoundCollector
    steps::Vector{AbstractDependency}

    InferenceRoundCollector() = new(AbstractDependency[])
end

function (collector::InferenceRoundCollector)(::InferenceRound, step::AbstractDependency)
    push!(collector.steps, step)
end

function Base.collect(round::InferenceRound)
    collector = InferenceRoundCollector()
    process_inference_round(collector, round)
    return collector.steps
end
