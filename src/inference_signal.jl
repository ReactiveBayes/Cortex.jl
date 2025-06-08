
using Moshi.Data: @data
using Moshi.Derive: @derive

@data InferenceSignalVariants begin
    # A variant that is used by default when no other variant is specified
    Unspecified

    # A message from a factor to a variable
    struct MessageToFactor
        variable_id::Int
        factor_id::Int
    end

    # A message from a variable to a factor
    struct MessageToVariable
        variable_id::Int
        factor_id::Int
    end

    # A product of messages from a variable to a factor
    struct ProductOfMessages
        variable_id::Int
        range::UnitRange{Int}
        factors_connected_to_variable::Vector{Int}
    end

    # An individual marginal of a variable
    struct IndividualMarginal
        variable_id::Int
    end

    # A joint marginal of a factor
    struct JointMarginal
        factor_id::Int
        variable_ids::Vector{Int}
    end
end

# Automatically derive the hash, equality, and show methods for the inference signal variant data type
@derive InferenceSignalVariants[Hash, Eq, Show]

"""
The type representing all possible variants of an inference signal.
"""
const InferenceSignalVariant = InferenceSignalVariants.Type

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
