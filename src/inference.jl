
module InferenceStepType
const MessageToVariable::UInt8 = 0x1
const MessageToFactor::UInt8 = 0x2
end

struct InferenceStep
    message::Value
    type::UInt8
    variable::Int
    factor::Int
end

struct InferenceRound{M}
    model::M
    variable::Int
end

function create_inference_round(model, variable)
    return InferenceRound(model, variable)
end

function process_inference_round(processor::P, round::InferenceRound) where {P}
    vi = round.variable
    for fi in get_variable_neighbors(round.model, vi)
        message = Cortex.get_edge_message_to_variable(round.model, vi, fi)
        # First we check if the required messages are pending and not computed
        # If they are, we need to process them
        if is_pending(message) && !is_computed(message)
            processor(round, InferenceStep(message, InferenceStepType.MessageToVariable, vi, fi))
        else 

        end
    end
end

struct InferenceRoundCollector
    steps::Vector{InferenceStep}

    InferenceRoundCollector() = new(InferenceStep[])
end

function (collector::InferenceRoundCollector)(::InferenceRound, step::InferenceStep)
    push!(collector.steps, step)
end

function Base.collect(round::InferenceRound)
    collector = InferenceRoundCollector()
    process_inference_round(collector, round)
    return collector.steps
end


