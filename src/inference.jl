
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
                slot, dependency_wrapper = dependency
                if is_pending(round.model, dependency_wrapper) && !is_computed(round.model, dependency_wrapper)
                    # If they are, we need to process them
                    # Here we also manually dispatch on the type of dependency in order to avoid 
                    # expensive runtime dispatch
                    if dependency_wrapper.type == DependencyType.MessageToFactor
                        processor(round, dependency_wrapper.wrapped::MessageToFactor)
                    elseif dependency_wrapper.type == DependencyType.MessageToVariable
                        processor(round, dependency_wrapper.wrapped::MessageToVariable)
                    else
                        processor(round, dependency_wrapper.wrapped::AbstractDependency)
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
