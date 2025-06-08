
"""
    InferenceSignalVariants

A module containing the different variants of inference signals used in the inference engine.
These variants define the structure and behavior of messages passed between variables and factors.
"""
module InferenceSignalVariants

"""
    Unspecified

The default variant used when no specific signal variant has been assigned.
Computation rules for this variant are not defined and will throw an error.
"""
struct Unspecified end

"""
    MessageToFactor(variable_id::Int, factor_id::Int)

A message from a variable to a factor in a probabilistic graphical model.

# Fields
- `variable_id::Int`: The ID of the source variable sending the message
- `factor_id::Int`: The ID of the target factor receiving the message

See also [`Cortex.compute_message_to_factor!`](@ref).
"""
struct MessageToFactor
    variable_id::Int
    factor_id::Int
end

"""
    MessageToVariable(variable_id::Int, factor_id::Int)

A message from a factor to a variable in a probabilistic graphical model.

# Fields
- `variable_id::Int`: The ID of the target variable receiving the message
- `factor_id::Int`: The ID of the source factor sending the message

See also [`Cortex.compute_message_to_variable!`](@ref).
"""
struct MessageToVariable
    variable_id::Int
    factor_id::Int
end

"""
    ProductOfMessages(variable_id::Int, range::UnitRange{Int}, factors_connected_to_variable::Vector{Int})

A signal variant representing the product of multiple messages for a specific variable.

# Fields
- `variable_id::Int`: The ID of the source variable
- `range::UnitRange{Int}`: Range specification for selecting messages from which factors to include
- `factors_connected_to_variable::Vector{Int}`: Complete list of factor IDs connected to the variable

See also [`Cortex.compute_product_of_messages!`](@ref).
"""
struct ProductOfMessages
    variable_id::Int
    range::UnitRange{Int}
    factors_connected_to_variable::Vector{Int}
end

"""
    IndividualMarginal(variable_id::Int)

A signal variant representing the marginal distribution of a single variable.

# Fields
- `variable_id::Int`: The ID of the variable whose marginal is represented

See also [`Cortex.compute_individual_marginal!`](@ref).
"""
struct IndividualMarginal
    variable_id::Int
end

"""
    JointMarginal(factor_id::Int, variable_ids::Vector{Int})

A signal variant representing the joint marginal distribution over multiple variables connected to a specific factor.

# Fields
- `factor_id::Int`: The ID of the factor around which the joint marginal is computed
- `variable_ids::Vector{Int}`: The IDs of variables included in the joint marginal

See also [`Cortex.compute_joint_marginal!`](@ref).
"""
struct JointMarginal
    factor_id::Int
    variable_ids::Vector{Int}
end
end

"""
    InferenceSignalVariant

A Union type representing all possible variants of an inference signal.

This type alias encompasses all the concrete variant types defined in the 
[`InferenceSignalVariants`](@ref) module, providing type-safe signal classification
for the inference engine.
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
    InferenceSignal

A specialized signal type for probabilistic inference with variant-based dispatch.

This type alias represents a [`Signal`](@ref) with value type `Any` and variant 
type [`InferenceSignalVariant`](@ref). It provides type-safe signal handling 
specific to inference operations, enabling efficient dispatch based on signal variants.

All inference signals are created with [`create_inference_signal`](@ref) and their
variants are defined in the [`InferenceSignalVariants`](@ref) module.
"""
const InferenceSignal = Signal{Any, InferenceSignalVariant}

"""
    create_inference_signal()::InferenceSignal

Create a new inference signal with an [`Unspecified`](@ref InferenceSignalVariants.Unspecified) variant.

The created signal has an undefined value ([`UndefValue`](@ref)) and an unspecified
variant. Use [`Cortex.set_variant!`](@ref) to assign a specific variant from the
[`InferenceSignalVariants`](@ref) module before using the signal in inference.
"""
function create_inference_signal()::InferenceSignal
    return Signal(Any, InferenceSignalVariant, UndefValue(), InferenceSignalVariants.Unspecified())
end
