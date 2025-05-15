@testitem "It should not be possible to create an inference engine for an unsupported model backend" begin
    import Cortex: UnsupportedModelBackendError

    @test_throws UnsupportedModelBackendError(1) Cortex.InferenceEngine(model_backend = 1)
    @test_throws UnsupportedModelBackendError("string") Cortex.InferenceEngine(model_backend = "string")

    @test_throws "The model backend of type `Int64` is not supported." Cortex.InferenceEngine(model_backend = 1)
    @test_throws "The model backend of type `String` is not supported." Cortex.InferenceEngine(model_backend = "string")
end

@testitem "`BipartiteFactorGraphs` backend should be supported through extensions" begin
    using BipartiteFactorGraphs

    graph = BipartiteFactorGraphs.BipartiteFactorGraph()

    engine = Cortex.InferenceEngine(model_backend = graph)

    # This test checks that the inference engine is created without errors
    @test engine isa Cortex.InferenceEngine
end

@testitem "Test inference related functions for custom inference engine in `TestUtils`" setup = [TestUtils] begin
    using .TestUtils
    using BipartiteFactorGraphs

    graph = BipartiteFactorGraph()

    variable_id_1 = add_variable!(graph, Variable(:a))
    variable_id_2 = add_variable!(graph, Variable(:b, 1))
    variable_id_3 = add_variable!(graph, Variable(:c, 2, 3))

    inference_engine = Cortex.InferenceEngine(model_backend = graph, resolve_dependencies = false)

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

    # Here we check that the factor data structure returned from the inference engine's backend is correct
    factor_id_1 = add_factor!(graph, Factor(:f1))
    factor_id_2 = add_factor!(graph, Factor(:f2))

    # We check that the factor data structure returned from the inference engine's backend is correct
    @test Cortex.get_factor_data(inference_engine, factor_id_1).fform === :f1
    @test Cortex.get_factor_data(inference_engine, factor_id_2).fform === :f2

    add_edge!(graph, variable_id_1, factor_id_1, Connection(:out))
    add_edge!(graph, variable_id_2, factor_id_2, Connection(:theta))

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

@testitem "InferenceEngine should prepare signals metadata by default" setup = [TestUtils] begin
    using .TestUtils

    graph = BipartiteFactorGraph()

    v1 = add_variable!(graph, Variable(:v1))
    v2 = add_variable!(graph, Variable(:v2))
    v3 = add_variable!(graph, Variable(:v3))

    f1 = add_factor!(graph, Factor(:f1))
    f2 = add_factor!(graph, Factor(:f2))

    add_edge!(graph, v1, f1, Connection(:out))
    add_edge!(graph, v2, f2, Connection(:out))
    add_edge!(graph, v3, f1, Connection(:in))
    add_edge!(graph, v3, f2, Connection(:in))

    engine = Cortex.InferenceEngine(model_backend = graph)

    @test Cortex.get_message_to_variable(engine, v1, f1).type == Cortex.InferenceSignalTypes.MessageToVariable
    @test Cortex.get_message_to_variable(engine, v2, f2).type == Cortex.InferenceSignalTypes.MessageToVariable
    @test Cortex.get_message_to_variable(engine, v3, f1).type == Cortex.InferenceSignalTypes.MessageToVariable
    @test Cortex.get_message_to_variable(engine, v3, f2).type == Cortex.InferenceSignalTypes.MessageToVariable

    @test Cortex.get_message_to_factor(engine, v1, f1).type == Cortex.InferenceSignalTypes.MessageToFactor
    @test Cortex.get_message_to_factor(engine, v2, f2).type == Cortex.InferenceSignalTypes.MessageToFactor
    @test Cortex.get_message_to_factor(engine, v3, f1).type == Cortex.InferenceSignalTypes.MessageToFactor
    @test Cortex.get_message_to_factor(engine, v3, f2).type == Cortex.InferenceSignalTypes.MessageToFactor

    @test Cortex.get_marginal(engine, v1).type == Cortex.InferenceSignalTypes.IndividualMarginal
    @test Cortex.get_marginal(engine, v2).type == Cortex.InferenceSignalTypes.IndividualMarginal
    @test Cortex.get_marginal(engine, v3).type == Cortex.InferenceSignalTypes.IndividualMarginal
end

@testitem "An empty inference round should be created for an empty model that has no pending messages" setup = [
    TestUtils
] begin
    using .TestUtils
    using JET

    @testset let graph = BipartiteFactorGraph()
        f1 = add_factor!(graph, Factor(:left))
        f2 = add_factor!(graph, Factor(:right))
        vc = add_variable!(graph, Variable(:center))

        add_edge!(graph, vc, f1, Connection(:param))
        add_edge!(graph, vc, f2, Connection(:param))

        inference_engine = Cortex.InferenceEngine(model_backend = graph)

        inference_request = Cortex.request_inference_for(inference_engine, vc)
        inference_steps = Cortex.scan_inference_request(inference_request)

        @test length(inference_steps) == 0
    end
end

@testitem "A non-empty inference round should be created for a model that has pending messages" setup = [TestUtils] begin
    using .TestUtils
    using JET

    function make_small_node_variable_node_model()
        graph = BipartiteFactorGraph()

        f1 = add_factor!(graph, Factor(:left))
        f2 = add_factor!(graph, Factor(:right))
        vc = add_variable!(graph, Variable(:center))

        add_edge!(graph, vc, f1, Connection(:param))
        add_edge!(graph, vc, f2, Connection(:param))

        # We disable dependency resolution because we will add dependencies manually
        inference_engine = Cortex.InferenceEngine(model_backend = graph, resolve_dependencies = false)

        vm = Cortex.get_marginal(inference_engine, vc)

        left = Cortex.Signal()
        right = Cortex.Signal()

        Cortex.add_dependency!(Cortex.get_message_to_variable(inference_engine, vc, f1), left)
        Cortex.add_dependency!(Cortex.get_message_to_variable(inference_engine, vc, f2), right)

        Cortex.add_dependency!(vm, Cortex.get_message_to_variable(inference_engine, vc, f1))
        Cortex.add_dependency!(vm, Cortex.get_message_to_variable(inference_engine, vc, f2))

        return inference_engine, f1, f2, vc, left, right
    end

    # f1 -> vc is pending, should be in the inference round
    @testset let (inference_engine, f1, f2, vc, left, right) = make_small_node_variable_node_model()
        Cortex.set_value!(left, 1.0)

        inference_request = Cortex.request_inference_for(inference_engine, vc)
        inference_steps = Cortex.scan_inference_request(inference_request)

        @test length(inference_steps) == 1
        @test inference_steps[1] == Cortex.get_message_to_variable(inference_engine, vc, f1)
    end

    # f2 -> vc is pending, should be in the inference round
    @testset let (inference_engine, f1, f2, vc, left, right) = make_small_node_variable_node_model()
        Cortex.set_value!(right, 1.0)

        inference_request = Cortex.request_inference_for(inference_engine, vc)
        inference_steps = Cortex.scan_inference_request(inference_request)

        @test length(inference_steps) == 1
        @test inference_steps[1] == Cortex.get_message_to_variable(inference_engine, vc, f2)
    end

    # f1 -> vc and f2 -> vc are pending, should be in the inference round
    @testset let (inference_engine, f1, f2, vc, left, right) = make_small_node_variable_node_model()
        Cortex.set_value!(left, 1.0)
        Cortex.set_value!(right, 1.0)

        inference_request = Cortex.request_inference_for(inference_engine, vc)
        inference_steps = Cortex.scan_inference_request(inference_request)

        @test length(inference_steps) == 2
        @test inference_steps[1] == Cortex.get_message_to_variable(inference_engine, vc, f1)
        @test inference_steps[2] == Cortex.get_message_to_variable(inference_engine, vc, f2)
    end
end

@testitem "An inference round should correctly resolve dependencies of required messages" setup = [TestUtils] begin
    using .TestUtils
    using JET

    model = BipartiteFactorGraph()

    v1 = add_variable!(model, Variable(:v1))
    v2 = add_variable!(model, Variable(:v2))
    v3 = add_variable!(model, Variable(:v3))

    f1 = add_factor!(model, Factor(:f1))
    f2 = add_factor!(model, Factor(:f2))

    # |v1| - :out |f1| :in - |v2| - :out |f2| :in - |v3|
    add_edge!(model, v1, f1, Connection(:out))
    add_edge!(model, v2, f1, Connection(:in))
    add_edge!(model, v2, f2, Connection(:out))
    add_edge!(model, v3, f2, Connection(:in))

    # We disable dependency resolution because we will add dependencies manually
    inference_engine = Cortex.InferenceEngine(model_backend = model, resolve_dependencies = false)

    # A message from f1 to v2 depends on a message from v1 to f1
    Cortex.add_dependency!(
        Cortex.get_message_to_variable(inference_engine, v2, f1), Cortex.get_message_to_factor(inference_engine, v1, f1)
    )

    # A message from f2 to v2 depends on a message from v3 to f2
    Cortex.add_dependency!(
        Cortex.get_message_to_variable(inference_engine, v2, f2), Cortex.get_message_to_factor(inference_engine, v3, f2)
    )

    # A marginal for v2 depends on a message f1 to v2 and a message f2 to v2
    Cortex.add_dependency!(
        Cortex.get_marginal(inference_engine, v2), Cortex.get_message_to_variable(inference_engine, v2, f1)
    )

    Cortex.add_dependency!(
        Cortex.get_marginal(inference_engine, v2), Cortex.get_message_to_variable(inference_engine, v2, f2)
    )

    # We set pending messages from v1 to f1 and v3 to f2
    # Since they are direct dependencies of messages to v2, they should be added to the inference round
    Cortex.set_value!(Cortex.get_message_to_factor(inference_engine, v1, f1), 1.0)
    Cortex.set_value!(Cortex.get_message_to_factor(inference_engine, v3, f2), 1.0)

    inference_request = Cortex.request_inference_for(inference_engine, v2)
    inference_steps = Cortex.scan_inference_request(inference_request)

    @test length(inference_steps) == 2
    @test inference_steps[1] == Cortex.get_message_to_variable(inference_engine, v2, f1)
    @test inference_steps[2] == Cortex.get_message_to_variable(inference_engine, v2, f2)
end

@testitem "Inference in Beta-Bernoulli model" setup = [TestUtils] begin
    using .TestUtils
    using JET, BipartiteFactorGraphs, StableRNGs

    struct Beta
        a::Float64
        b::Float64
    end

    struct Bernoulli
        y::Bool
    end

    function computer(engine::Cortex.InferenceEngine, signal::Cortex.Signal, dependencies::Vector{Cortex.Signal})
        if signal.type == Cortex.InferenceSignalTypes.MessageToVariable
            _, factor_id = (signal.metadata::Tuple{Int, Int})

            factor = Cortex.get_factor_data(engine, factor_id)

            if factor.fform === :bernoulli
                r = Cortex.get_value(dependencies[1])::Bool
                return Beta(one(r) + r, 2one(r) - r)
            elseif factor.fform === :prior
                error("Should not be invoked")
            end
        elseif signal.type == Cortex.InferenceSignalTypes.IndividualMarginal ||
            signal.type == Cortex.InferenceSignalTypes.ProductOfMessages
            answer = Cortex.get_value(dependencies[1])::Beta
            for i in 2:length(dependencies)
                @inbounds next = Cortex.get_value(dependencies[i])::Beta
                answer = Beta(answer.a + next.a - 1, answer.b + next.b - 1)
            end
            return answer
        end

        error("Unreachable reached")
    end

    function make_beta_bernoulli_model(n)
        graph = BipartiteFactorGraph()

        p = add_variable!(graph, Variable(:p))
        o = []
        f = []

        for i in 1:n
            oi = add_variable!(graph, Variable(:o, i))
            fi = add_factor!(graph, Factor(:bernoulli))

            push!(o, oi)
            push!(f, fi)

            add_edge!(graph, p, fi, Connection(:out))
            add_edge!(graph, oi, fi, Connection(:out))
        end

        engine = Cortex.InferenceEngine(
            model_backend = graph,
            dependency_resolver = Cortex.DefaultDependencyResolver(),
            inference_request_processor = computer
        )

        return engine, p, o, f
    end

    function experiment(dataset)
        n = length(dataset)
        engine, p, o, f = make_beta_bernoulli_model(n)

        for i in 1:n
            Cortex.set_value!(Cortex.get_message_to_factor(engine, o[i], f[i]), dataset[i])
        end

        Cortex.update_marginals!(engine, p)

        return Cortex.get_value(Cortex.get_marginal(engine, p))
    end

    n = 100
    rng = StableRNG(1234)
    dataset = rand(rng, Bool, n)

    answer = experiment(dataset)

    # Known answer calculation for Beta-Bernoulli
    # Prior: Beta(1, 1)
    # Likelihood: Bernoulli(p)
    # Data: dataset (n trials)
    # Posterior: Beta(1 + sum(dataset), 1 + n - sum(dataset))
    num_successes = sum(dataset)
    num_failures = n - num_successes
    known_answer = Beta(1.0 + num_successes, 1.0 + num_failures)

    @test answer.a ≈ known_answer.a
    @test answer.b ≈ known_answer.b
end

@testitem "Inference in a simple SSM model - Belief Propagation" setup = [TestUtils] begin
    using .TestUtils
    using JET, BipartiteFactorGraphs, StableRNGs

    struct Normal
        mean::Float64
        variance::Float64
    end

    function computer(engine::Cortex.InferenceEngine, signal::Cortex.Signal, dependencies::Vector{Cortex.Signal})
        if signal.type == Cortex.InferenceSignalTypes.IndividualMarginal
            return reduce(product, Cortex.get_value.(dependencies))
        elseif signal.type == Cortex.InferenceSignalTypes.MessageToFactor
            return reduce(product, Cortex.get_value.(dependencies))
        elseif signal.type == Cortex.InferenceSignalTypes.MessageToVariable
            @assert length(dependencies) == 1
            input = Cortex.get_value(dependencies[1])

            if typeof(input) <: Real
                return Normal(input, 1.0)
            elseif typeof(input) <: Normal
                return Normal(input.mean, input.variance + 1.0)
            else
                error("Unreachable reached")
            end
        end

        error("Unreachable reached")
    end

    # In this model, we assume that both the likelihood and the transition are Normal
    # with fixed variance equal to 1.0.
    function make_ssm_model(n)
        graph = BipartiteFactorGraph()

        x = [add_variable!(graph, Variable(:x, i)) for i in 1:n]
        y = [add_variable!(graph, Variable(:y, i)) for i in 1:n]

        likelihood = [add_factor!(graph, Factor(:likelihood)) for i in 1:n]
        transition = [add_factor!(graph, Factor(:transition)) for i in 1:(n - 1)]

        for i in 1:n
            add_edge!(graph, y[i], likelihood[i], Connection(:out))
            add_edge!(graph, x[i], likelihood[i], Connection(:out))
        end

        for i in 1:(n - 1)
            add_edge!(graph, x[i], transition[i], Connection(:out))
            add_edge!(graph, x[i + 1], transition[i], Connection(:in))
        end

        engine = Cortex.InferenceEngine(
            model_backend = graph,
            dependency_resolver = Cortex.DefaultDependencyResolver(),
            inference_request_processor = computer
        )

        return engine, x, y, likelihood, transition
    end

    function product(left::Normal, right::Normal)
        xi = left.mean / left.variance + right.mean / right.variance
        w = 1 / left.variance + 1 / right.variance
        variance = 1 / w
        mean = variance * xi
        return Normal(mean, variance)
    end

    function experiment(dataset)
        n = length(dataset)
        engine, x, y, likelihood, transition = make_ssm_model(n)

        for i in 1:n
            Cortex.set_value!(Cortex.get_message_to_factor(engine, y[i], likelihood[i]), dataset[i])
        end

        Cortex.update_marginals!(engine, x)

        return Cortex.get_value.(Cortex.get_marginal.(engine, x))
    end

    rng = StableRNG(1234)
    dataset = rand(rng, 100)

    answer = experiment(dataset)
end

@testitem "Inference in a simple SSM model - Mean Field" setup = [TestUtils] begin
    using .TestUtils
    using JET, BipartiteFactorGraphs, StableRNGs, Random

    struct Normal
        mean::Float64
        precision::Float64
    end

    Random.rand(rng::AbstractRNG, n::Normal) = n.mean + randn(rng) / sqrt(n.precision)

    struct Gamma
        shape::Float64
        scale::Float64
    end

    mean(g::Gamma) = g.shape * g.scale

    mean(n::Normal) = n.mean
    var(n::Normal) = 1 / n.precision

    struct MeanFieldResolver <: Cortex.AbstractDependencyResolver end

    function Cortex.resolve_variable_dependencies!(::MeanFieldResolver, engine::Cortex.InferenceEngine, variable_id)
        marginal = Cortex.get_marginal(engine, variable_id)
        for factor_id in Cortex.get_connected_factor_ids(engine, variable_id)
            Cortex.add_dependency!(
                marginal, Cortex.get_message_to_variable(engine, variable_id, factor_id); intermediate = true
            )
        end
        return nothing
    end

    function Cortex.resolve_factor_dependencies!(::MeanFieldResolver, engine::Cortex.InferenceEngine, factor_id)
        variable_ids_connected_to_factor = Cortex.get_connected_variable_ids(engine, factor_id)

        for variable_id1 in variable_ids_connected_to_factor, variable_id2 in variable_ids_connected_to_factor
            if variable_id1 !== variable_id2
                Cortex.add_dependency!(
                    Cortex.get_message_to_variable(engine, variable_id1, factor_id),
                    Cortex.get_marginal(engine, variable_id2);
                    weak = true
                )
            end
        end
    end

    function product(left::Normal, right::Normal)
        xi = left.mean * left.precision + right.mean * right.precision
        w = left.precision + right.precision
        precision = w
        mean = (1 / precision) * xi
        return Normal(mean, precision)
    end

    function product(left::Gamma, right::Gamma)
        return Gamma(left.shape + right.shape - 1, (left.scale * right.scale) / (left.scale + right.scale))
    end

    function get_name_of_variable(engine::Cortex.InferenceEngine, variable_id)
        return Cortex.get_variable_data(engine, variable_id).name
    end

    function computer(engine::Cortex.InferenceEngine, signal::Cortex.Signal, dependencies::Vector{Cortex.Signal})
        if signal.type == Cortex.InferenceSignalTypes.IndividualMarginal
            return reduce(product, Cortex.get_value.(dependencies))
        elseif signal.type == Cortex.InferenceSignalTypes.MessageToFactor
            return reduce(product, Cortex.get_value.(dependencies))
        elseif signal.type == Cortex.InferenceSignalTypes.MessageToVariable
            @assert length(dependencies) == 2

            x = findfirst(d -> get_name_of_variable(engine, first(d.metadata)) == :x, dependencies)
            y = findfirst(d -> get_name_of_variable(engine, first(d.metadata)) == :y, dependencies)
            ssnoise = findfirst(d -> get_name_of_variable(engine, first(d.metadata)) == :ssnoise, dependencies)
            obsnoise = findfirst(d -> get_name_of_variable(engine, first(d.metadata)) == :obsnoise, dependencies)

            if !isnothing(x) && !isnothing(ssnoise)
                return Normal(mean(Cortex.get_value(dependencies[x])), mean(Cortex.get_value(dependencies[ssnoise])))
            end

            if !isnothing(y) && !isnothing(obsnoise)
                return Normal(Cortex.get_value(dependencies[y]), mean(Cortex.get_value(dependencies[obsnoise])))
            end

            if !isnothing(y) && !isnothing(x)
                q_out = Cortex.get_value(dependencies[y])
                q_μ = Cortex.get_value(dependencies[x])
                θ = 2 / (var(q_μ) + abs2(q_out - mean(q_μ)))
                α = convert(typeof(θ), 1.5)
                return Gamma(α, θ)
            end

            if filter(d -> get_name_of_variable(engine, first(d.metadata)) == :x, dependencies) |> length == 2
                q_out = Cortex.get_value(dependencies[1])
                q_μ = Cortex.get_value(dependencies[2])
                θ = 2 / (var(q_out) + var(q_μ) + abs2(mean(q_out) - mean(q_μ)))
                α = convert(typeof(θ), 1.5)
                return Gamma(α, θ)
            end

            error("Unreachable reached")
        end

        error("Unreachable reached")
    end

    function make_ssm_model(n)
        graph = BipartiteFactorGraph()

        ssnoise = add_variable!(graph, Variable(:ssnoise))
        obsnoise = add_variable!(graph, Variable(:obsnoise))

        x = [add_variable!(graph, Variable(:x, i)) for i in 1:n]
        y = [add_variable!(graph, Variable(:y, i)) for i in 1:n]

        likelihood = [add_factor!(graph, Factor(:likelihood)) for i in 1:n]
        transition = [add_factor!(graph, Factor(:transition)) for i in 1:(n - 1)]

        for i in 1:n
            add_edge!(graph, y[i], likelihood[i], Connection(:out))
            add_edge!(graph, x[i], likelihood[i], Connection(:out))
            add_edge!(graph, obsnoise, likelihood[i], Connection(:out))
        end

        for i in 1:(n - 1)
            add_edge!(graph, x[i], transition[i], Connection(:out))
            add_edge!(graph, x[i + 1], transition[i], Connection(:in))
            add_edge!(graph, ssnoise, transition[i], Connection(:out))
        end

        engine = Cortex.InferenceEngine(
            model_backend = graph, dependency_resolver = MeanFieldResolver(), inference_request_processor = computer
        )

        # Initial marginals
        Cortex.set_value!(Cortex.get_marginal(engine, ssnoise), Gamma(1.0, 1.0))
        Cortex.set_value!(Cortex.get_marginal(engine, obsnoise), Gamma(1.0, 1.0))

        for i in 1:n
            Cortex.set_value!(Cortex.get_marginal(engine, x[i]), Normal(0.0, 1.0))
        end

        return engine, x, y, obsnoise, ssnoise, likelihood, transition
    end

    function experiment(dataset, vmp_iterations)
        n = length(dataset)
        engine, x, y, obsnoise, ssnoise, likelihood, transition = make_ssm_model(n)

        for i in 1:n
            Cortex.set_value!(Cortex.get_marginal(engine, y[i]), dataset[i])
        end

        for iteration in 1:vmp_iterations
            # Check that the marginals can be updated in any order
            if div(iteration, 2) == 0
                Cortex.update_marginals!(engine, x)
                Cortex.update_marginals!(engine, ssnoise)
                Cortex.update_marginals!(engine, obsnoise)
            else
                Cortex.update_marginals!(engine, obsnoise)
                Cortex.update_marginals!(engine, ssnoise)
                Cortex.update_marginals!(engine, x)
            end

            # Check that the marginals can be updated several times
            Cortex.update_marginals!(engine, obsnoise)
            Cortex.update_marginals!(engine, obsnoise)
            Cortex.update_marginals!(engine, obsnoise)

            # Check that the updates can be merged into a single update
            Cortex.update_marginals!(engine, [ssnoise, obsnoise])
        end

        return (
            x = Cortex.get_value.(Cortex.get_marginal.(engine, x)),
            ssnoise = Cortex.get_value(Cortex.get_marginal(engine, ssnoise)),
            obsnoise = Cortex.get_value(Cortex.get_marginal(engine, obsnoise))
        )
    end

    rng = StableRNG(1234)

    n = 100
    ssnoise_real = 100.0
    obsnoise_real = 100.0
    random_walk = [0.0]
    for i in 2:n
        push!(random_walk, rand(rng, Normal(random_walk[i - 1], ssnoise_real)))
    end

    observations = []
    for i in 1:n
        push!(observations, rand(rng, Normal(random_walk[i], obsnoise_real)))
    end

    vmp_iterations = 100
    answer = experiment(observations, vmp_iterations)

    # The actual answer isn't precise because of the mean-field assumption
    # as well as the fact that the convergence of the VMP updates 
    # depends on the initial conditions and order of updates
    @test mean(answer.obsnoise) > 50.0
    @test mean(answer.ssnoise) > 50.0
end

@testitem "Inference in a simple SSM model - Structured" setup = [TestUtils] begin
    using .TestUtils
    using JET, BipartiteFactorGraphs, StableRNGs, Random

    struct Normal
        mean::Float64
        precision::Float64
    end

    Random.rand(rng::AbstractRNG, n::Normal) = n.mean + randn(rng) / sqrt(n.precision)

    mean(n::Normal) = n.mean
    var(n::Normal) = 1 / n.precision
    precision(n::Normal) = n.precision

    struct Gamma
        shape::Float64
        scale::Float64
    end

    mean(g::Gamma) = g.shape * g.scale

    struct MvNormal
        mean::Vector{Float64}
        precision::Matrix{Float64}
    end

    mean(n::MvNormal) = n.mean
    cov(n::MvNormal) = inv(n.precision)
    precision(n::MvNormal) = n.precision

    struct StructuredResolver <: Cortex.AbstractDependencyResolver
        joint_dependencies::Dict{Any, Vector{Cortex.Signal}}

        function StructuredResolver()
            return new(Dict{Any, Vector{Cortex.Signal}}())
        end
    end

    function Cortex.get_joint_dependencies(resolver::StructuredResolver, engine::Cortex.InferenceEngine, variable_id)
        return get(resolver.joint_dependencies, variable_id, [])
    end

    function Cortex.resolve_variable_dependencies!(::StructuredResolver, engine::Cortex.InferenceEngine, variable_id)
        return Cortex.resolve_variable_dependencies!(Cortex.DefaultDependencyResolver(), engine, variable_id)
    end

    function Cortex.resolve_factor_dependencies!(
        resolver::StructuredResolver, engine::Cortex.InferenceEngine, factor_id
    )
        factor_data = Cortex.get_factor_data(engine, factor_id)

        # For likelihood we do mean-field like updates
        if factor_data.fform === :likelihood
            variable_ids_connected_to_factor = Cortex.get_connected_variable_ids(engine, factor_id)
            for variable_id1 in variable_ids_connected_to_factor, variable_id2 in variable_ids_connected_to_factor
                if variable_id1 !== variable_id2
                    Cortex.add_dependency!(
                        Cortex.get_message_to_variable(engine, variable_id1, factor_id),
                        Cortex.get_marginal(engine, variable_id2);
                        weak = true
                    )
                end
            end
        else
            # For transition we do structured updates
            variable_ids_connected_to_factor = Cortex.get_connected_variable_ids(engine, factor_id)

            # We cluster the variables into their respective clusters
            # For this example we simply use the name of the variable, thus x_1 and x_2 are in the same cluster
            clusters = Dict{Symbol, Vector{Int}}()

            for variable_id in variable_ids_connected_to_factor
                name = Cortex.get_variable_data(engine, variable_id).name
                if haskey(clusters, name)
                    push!(clusters[name], variable_id)
                else
                    clusters[name] = [variable_id]
                end
            end

            deps = map(values(clusters)) do cluster
                if length(cluster) == 1
                    return Cortex.get_marginal(engine, first(cluster))
                else
                    new_joint_marginal = Cortex.Signal(
                        type = Cortex.InferenceSignalTypes.JointMarginal, metadata = (factor_id, cluster)
                    )
                    for v_id in cluster
                        if haskey(resolver.joint_dependencies, v_id)
                            push!(resolver.joint_dependencies[v_id], new_joint_marginal)
                        else
                            resolver.joint_dependencies[v_id] = [new_joint_marginal]
                        end

                        # Should be always weak here?
                        Cortex.add_dependency!(
                            new_joint_marginal, Cortex.get_message_to_factor(engine, v_id, factor_id); weak = true
                        )
                    end
                    return new_joint_marginal
                end
            end

            for d1 in deps, d2 in deps
                if d1.type === Cortex.InferenceSignalTypes.JointMarginal && d1 !== d2
                    Cortex.add_dependency!(d1, d2; weak = true)
                end
            end

            for (index, cluster) in enumerate(values(clusters))
                for m1 in cluster, m2 in cluster
                    if m1 !== m2
                        Cortex.add_dependency!(
                            Cortex.get_message_to_variable(engine, m1, factor_id),
                            Cortex.get_message_to_factor(engine, m2, factor_id);
                        )
                    end
                end

                for m1 in cluster
                    for (another_index, another_cluster_joint_marginal) in enumerate(deps)
                        if index !== another_index
                            Cortex.add_dependency!(
                                Cortex.get_message_to_variable(engine, m1, factor_id),
                                another_cluster_joint_marginal;
                                weak = true
                            )
                        end
                    end
                end
            end
        end
    end

    function product(left::Normal, right::Normal)
        xi = left.mean * left.precision + right.mean * right.precision
        w = left.precision + right.precision
        precision = w
        mean = (1 / precision) * xi
        return Normal(mean, precision)
    end

    function product(left::Gamma, right::Gamma)
        return Gamma(left.shape + right.shape - 1, (left.scale * right.scale) / (left.scale + right.scale))
    end

    function get_name_of_variable(engine::Cortex.InferenceEngine, variable_id)
        return Cortex.get_variable_data(engine, variable_id).name
    end

    function computer(engine::Cortex.InferenceEngine, signal::Cortex.Signal, dependencies::Vector{Cortex.Signal})
        if signal.type == Cortex.InferenceSignalTypes.IndividualMarginal
            return reduce(product, Cortex.get_value.(dependencies))
        elseif signal.type == Cortex.InferenceSignalTypes.MessageToFactor
            return reduce(product, Cortex.get_value.(dependencies))
        elseif signal.type == Cortex.InferenceSignalTypes.ProductOfMessages
            return reduce(product, Cortex.get_value.(dependencies))
        elseif signal.type == Cortex.InferenceSignalTypes.JointMarginal
            msg1 = dependencies[1]
            msg2 = dependencies[2]
            mrg  = dependencies[3]

            @assert msg1.type == Cortex.InferenceSignalTypes.MessageToFactor
            @assert msg2.type == Cortex.InferenceSignalTypes.MessageToFactor
            @assert mrg.type == Cortex.InferenceSignalTypes.IndividualMarginal

            msg1_value = Cortex.get_value(msg1)
            msg2_value = Cortex.get_value(msg2)
            mrg_value = Cortex.get_value(mrg)

            xi_out, W_out = (precision(msg1_value) * mean(msg1_value), precision(msg1_value))
            xi_μ, W_μ = (precision(msg2_value) * mean(msg2_value), precision(msg2_value))

            W_bar = mean(mrg_value)

            W = [W_out+W_bar -W_bar; -W_bar W_μ+W_bar]
            μ = inv(W) * [xi_out; xi_μ]

            return MvNormal(μ, W)

        elseif signal.type == Cortex.InferenceSignalTypes.MessageToVariable
            v, f = (signal.metadata::Tuple{Int, Int})

            factor = Cortex.get_factor_data(engine, f)

            if factor.fform === :likelihood
                y = findfirst(d -> get_name_of_variable(engine, first(d.metadata)) == :y, dependencies)
                x = findfirst(d -> get_name_of_variable(engine, first(d.metadata)) == :x, dependencies)
                obsnoise = findfirst(d -> get_name_of_variable(engine, first(d.metadata)) == :obsnoise, dependencies)

                if !isnothing(y) && !isnothing(obsnoise)
                    return Normal(Cortex.get_value(dependencies[y]), mean(Cortex.get_value(dependencies[obsnoise])))
                end

                if !isnothing(x) && !isnothing(y)
                    q_out = Cortex.get_value(dependencies[y])
                    q_μ = Cortex.get_value(dependencies[x])
                    θ = 2 / (var(q_μ) + abs2(q_out - mean(q_μ)))
                    α = convert(typeof(θ), 1.5)
                    return Gamma(α, θ)
                end

                error("unreachable reached in likelihood")
            elseif factor.fform === :transition
                msg = findfirst(d -> d.type == Cortex.InferenceSignalTypes.MessageToFactor, dependencies)
                mrg = findfirst(d -> d.type == Cortex.InferenceSignalTypes.IndividualMarginal, dependencies)
                jmrg = findfirst(d -> d.type == Cortex.InferenceSignalTypes.JointMarginal, dependencies)

                if !isnothing(msg) && !isnothing(mrg)
                    v_msg = Cortex.get_value(dependencies[msg])
                    v_mrg = Cortex.get_value(dependencies[mrg])

                    m_μ_mean = mean(v_msg)
                    m_μ_var = var(v_msg)

                    return Normal(m_μ_mean, inv(m_μ_var + inv(mean(v_mrg))))
                elseif !isnothing(jmrg)
                    v_jmrg = Cortex.get_value(dependencies[jmrg])
                    m, V = (mean(v_jmrg), cov(v_jmrg))
                    θ = 2 / (V[1, 1] - V[1, 2] - V[2, 1] + V[2, 2] + abs2(m[1] - m[2]))
                    α = convert(typeof(θ), 1.5)
                    return Gamma(α, θ)
                end

                error("unreachable reached")
            else
                error("unreachable reached")
            end
        end

        error("Unreachable reached")
    end

    function make_ssm_model(n)
        graph = BipartiteFactorGraph()

        ssnoise = add_variable!(graph, Variable(:ssnoise))
        obsnoise = add_variable!(graph, Variable(:obsnoise))

        x = [add_variable!(graph, Variable(:x, i)) for i in 1:n]
        y = [add_variable!(graph, Variable(:y, i)) for i in 1:n]

        likelihood = [add_factor!(graph, Factor(:likelihood)) for i in 1:n]
        transition = [add_factor!(graph, Factor(:transition)) for i in 1:(n - 1)]

        for i in 1:n
            add_edge!(graph, y[i], likelihood[i], Connection(:out))
            add_edge!(graph, x[i], likelihood[i], Connection(:out))
            add_edge!(graph, obsnoise, likelihood[i], Connection(:out))
        end

        for i in 1:(n - 1)
            add_edge!(graph, x[i], transition[i], Connection(:out))
            add_edge!(graph, x[i + 1], transition[i], Connection(:in))
            add_edge!(graph, ssnoise, transition[i], Connection(:out))
        end

        engine = Cortex.InferenceEngine(
            model_backend = graph,
            dependency_resolver = StructuredResolver(),
            inference_request_processor = computer,
            trace = true
        )

        # Initial marginals
        Cortex.set_value!(Cortex.get_marginal(engine, ssnoise), Gamma(1.0, 1.0))
        Cortex.set_value!(Cortex.get_marginal(engine, obsnoise), Gamma(1.0, 1.0))

        for i in 1:n
            Cortex.set_value!(Cortex.get_marginal(engine, x[i]), Normal(0.0, 1.0))
        end

        return engine, x, y, obsnoise, ssnoise, likelihood, transition
    end

    function experiment(dataset, vmp_iterations)
        n = length(dataset)
        engine, x, y, obsnoise, ssnoise, likelihood, transition = make_ssm_model(n)

        for i in 1:n
            Cortex.set_value!(Cortex.get_marginal(engine, y[i]), dataset[i])
        end

        for iteration in 1:vmp_iterations
            Cortex.update_marginals!(engine, x)
            Cortex.update_marginals!(engine, ssnoise)
            Cortex.update_marginals!(engine, obsnoise)
        end

        return (
            engine = engine,
            x = Cortex.get_value.(Cortex.get_marginal.(engine, x)),
            ssnoise = Cortex.get_value(Cortex.get_marginal(engine, ssnoise)),
            obsnoise = Cortex.get_value(Cortex.get_marginal(engine, obsnoise))
        )
    end

    rng = StableRNG(1234)

    n = 100
    ssnoise_real = 100.0
    obsnoise_real = 100.0
    random_walk = [0.0]
    for i in 2:n
        push!(random_walk, rand(rng, Normal(random_walk[i - 1], ssnoise_real)))
    end

    observations = []
    for i in 1:n
        push!(observations, rand(rng, Normal(random_walk[i], obsnoise_real)))
    end

    vmp_iterations = 100
    answer = experiment(observations, vmp_iterations)

    # The actual answer isn't precise because of the mean-field assumption
    # as well as the fact that the convergence of the VMP updates 
    # depends on the initial conditions and order of updates
    @test mean(answer.obsnoise) > 90
    @test mean(answer.ssnoise) > 90

    answer.engine
end

@testitem "Tracing inference in a simple IID model" setup = [TestUtils] begin
    using .TestUtils
    using JET, BipartiteFactorGraphs

    function computer(engine::Cortex.InferenceEngine, signal::Cortex.Signal, dependencies::Vector{Cortex.Signal})
        if signal.type == Cortex.InferenceSignalTypes.MessageToVariable
            _, factor_id = (signal.metadata::Tuple{Int, Int})

            factor = Cortex.get_factor_data(engine, factor_id)

            if factor.fform === :likelihood1
                return 2 * Cortex.get_value(dependencies[1])
            elseif factor.fform === :likelihood2
                return 2 * Cortex.get_value(dependencies[1])
            elseif factor.fform === :prior
                error("Should not be invoked")
            end
        elseif signal.type == Cortex.InferenceSignalTypes.IndividualMarginal
            return sum(Cortex.get_value.(dependencies))
        end

        error("Unreachable reached")
    end

    graph = BipartiteFactorGraph()

    # The "center" of the model
    p = add_variable!(graph, Variable(:p))

    # The observed outcomes
    o1 = add_variable!(graph, Variable(:y1))
    o2 = add_variable!(graph, Variable(:y2))

    # Priors
    fp = add_factor!(graph, Factor(:prior))

    # Likelihoods
    f1 = add_factor!(graph, Factor(:likelihood1))
    f2 = add_factor!(graph, Factor(:likelihood2))

    # Connections between the parameter `p` and the factors
    add_edge!(graph, p, fp, Connection(:out))
    add_edge!(graph, p, f1, Connection(:in))
    add_edge!(graph, p, f2, Connection(:in))

    # Connections between the observed outcomes and the likelihoods
    add_edge!(graph, o1, f1, Connection(:out))
    add_edge!(graph, o2, f2, Connection(:out))

    inference_engine = Cortex.InferenceEngine(
        model_backend = graph,
        dependency_resolver = Cortex.DefaultDependencyResolver(),
        inference_request_processor = computer,
        trace = true
    )

    # Set data
    o1_value = 1
    o2_value = 2

    Cortex.set_value!(Cortex.get_message_to_factor(inference_engine, o1, f1), o1_value)
    Cortex.set_value!(Cortex.get_message_to_factor(inference_engine, o2, f2), o2_value)

    # Set prior
    Cortex.set_value!(Cortex.get_message_to_variable(inference_engine, p, fp), 3)

    Cortex.update_marginals!(inference_engine, p)

    @test Cortex.get_value(Cortex.get_marginal(inference_engine, p)) == 9

    trace = Cortex.get_trace(inference_engine)

    @test length(trace.inference_requests) == 1

    traced_update_request = trace.inference_requests[1]

    @test traced_update_request.request.variable_ids == (p,)
    @test traced_update_request.total_time_in_ns > 0
    @test length(traced_update_request.rounds) == 2

    @test length(traced_update_request.rounds[1].executions) == 2
    @test traced_update_request.rounds[1].total_time_in_ns > 0
    @test traced_update_request.rounds[1].executions[1].variable_id == p
    @test traced_update_request.rounds[1].executions[1].signal.type == Cortex.InferenceSignalTypes.MessageToVariable
    @test traced_update_request.rounds[1].executions[1].signal.metadata == (p, f1)
    @test traced_update_request.rounds[1].executions[1].total_time_in_ns > 0
    @test traced_update_request.rounds[1].executions[1].value_before_execution == Cortex.UndefValue()
    @test traced_update_request.rounds[1].executions[1].value_after_execution == 2 * o1_value

    @test traced_update_request.rounds[1].executions[2].variable_id == p
    @test traced_update_request.rounds[1].executions[2].signal.type == Cortex.InferenceSignalTypes.MessageToVariable
    @test traced_update_request.rounds[1].executions[2].signal.metadata == (p, f2)
    @test traced_update_request.rounds[1].executions[2].total_time_in_ns > 0
    @test traced_update_request.rounds[1].executions[2].value_before_execution == Cortex.UndefValue()
    @test traced_update_request.rounds[1].executions[2].value_after_execution == 2 * o2_value

    @test length(traced_update_request.rounds[2].executions) == 1
    @test traced_update_request.rounds[2].total_time_in_ns > 0
    @test traced_update_request.rounds[2].executions[1].variable_id == p
    @test traced_update_request.rounds[2].executions[1].signal.type == Cortex.InferenceSignalTypes.IndividualMarginal
    @test traced_update_request.rounds[2].executions[1].signal.metadata == (p,)
    @test traced_update_request.rounds[2].executions[1].total_time_in_ns > 0
    @test traced_update_request.rounds[2].executions[1].value_before_execution == Cortex.UndefValue()
    @test traced_update_request.rounds[2].executions[1].value_after_execution == 9

    io = IOBuffer()
    show(io, trace)

    trace_string_representation = String(take!(io))

    @test !isempty(trace_string_representation)

    @test occursin("MessageToVariable(from = likelihood1, to = p)", trace_string_representation)
    @test occursin("MessageToVariable(from = likelihood2, to = p)", trace_string_representation)

    @test occursin("IndividualMarginal(p)", trace_string_representation)
end