@testitem "`BipartiteFactorGraphs` backend should be supported through extensions" begin
    using BipartiteFactorGraphs

    import Cortex: Variable, Factor, Connection

    graph = BipartiteFactorGraph(Variable, Factor, Connection)

    engine = Cortex.InferenceEngine(model_engine = graph)
    @test engine isa Cortex.InferenceEngine

    engine = Cortex.InferenceEngine(model_engine = graph, resolve_dependencies = false)
    @test engine isa Cortex.InferenceEngine

    engine = Cortex.InferenceEngine(model_engine = graph, prepare_signals_metadata = false)
    @test engine isa Cortex.InferenceEngine
end

@testitem "Test inference related functions for custom inference engine in `TestUtils`" setup = [TestUtils] begin
    using .TestUtils
    using BipartiteFactorGraphs

    graph = BipartiteFactorGraph(Variable, Factor, Connection)

    variable_id_1 = add_variable!(graph, Variable(name = :a))
    variable_id_2 = add_variable!(graph, Variable(name = :b, index = (1,)))
    variable_id_3 = add_variable!(graph, Variable(name = :c, index = (2, 3)))

    factor_id_1 = add_factor!(graph, Factor(functional_form = :f1))
    factor_id_2 = add_factor!(graph, Factor(functional_form = :f2))

    add_edge!(graph, variable_id_1, factor_id_1, Connection(label = :out))
    add_edge!(graph, variable_id_2, factor_id_2, Connection(label = :theta))

    inference_engine = Cortex.InferenceEngine(model_engine = graph)

    # Here we check that the variable data structure returned from the inference engine's backend is correct
    # But technically this is not required to be implemented and is not used in the inference engine
    @test Cortex.get_variable_name(Cortex.get_variable(inference_engine, variable_id_1)) == :a
    @test Cortex.get_variable_name(Cortex.get_variable(inference_engine, variable_id_2)) == :b
    @test Cortex.get_variable_name(Cortex.get_variable(inference_engine, variable_id_3)) == :c
    @test Cortex.get_variable_index(Cortex.get_variable(inference_engine, variable_id_1)) == nothing
    @test Cortex.get_variable_index(Cortex.get_variable(inference_engine, variable_id_2)) == (1,)
    @test Cortex.get_variable_index(Cortex.get_variable(inference_engine, variable_id_3)) == (2, 3)

    # We check that the marginal of the variable is a `Signal` object
    @test Cortex.get_variable_marginal(Cortex.get_variable(inference_engine, variable_id_1)) isa Cortex.Signal
    @test Cortex.get_variable_marginal(Cortex.get_variable(inference_engine, variable_id_2)) isa Cortex.Signal
    @test Cortex.get_variable_marginal(Cortex.get_variable(inference_engine, variable_id_3)) isa Cortex.Signal

    # We check that the factor data structure returned from the inference engine's backend is correct
    @test Cortex.get_factor_functional_form(Cortex.get_factor(inference_engine, factor_id_1)) === :f1
    @test Cortex.get_factor_functional_form(Cortex.get_factor(inference_engine, factor_id_2)) === :f2

    # Here we check that the connection data structure returned from the inference engine's backend is correct
    @test Cortex.get_connection(inference_engine, variable_id_1, factor_id_1) isa Connection
    @test Cortex.get_connection(inference_engine, variable_id_2, factor_id_2) isa Connection

    # Here we check that the connection label is correct
    @test Cortex.get_connection_label(Cortex.get_connection(inference_engine, variable_id_1, factor_id_1)) === :out
    @test Cortex.get_connection_label(Cortex.get_connection(inference_engine, variable_id_2, factor_id_2)) === :theta

    # Here we check that the message to variable is correct
    @test Cortex.get_connection_message_to_variable(
        Cortex.get_connection(inference_engine, variable_id_1, factor_id_1)
    ) isa Cortex.Signal
    @test Cortex.get_connection_message_to_variable(
        Cortex.get_connection(inference_engine, variable_id_2, factor_id_2)
    ) isa Cortex.Signal

    # Here we check that the message to factor is correct
    @test Cortex.get_connection_message_to_factor(
        Cortex.get_connection(inference_engine, variable_id_1, factor_id_1)
    ) isa Cortex.Signal
    @test Cortex.get_connection_message_to_factor(
        Cortex.get_connection(inference_engine, variable_id_2, factor_id_2)
    ) isa Cortex.Signal

    # Here we check that the message to variable is correct
    @test Cortex.get_connection_message_to_variable(inference_engine, variable_id_1, factor_id_1) ===
        Cortex.get_connection_message_to_variable(Cortex.get_connection(inference_engine, variable_id_1, factor_id_1))
    @test Cortex.get_connection_message_to_variable(inference_engine, variable_id_2, factor_id_2) ===
        Cortex.get_connection_message_to_variable(Cortex.get_connection(inference_engine, variable_id_2, factor_id_2))

    # Here we check that an error is thrown if the connection is not found
    @test_throws Exception Cortex.get_connection(inference_engine, variable_id_1, factor_id_2)
    @test_throws Exception Cortex.get_connection(inference_engine, variable_id_2, factor_id_1)

    # Here we check that the variables are correctly returned
    @test Set(Cortex.get_variable_ids(inference_engine)) == Set([variable_id_1, variable_id_2, variable_id_3])

    # Here we check that the factors are correctly returned
    @test Set(Cortex.get_factor_ids(inference_engine)) == Set([factor_id_1, factor_id_2])

    # Check that the connections are correctly returned
    @test Set(Cortex.get_connected_variable_ids(inference_engine, factor_id_1)) == Set([variable_id_1])
    @test Set(Cortex.get_connected_variable_ids(inference_engine, factor_id_2)) == Set([variable_id_2])

    # Check that the connections are correctly returned
    @test Set(Cortex.get_connected_factor_ids(inference_engine, variable_id_1)) == Set([factor_id_1])
    @test Set(Cortex.get_connected_factor_ids(inference_engine, variable_id_2)) == Set([factor_id_2])
    @test Set(Cortex.get_connected_factor_ids(inference_engine, variable_id_3)) == Set([])
end
