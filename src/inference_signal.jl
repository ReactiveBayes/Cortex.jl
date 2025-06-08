
"""
    InferenceSignalVariants

A module containing the different variants of inference signals used in the inference engine.
These variants define the structure and behavior of messages passed between variables and factors.
"""
module InferenceSignalVariants

"""
    Unspecified

A variant that is used by default when no other variant is specified.
"""
struct Unspecified end

"""
    MessageToFactor

A message from a factor to a variable.

# Fields
- `variable_id::Int`: The ID of the target variable
- `factor_id::Int`: The ID of the source factor
"""
struct MessageToFactor
    variable_id::Int
    factor_id::Int
end

"""
    MessageToVariable

A message from a variable to a factor.

# Fields
- `variable_id::Int`: The ID of the source variable
- `factor_id::Int`: The ID of the target factor
"""
struct MessageToVariable
    variable_id::Int
    factor_id::Int
end

"""
    ProductOfMessages

A product of messages from a variable to multiple factors.

# Fields
- `variable_id::Int`: The ID of the source variable
- `range::UnitRange{Int}`: The range of factor IDs
- `factors_connected_to_variable::Vector{Int}`: The IDs of factors connected to the variable
"""
struct ProductOfMessages
    variable_id::Int
    range::UnitRange{Int}
    factors_connected_to_variable::Vector{Int}
end

"""
    IndividualMarginal

An individual marginal of a variable.

# Fields
- `variable_id::Int`: The ID of the variable
"""
struct IndividualMarginal
    variable_id::Int
end

"""
    JointMarginal

A joint marginal of a factor.

# Fields
- `factor_id::Int`: The ID of the factor
- `variable_ids::Vector{Int}`: The IDs of variables connected to the factor
"""
struct JointMarginal
    factor_id::Int
    variable_ids::Vector{Int}
end
end

"""
The type representing all possible variants of an inference signal.
"""
const InferenceSignalVariant = Union{
    InferenceSignalVariants.Unspecified,
    InferenceSignalVariants.MessageToFactor,
    InferenceSignalVariants.MessageToVariable,
    InferenceSignalVariants.ProductOfMessages,
    InferenceSignalVariants.IndividualMarginal,
    InferenceSignalVariants.JointMarginal
}

"""
A special type of signal that is used to represent signals that are used in inference.
See also [`create_inference_signal`](@ref) for creating an inference signal.
The `InferenceSignal` variants are defined in [`InferenceSignalVariants`](@ref).
"""
const InferenceSignal = Signal{Any, InferenceSignalVariant}

"""
    create_inference_signal()::InferenceSignal

Create an inference signal with an unspecified variant. `Cortex.set_variant!` should be used to set the variant of the signal.
See also [`InferenceSignalVariants`](@ref) for the possible variants.
"""
function create_inference_signal()::InferenceSignal
    return Signal(Any, InferenceSignalVariant, UndefValue(), InferenceSignalVariants.Unspecified())
end
