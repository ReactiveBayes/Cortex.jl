using Cortex
using Test
using Aqua
using JET
using TestItemRunner

@testmodule TestUtils begin
    using Reexport
    @reexport using BipartiteFactorGraphs
    @reexport using Cortex

    export Variable, Factor, Connection

    # For testing purposes we define a simple `Variable` type that is used to test the inference engine
    # It contains a `marginal` field that is a `Signal` object.
    # A name and index are also stored to make it easier to identify the variable in tests.
    struct Variable
        name::Symbol
        index::Any
        marginal::Cortex.Signal

        function Variable(name, index...)
            return new(name, index, Cortex.Signal(type = Cortex.InferenceSignalTypes.IndividualMarginal))
        end
    end

    # For testing purposes we define a simple `Factor` type that is used to test the inference engine
    # It contains a `fform` field that is a symbol that represents the factor's form.
    struct Factor
        fform::Any
    end

    # For testing purposes we define a simple `Connection` type that is used to test the inference engine
    # It contains a `label` field that is a symbol that represents the connection's label, an `index` field that is an integer that represents the connection's index,
    # a `message_to_variable` field that is a `Signal` object that represents the message to the variable, 
    # and a `message_to_factor` field that is a `Signal` object that represents the message to the factor.
    struct Connection
        label::Symbol
        index::Int
        message_to_variable::Cortex.Signal
        message_to_factor::Cortex.Signal

        function Connection(variable_id, factor_id, label, index = 0)
            return new(
                label,
                index,
                Cortex.Signal(
                    type = Cortex.InferenceSignalTypes.MessageToVariable, metadata = (variable_id, factor_id)
                ),
                Cortex.Signal(type = Cortex.InferenceSignalTypes.MessageToFactor, metadata = (variable_id, factor_id))
            )
        end
    end

    # This is required to be implemented a variable data structure returned from the inference engine's backend
    Cortex.get_marginal(variable::Variable) = variable.marginal

    # This is required to be implemented a connection data structure returned from the inference engine's backend
    Cortex.get_connection_label(connection::Connection) = connection.label
    Cortex.get_connection_index(connection::Connection) = connection.index
    Cortex.get_message_to_variable(connection::Connection) = connection.message_to_variable
    Cortex.get_message_to_factor(connection::Connection) = connection.message_to_factor
end

@testset "Cortex.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(Cortex)
    end

    @testset "Code linting (JET.jl)" begin
        JET.test_package(Cortex; target_defined_modules = true)
    end

    TestItemRunner.@run_package_tests()
end
