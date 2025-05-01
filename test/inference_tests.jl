@testitem "An empty inference round should be created for an empty model that has no pending messages" setup = [
    ModelUtils
] begin
    using .ModelUtils
    using JET

    @testset let model = Model()
        f1 = add_factor_to_model!(model, :left)
        f2 = add_factor_to_model!(model, :right)
        vc = add_variable_to_model!(model, :center)

        add_edge_to_model!(model, vc, f1)
        add_edge_to_model!(model, vc, f2)

        inference_round = Cortex.create_inference_round(model, vc)
        inference_steps = collect(inference_round)

        @test length(inference_steps) == 0
    end
end

@testitem "A non-empty inference round should be created for a model that has pending messages" setup = [ModelUtils] begin
    using .ModelUtils
    using JET

    function make_small_node_variable_node_model()
        model = Model()

        f1 = add_factor_to_model!(model, :left)
        f2 = add_factor_to_model!(model, :right)
        vc = add_variable_to_model!(model, :center)

        add_edge_to_model!(model, vc, f1)
        add_edge_to_model!(model, vc, f2)

        vm = Cortex.get_variable_marginal(model, vc)

        left = Cortex.Signal()
        right = Cortex.Signal()

        Cortex.add_dependency!(Cortex.get_edge_message_to_variable(model, vc, f1), left)
        Cortex.add_dependency!(Cortex.get_edge_message_to_variable(model, vc, f2), right)

        Cortex.add_dependency!(vm, Cortex.get_edge_message_to_variable(model, vc, f1))
        Cortex.add_dependency!(vm, Cortex.get_edge_message_to_variable(model, vc, f2))

        return model, f1, f2, vc, left, right
    end

    # f1 -> vc is pending, should be in the inference round
    @testset let (model, f1, f2, vc, left, right) = make_small_node_variable_node_model()
        Cortex.set_value!(left, 1.0)

        inference_round = Cortex.create_inference_round(model, vc)
        inference_steps = collect(inference_round)

        @test length(inference_steps) == 1
        @test inference_steps[1] == Cortex.get_edge_message_to_variable(model, vc, f1)
    end

    # f2 -> vc is pending, should be in the inference round
    @testset let (model, f1, f2, vc, left, right) = make_small_node_variable_node_model()
        Cortex.set_value!(right, 1.0)

        inference_round = Cortex.create_inference_round(model, vc)
        inference_steps = collect(inference_round)

        @test length(inference_steps) == 1
        @test inference_steps[1] == Cortex.get_edge_message_to_variable(model, vc, f2)
    end

    # f1 -> vc and f2 -> vc are pending, should be in the inference round
    @testset let (model, f1, f2, vc, left, right) = make_small_node_variable_node_model()
        Cortex.set_value!(left, 1.0)
        Cortex.set_value!(right, 1.0)

        inference_round = Cortex.create_inference_round(model, vc)
        inference_steps = collect(inference_round)

        @test length(inference_steps) == 2
        @test inference_steps[1] == Cortex.get_edge_message_to_variable(model, vc, f1)
        @test inference_steps[2] == Cortex.get_edge_message_to_variable(model, vc, f2)
    end
end

@testitem "An inference round should correctly resolve dependencies of required messages" setup = [ModelUtils] begin
    using .ModelUtils
    using JET

    model = Model()

    v1 = add_variable_to_model!(model, :v1)
    v2 = add_variable_to_model!(model, :v2)
    v3 = add_variable_to_model!(model, :v3)

    f1 = add_factor_to_model!(model, :f1)
    f2 = add_factor_to_model!(model, :f2)

    # |v1| - |f1| - |v2| - |f2| - |v3|
    add_edge_to_model!(model, v1, f1)
    add_edge_to_model!(model, v2, f1)
    add_edge_to_model!(model, v2, f2)
    add_edge_to_model!(model, v3, f2)

    # A message from f1 to v2 depends on a message from v1 to f1
    Cortex.add_dependency!(
        Cortex.get_edge_message_to_variable(model, v2, f1), Cortex.get_edge_message_to_factor(model, v1, f1)
    )

    # A message from f2 to v2 depends on a message from v3 to f2
    Cortex.add_dependency!(
        Cortex.get_edge_message_to_variable(model, v2, f2), Cortex.get_edge_message_to_factor(model, v3, f2)
    )

    # A marginal for v2 depends on a message f1 to v2 and a message f2 to v2
    Cortex.add_dependency!(Cortex.get_variable_marginal(model, v2), Cortex.get_edge_message_to_variable(model, v2, f1))

    Cortex.add_dependency!(Cortex.get_variable_marginal(model, v2), Cortex.get_edge_message_to_variable(model, v2, f2))

    # We set pending messages from v1 to f1 and v3 to f2
    # Since they are direct dependencies of messages to v2, they should be added to the inference round
    Cortex.set_value!(Cortex.get_edge_message_to_factor(model, v1, f1), 1.0)
    Cortex.set_value!(Cortex.get_edge_message_to_factor(model, v3, f2), 1.0)

    inference_round = Cortex.create_inference_round(model, v2)
    inference_steps = collect(inference_round)

    @test length(inference_steps) == 2
    @test inference_steps[1] == Cortex.get_edge_message_to_variable(model, v2, f1)
    @test inference_steps[2] == Cortex.get_edge_message_to_variable(model, v2, f2)
end

@testitem "An inference in a simple IID model" setup = [ModelUtils] begin
    using .ModelUtils
    using JET, BipartiteFactorGraphs

    model = Model()

    # The "center" of the model
    p = add_variable_to_model!(model, :p)

    # The observed outcomes
    o1 = add_variable_to_model!(model, :y1)
    o2 = add_variable_to_model!(model, :y2)

    # Priors
    fp = add_factor_to_model!(model, :prior)

    # Likelihoods
    f1 = add_factor_to_model!(model, :likelihood)
    f2 = add_factor_to_model!(model, :likelihood)

    # Connections between the parameter `p` and the factors
    add_edge_to_model!(model, p, fp)
    add_edge_to_model!(model, p, f1)
    add_edge_to_model!(model, p, f2)

    # Connections between the observed outcomes and the likelihoods
    add_edge_to_model!(model, o1, f1)
    add_edge_to_model!(model, o2, f2)

    resolve_dependencies!(model, BeliefPropagation())

    # Set data
    Cortex.set_value!(Cortex.get_edge_message_to_factor(model, o1, f1), 1)
    Cortex.set_value!(Cortex.get_edge_message_to_factor(model, o2, f2), 2)

    # Set prior
    Cortex.set_value!(Cortex.get_edge_message_to_variable(model, p, fp), 3)

    function computer(signal::Cortex.Signal, dependencies::Vector{Cortex.Signal})

        if signal.type == Cortex.InferenceSignalTypes.MessageToVariable
            v, f = signal.metadata
            
            factor = get_factor_data(model.graph, f)

            if factor.type === :likelihood
                return 2 * Cortex.get_value(dependencies[1])
            elseif factor.type === :prior
                error("Should not be invoked")
            end
        elseif signal.type == Cortex.InferenceSignalTypes.IndividualMarginal
            return sum(Cortex.get_value.(dependencies))
        end

        error("Unreachable reached")
    end

    Cortex.update_posterior!(model, Cortex.InferenceRoundComputer(computer), p)

    @test Cortex.get_value(Cortex.get_variable_marginal(model, p)) == 9
end

