@testitem "An empty inference round should be created for an empty model that has no pending messages" setup = [
    ModelUtils
] begin
    using .ModelUtils
    using JET

    @testset let model = Model()
        f1 = add_factor!(model.graph, Factor(:left))
        f2 = add_factor!(model.graph, Factor(:right))
        vc = add_variable!(model.graph, Variable(:center))

        add_edge!(model.graph, vc, f1, Edge())
        add_edge!(model.graph, vc, f2, Edge())

        inference_round = Cortex.create_inference_round(model, vc)
        inference_steps = collect(inference_round)

        @test length(inference_steps) == 0

        @test_opt Cortex.create_inference_round(model, vc)
        @test_opt collect(Cortex.create_inference_round(model, vc))
    end
end

@testitem "A non-empty inference round should be created for a model that has pending messages" setup = [ModelUtils] begin
    using .ModelUtils
    using JET

    function make_small_node_variable_node_model()
        model = Model()
        f1 = add_factor!(model.graph, Factor(:left))
        f2 = add_factor!(model.graph, Factor(:right))
        vc = add_variable!(model.graph, Variable(:center))

        add_edge!(model.graph, vc, f1, Edge())
        add_edge!(model.graph, vc, f2, Edge())

        return model, f1, f2, vc
    end

    # f1 -> vc is pending, should be in the inference round
    @testset let (model, f1, f2, vc) = make_small_node_variable_node_model()
        Cortex.set_pending!(Cortex.get_edge_message_to_variable(model, vc, f1))

        inference_round = Cortex.create_inference_round(model, vc)
        inference_steps = collect(inference_round)

        @test length(inference_steps) == 1
        @test inference_steps[1].message == Cortex.get_edge_message_to_variable(model, vc, f1)
        @test inference_steps[1].type == Cortex.InferenceStepType.MessageToVariable
        @test inference_steps[1].variable == vc
        @test inference_steps[1].factor == f1
    end

    # f2 -> vc is pending, should be in the inference round
    @testset let (model, f1, f2, vc) = make_small_node_variable_node_model()
        Cortex.set_pending!(Cortex.get_edge_message_to_variable(model, vc, f2))

        inference_round = Cortex.create_inference_round(model, vc)
        inference_steps = collect(inference_round)

        @test length(inference_steps) == 1
        @test inference_steps[1].message == Cortex.get_edge_message_to_variable(model, vc, f2)
        @test inference_steps[1].type == Cortex.InferenceStepType.MessageToVariable
        @test inference_steps[1].variable == vc
        @test inference_steps[1].factor == f2
    end

    # f1 -> vc and f2 -> vc are pending, should be in the inference round
    @testset let (model, f1, f2, vc) = make_small_node_variable_node_model()
        Cortex.set_pending!(Cortex.get_edge_message_to_variable(model, vc, f1))
        Cortex.set_pending!(Cortex.get_edge_message_to_variable(model, vc, f2))

        inference_round = Cortex.create_inference_round(model, vc)
        inference_steps = collect(inference_round)

        @test length(inference_steps) == 2
        @test inference_steps[1].message == Cortex.get_edge_message_to_variable(model, vc, f1)
        @test inference_steps[2].message == Cortex.get_edge_message_to_variable(model, vc, f2)
    end
end

@testitem "An inference round should contain first immediate dependencies of required messages" setup = [ModelUtils] begin
    using .ModelUtils
    using JET

    model = Model()

    v1 = add_variable!(model.graph, Variable(:v1))
    v2 = add_variable!(model.graph, Variable(:v2))
    v3 = add_variable!(model.graph, Variable(:v3))

    f1 = add_factor!(model.graph, Factor(:f1))
    f2 = add_factor!(model.graph, Factor(:f2))

    # |v1| - |f1| - |v2| - |f2| - |v3|
    add_edge!(model.graph, v1, f1, Edge())
    add_edge!(model.graph, v2, f1, Edge())
    add_edge!(model.graph, v2, f2, Edge())
    add_edge!(model.graph, v3, f2, Edge())
    
    Cortex.set_pending!(Cortex.get_edge_message_to_factor(model, v1, f1))
    Cortex.set_pending!(Cortex.get_edge_message_to_factor(model, v3, f2))

    inference_round = Cortex.create_inference_round(model, v2)
    inference_steps = collect(inference_round)

    @test length(inference_steps) == 2
    @test inference_steps[1].message == Cortex.get_edge_message_to_factor(model, v1, f1)
    @test inference_steps[2].message == Cortex.get_edge_message_to_factor(model, v3, f2)
        
end