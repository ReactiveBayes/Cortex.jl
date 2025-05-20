@testitem "`BipartiteFactorGraphs` backend should be supported through extensions" begin
    using BipartiteFactorGraphs

    graph = BipartiteFactorGraph()

    engine = Cortex.InferenceEngine(model_backend = graph)
    @test engine isa Cortex.InferenceEngine

    engine = Cortex.InferenceEngine(model_backend = graph, resolve_dependencies = false)
    @test engine isa Cortex.InferenceEngine

    engine = Cortex.InferenceEngine(model_backend = graph, prepare_signals_metadata = false)
    @test engine isa Cortex.InferenceEngine
end

@testitem "Test inference related functions for custom inference engine in `TestUtils`" setup = [TestUtils] begin
    using .TestUtils
    using BipartiteFactorGraphs

    graph = BipartiteFactorGraph()

    variable_id_1 = add_variable!(graph, Variable(:a))
    variable_id_2 = add_variable!(graph, Variable(:b, 1))
    variable_id_3 = add_variable!(graph, Variable(:c, 2, 3))

    factor_id_1 = add_factor!(graph, Factor(:f1))
    factor_id_2 = add_factor!(graph, Factor(:f2))

    add_edge!(graph, variable_id_1, factor_id_1, Connection(:out))
    add_edge!(graph, variable_id_2, factor_id_2, Connection(:theta))

    inference_engine = Cortex.InferenceEngine(model_backend = graph)

    # Here we check that the variable data structure returned from the inference engine's backend is correct
    # But technically this is not required to be implemented and is not used in the inference engine
    @test Cortex.get_variable_data(inference_engine, variable_id_1).name == :a
    @test Cortex.get_variable_data(inference_engine, variable_id_2).name == :b
    @test Cortex.get_variable_data(inference_engine, variable_id_3).name == :c
    @test Cortex.get_variable_data(inference_engine, variable_id_1).index == ()
    @test Cortex.get_variable_data(inference_engine, variable_id_2).index == (1,)
    @test Cortex.get_variable_data(inference_engine, variable_id_3).index == (2, 3)

    # We check that the marginal of the variable is a `Signal` object
    @test Cortex.get_marginal(Cortex.get_variable_data(inference_engine, variable_id_1)) isa Cortex.Signal
    @test Cortex.get_marginal(Cortex.get_variable_data(inference_engine, variable_id_2)) isa Cortex.Signal
    @test Cortex.get_marginal(Cortex.get_variable_data(inference_engine, variable_id_3)) isa Cortex.Signal

    # We check that the marginal of the variable is the same as the one returned from the inference engine's backend
    @test Cortex.get_marginal(inference_engine, variable_id_1) ===
        Cortex.get_marginal(Cortex.get_variable_data(inference_engine, variable_id_1))
    @test Cortex.get_marginal(inference_engine, variable_id_2) ===
        Cortex.get_marginal(Cortex.get_variable_data(inference_engine, variable_id_2))
    @test Cortex.get_marginal(inference_engine, variable_id_3) ===
        Cortex.get_marginal(Cortex.get_variable_data(inference_engine, variable_id_3))

    # We check that the factor data structure returned from the inference engine's backend is correct
    @test Cortex.get_factor_data(inference_engine, factor_id_1).fform === :f1
    @test Cortex.get_factor_data(inference_engine, factor_id_2).fform === :f2

    # Here we check that the connection data structure returned from the inference engine's backend is correct
    @test Cortex.get_connection(inference_engine, variable_id_1, factor_id_1) isa Connection
    @test Cortex.get_connection(inference_engine, variable_id_2, factor_id_2) isa Connection

    # Here we check that the connection label is correct
    @test Cortex.get_connection_label(Cortex.get_connection(inference_engine, variable_id_1, factor_id_1)) === :out
    @test Cortex.get_connection_label(Cortex.get_connection(inference_engine, variable_id_2, factor_id_2)) === :theta

    # Here we check that the connection label is correct
    @test Cortex.get_connection_label(inference_engine, variable_id_1, factor_id_1) ===
        Cortex.get_connection_label(Cortex.get_connection(inference_engine, variable_id_1, factor_id_1))
    @test Cortex.get_connection_label(inference_engine, variable_id_2, factor_id_2) ===
        Cortex.get_connection_label(Cortex.get_connection(inference_engine, variable_id_2, factor_id_2))

    # Here we check that the connection index is correct
    @test Cortex.get_connection_index(Cortex.get_connection(inference_engine, variable_id_1, factor_id_1)) === 0
    @test Cortex.get_connection_index(Cortex.get_connection(inference_engine, variable_id_2, factor_id_2)) === 0

    # Here we check that the message to variable is correct
    @test Cortex.get_message_to_variable(Cortex.get_connection(inference_engine, variable_id_1, factor_id_1)) isa
        Cortex.Signal
    @test Cortex.get_message_to_variable(Cortex.get_connection(inference_engine, variable_id_2, factor_id_2)) isa
        Cortex.Signal

    # Here we check that the message to factor is correct
    @test Cortex.get_message_to_factor(Cortex.get_connection(inference_engine, variable_id_1, factor_id_1)) isa
        Cortex.Signal
    @test Cortex.get_message_to_factor(Cortex.get_connection(inference_engine, variable_id_2, factor_id_2)) isa
        Cortex.Signal

    # Here we check that the message to variable is correct
    @test Cortex.get_message_to_variable(inference_engine, variable_id_1, factor_id_1) ===
        Cortex.get_message_to_variable(Cortex.get_connection(inference_engine, variable_id_1, factor_id_1))
    @test Cortex.get_message_to_variable(inference_engine, variable_id_2, factor_id_2) ===
        Cortex.get_message_to_variable(Cortex.get_connection(inference_engine, variable_id_2, factor_id_2))

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
