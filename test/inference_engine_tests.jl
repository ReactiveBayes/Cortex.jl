@testitem "InferenceEngine specific signals should be pretty-printed with their type" setup = [TestUtils] begin
    @test Cortex.InferenceSignalTypes.to_string(UInt8(0x00)) == ""
    @test Cortex.InferenceSignalTypes.to_string(Cortex.InferenceSignalTypes.MessageToVariable) == "MessageToVariable"
    @test Cortex.InferenceSignalTypes.to_string(Cortex.InferenceSignalTypes.MessageToFactor) == "MessageToFactor"
    @test Cortex.InferenceSignalTypes.to_string(Cortex.InferenceSignalTypes.ProductOfMessages) == "ProductOfMessages"
    @test Cortex.InferenceSignalTypes.to_string(Cortex.InferenceSignalTypes.IndividualMarginal) == "IndividualMarginal"
    @test Cortex.InferenceSignalTypes.to_string(Cortex.InferenceSignalTypes.JointMarginal) == "JointMarginal"

    @test Cortex.InferenceSignalTypes.to_string(UInt8(0x11)) == "UnknownType(0x11)"
end

@testitem "InferenceEngine should save a warning for a variable that has no connected factors" setup = [TestUtils] begin
    using .TestUtils
    using JET

    graph = BipartiteFactorGraph(Variable, Factor, Connection)

    v = add_variable!(graph, Variable(name = :v))

    engine = Cortex.InferenceEngine(model_engine = graph)

    @test length(Cortex.get_warnings(engine)) == 1
    @test Cortex.get_warnings(engine)[1].description == "Variable has no connected factors"
    @test Cortex.get_warnings(engine)[1].context == v
end

@testitem "InferenceEngine should prepare signals metadata by default" setup = [TestUtils] begin
    using .TestUtils

    graph = BipartiteFactorGraph(Variable, Factor, Connection)

    v1 = add_variable!(graph, Variable(name = :v1))
    v2 = add_variable!(graph, Variable(name = :v2))
    v3 = add_variable!(graph, Variable(name = :v3))

    f1 = add_factor!(graph, Factor(functional_form = :f1))
    f2 = add_factor!(graph, Factor(functional_form = :f2))

    add_edge!(graph, v1, f1, Connection(label = :out))
    add_edge!(graph, v2, f2, Connection(label = :out))
    add_edge!(graph, v3, f1, Connection(label = :in))
    add_edge!(graph, v3, f2, Connection(label = :in))

    engine = Cortex.InferenceEngine(model_engine = graph)

    @test Cortex.get_connection_message_to_variable(engine, v1, f1).type ==
        Cortex.InferenceSignalTypes.MessageToVariable
    @test Cortex.get_connection_message_to_variable(engine, v2, f2).type ==
        Cortex.InferenceSignalTypes.MessageToVariable
    @test Cortex.get_connection_message_to_variable(engine, v3, f1).type ==
        Cortex.InferenceSignalTypes.MessageToVariable
    @test Cortex.get_connection_message_to_variable(engine, v3, f2).type ==
        Cortex.InferenceSignalTypes.MessageToVariable

    @test Cortex.get_connection_message_to_factor(engine, v1, f1).type == Cortex.InferenceSignalTypes.MessageToFactor
    @test Cortex.get_connection_message_to_factor(engine, v2, f2).type == Cortex.InferenceSignalTypes.MessageToFactor
    @test Cortex.get_connection_message_to_factor(engine, v3, f1).type == Cortex.InferenceSignalTypes.MessageToFactor
    @test Cortex.get_connection_message_to_factor(engine, v3, f2).type == Cortex.InferenceSignalTypes.MessageToFactor

    @test Cortex.get_variable_marginal(Cortex.get_variable(engine, v1)).type ==
        Cortex.InferenceSignalTypes.IndividualMarginal
    @test Cortex.get_variable_marginal(Cortex.get_variable(engine, v2)).type ==
        Cortex.InferenceSignalTypes.IndividualMarginal
    @test Cortex.get_variable_marginal(Cortex.get_variable(engine, v3)).type ==
        Cortex.InferenceSignalTypes.IndividualMarginal
end

@testitem "An empty inference round should be created for an empty model that has no pending messages" setup = [
    TestUtils
] begin
    using .TestUtils
    using JET

    @testset let graph = BipartiteFactorGraph(Variable, Factor, Connection)
        f1 = add_factor!(graph, Factor(functional_form = :left))
        f2 = add_factor!(graph, Factor(functional_form = :right))
        vc = add_variable!(graph, Variable(name = :center))

        add_edge!(graph, vc, f1, Connection(label = :param))
        add_edge!(graph, vc, f2, Connection(label = :param))

        inference_engine = Cortex.InferenceEngine(model_engine = graph)

        inference_request = Cortex.request_inference_for(inference_engine, vc)
        inference_steps = Cortex.scan_inference_request(inference_request)

        @test length(inference_steps) == 0
    end
end

@testitem "A non-empty inference round should be created for a model that has pending messages" setup = [TestUtils] begin
    using .TestUtils
    using JET

    function make_small_node_variable_node_model()
        graph = BipartiteFactorGraph(Variable, Factor, Connection)

        f1 = add_factor!(graph, Factor(functional_form = :left))
        f2 = add_factor!(graph, Factor(functional_form = :right))
        vc = add_variable!(graph, Variable(name = :center))

        add_edge!(graph, vc, f1, Connection(label = :param))
        add_edge!(graph, vc, f2, Connection(label = :param))

        # We disable dependency resolution because we will add dependencies manually
        inference_engine = Cortex.InferenceEngine(model_engine = graph, resolve_dependencies = false)

        vm = Cortex.get_variable_marginal(Cortex.get_variable(inference_engine, vc))

        left = Cortex.Signal()
        right = Cortex.Signal()

        Cortex.add_dependency!(Cortex.get_connection_message_to_variable(inference_engine, vc, f1), left)
        Cortex.add_dependency!(Cortex.get_connection_message_to_variable(inference_engine, vc, f2), right)

        Cortex.add_dependency!(vm, Cortex.get_connection_message_to_variable(inference_engine, vc, f1))
        Cortex.add_dependency!(vm, Cortex.get_connection_message_to_variable(inference_engine, vc, f2))

        return inference_engine, f1, f2, vc, left, right
    end

    # f1 -> vc is pending, should be in the inference round
    @testset let (inference_engine, f1, f2, vc, left, right) = make_small_node_variable_node_model()
        Cortex.set_value!(left, 1.0)

        inference_request = Cortex.request_inference_for(inference_engine, vc)
        inference_steps = Cortex.scan_inference_request(inference_request)

        @test length(inference_steps) == 1
        @test inference_steps[1] == Cortex.get_connection_message_to_variable(inference_engine, vc, f1)
    end

    # f2 -> vc is pending, should be in the inference round
    @testset let (inference_engine, f1, f2, vc, left, right) = make_small_node_variable_node_model()
        Cortex.set_value!(right, 1.0)

        inference_request = Cortex.request_inference_for(inference_engine, vc)
        inference_steps = Cortex.scan_inference_request(inference_request)

        @test length(inference_steps) == 1
        @test inference_steps[1] == Cortex.get_connection_message_to_variable(inference_engine, vc, f2)
    end

    # f1 -> vc and f2 -> vc are pending, should be in the inference round
    @testset let (inference_engine, f1, f2, vc, left, right) = make_small_node_variable_node_model()
        Cortex.set_value!(left, 1.0)
        Cortex.set_value!(right, 1.0)

        inference_request = Cortex.request_inference_for(inference_engine, vc)
        inference_steps = Cortex.scan_inference_request(inference_request)

        @test length(inference_steps) == 2
        @test inference_steps[1] == Cortex.get_connection_message_to_variable(inference_engine, vc, f1)
        @test inference_steps[2] == Cortex.get_connection_message_to_variable(inference_engine, vc, f2)
    end
end

@testitem "An inference round should correctly resolve dependencies of required messages" setup = [TestUtils] begin
    using .TestUtils
    using JET

    model = BipartiteFactorGraph(Variable, Factor, Connection)

    v1 = add_variable!(model, Variable(name = :v1))
    v2 = add_variable!(model, Variable(name = :v2))
    v3 = add_variable!(model, Variable(name = :v3))

    f1 = add_factor!(model, Factor(functional_form = :f1))
    f2 = add_factor!(model, Factor(functional_form = :f2))

    # |v1| - :out |f1| :in - |v2| - :out |f2| :in - |v3|
    add_edge!(model, v1, f1, Connection(label = :out))
    add_edge!(model, v2, f1, Connection(label = :in))
    add_edge!(model, v2, f2, Connection(label = :out))
    add_edge!(model, v3, f2, Connection(label = :in))

    # We disable dependency resolution because we will add dependencies manually
    inference_engine = Cortex.InferenceEngine(model_engine = model, resolve_dependencies = false)

    # A message from f1 to v2 depends on a message from v1 to f1
    Cortex.add_dependency!(
        Cortex.get_connection_message_to_variable(inference_engine, v2, f1),
        Cortex.get_connection_message_to_factor(inference_engine, v1, f1)
    )

    # A message from f2 to v2 depends on a message from v3 to f2
    Cortex.add_dependency!(
        Cortex.get_connection_message_to_variable(inference_engine, v2, f2),
        Cortex.get_connection_message_to_factor(inference_engine, v3, f2)
    )

    # A marginal for v2 depends on a message f1 to v2 and a message f2 to v2
    Cortex.add_dependency!(
        Cortex.get_variable_marginal(Cortex.get_variable(inference_engine, v2)),
        Cortex.get_connection_message_to_variable(inference_engine, v2, f1)
    )

    Cortex.add_dependency!(
        Cortex.get_variable_marginal(Cortex.get_variable(inference_engine, v2)),
        Cortex.get_connection_message_to_variable(inference_engine, v2, f2)
    )

    # We set pending messages from v1 to f1 and v3 to f2
    # Since they are direct dependencies of messages to v2, they should be added to the inference round
    Cortex.set_value!(Cortex.get_connection_message_to_factor(inference_engine, v1, f1), 1.0)
    Cortex.set_value!(Cortex.get_connection_message_to_factor(inference_engine, v3, f2), 1.0)

    inference_request = Cortex.request_inference_for(inference_engine, v2)
    inference_steps = Cortex.scan_inference_request(inference_request)

    @test length(inference_steps) == 2
    @test inference_steps[1] == Cortex.get_connection_message_to_variable(inference_engine, v2, f1)
    @test inference_steps[2] == Cortex.get_connection_message_to_variable(inference_engine, v2, f2)
end

@testitem "Inference in Beta-Bernoulli model" setup = [TestUtils, TestDistributions] begin
    using .TestUtils, .TestDistributions
    using JET, BipartiteFactorGraphs, StableRNGs

    function computer(engine::Cortex.InferenceEngine, signal::Cortex.Signal, dependencies::Vector{Cortex.Signal})
        if signal.type == Cortex.InferenceSignalTypes.MessageToVariable
            _, factor_id = (signal.metadata::Tuple{Int, Int})

            factor = Cortex.get_factor(engine, factor_id)

            if Cortex.get_factor_functional_form(factor) === :bernoulli
                r = Cortex.get_value(dependencies[1])::Bool
                return Beta(one(r) + r, 2one(r) - r)
            elseif Cortex.get_factor_functional_form(factor) === :prior
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
        graph = BipartiteFactorGraph(Variable, Factor, Connection)

        p = add_variable!(graph, Variable(name = :p))
        o = []
        f = []

        for i in 1:n
            oi = add_variable!(graph, Variable(name = :o, index = (i,)))
            fi = add_factor!(graph, Factor(functional_form = :bernoulli))

            push!(o, oi)
            push!(f, fi)

            add_edge!(graph, p, fi, Connection(label = :out))
            add_edge!(graph, oi, fi, Connection(label = :out))
        end

        engine = Cortex.InferenceEngine(
            model_engine = graph,
            dependency_resolver = Cortex.DefaultDependencyResolver(),
            inference_request_processor = computer
        )

        return engine, p, o, f
    end

    function experiment(dataset)
        n = length(dataset)
        engine, p, o, f = make_beta_bernoulli_model(n)

        for i in 1:n
            Cortex.set_value!(Cortex.get_connection_message_to_factor(engine, o[i], f[i]), dataset[i])
        end

        Cortex.update_marginals!(engine, p)

        return Cortex.get_value(Cortex.get_variable_marginal(Cortex.get_variable(engine, p)))
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

@testitem "Inference in a simple SSM model - Belief Propagation" setup = [TestUtils, TestDistributions] begin
    using .TestUtils, .TestDistributions
    using JET, BipartiteFactorGraphs, StableRNGs

    function computer(engine::Cortex.InferenceEngine, signal::Cortex.Signal, dependencies::Vector{Cortex.Signal})
        if signal.type == Cortex.InferenceSignalTypes.IndividualMarginal
            return reduce(product, Cortex.get_value.(dependencies))
        elseif signal.type == Cortex.InferenceSignalTypes.MessageToFactor
            return reduce(product, Cortex.get_value.(dependencies))
        elseif signal.type == Cortex.InferenceSignalTypes.MessageToVariable
            @assert length(dependencies) == 1
            input = Cortex.get_value(dependencies[1])

            if typeof(input) <: Real
                return NormalMeanVariance(input, 1.0)
            elseif typeof(input) <: NormalMeanVariance
                return NormalMeanVariance(input.mean, input.variance + 1.0)
            else
                error("Unreachable reached")
            end
        end

        error("Unreachable reached")
    end

    # In this model, we assume that both the likelihood and the transition are Normal
    # with fixed variance equal to 1.0.
    function make_ssm_model(n)
        graph = BipartiteFactorGraph(Variable, Factor, Connection)

        x = [add_variable!(graph, Variable(name = :x, index = (i,))) for i in 1:n]
        y = [add_variable!(graph, Variable(name = :y, index = (i,))) for i in 1:n]

        likelihood = [add_factor!(graph, Factor(functional_form = :likelihood)) for i in 1:n]
        transition = [add_factor!(graph, Factor(functional_form = :transition)) for i in 1:(n - 1)]

        for i in 1:n
            add_edge!(graph, y[i], likelihood[i], Connection(label = :out))
            add_edge!(graph, x[i], likelihood[i], Connection(label = :out))
        end

        for i in 1:(n - 1)
            add_edge!(graph, x[i], transition[i], Connection(label = :out))
            add_edge!(graph, x[i + 1], transition[i], Connection(label = :in))
        end

        engine = Cortex.InferenceEngine(
            model_engine = graph,
            dependency_resolver = Cortex.DefaultDependencyResolver(),
            inference_request_processor = computer
        )

        return engine, x, y, likelihood, transition
    end

    function experiment(dataset)
        n = length(dataset)
        engine, x, y, likelihood, transition = make_ssm_model(n)

        for i in 1:n
            Cortex.set_value!(Cortex.get_connection_message_to_factor(engine, y[i], likelihood[i]), dataset[i])
        end

        Cortex.update_marginals!(engine, x)

        return Cortex.get_value.(Cortex.get_variable_marginal.(Cortex.get_variable.(engine, x)))
    end

    rng = StableRNG(1234)
    dataset = zeros(100)
    for i in eachindex(dataset)
        dataset[i] = 2i + randn(rng)
    end

    answer = experiment(dataset)

    @test all(>=(0.0), map(x -> x.mean, answer))
    @test all(>=(0.0), diff(map(x -> x.mean, answer))) # this is a consequence of the dataset being an increasing function of the index
    @test all(>=(0.0), map(x -> x.variance, answer))
end

@testitem "Inference in a simple SSM model - Mean Field" setup = [TestUtils, TestDistributions] begin
    using .TestUtils, .TestDistributions
    using JET, BipartiteFactorGraphs, StableRNGs, Random

    struct MeanFieldResolver <: Cortex.AbstractDependencyResolver end

    function Cortex.resolve_variable_dependencies!(::MeanFieldResolver, engine::Cortex.InferenceEngine, variable_id)
        marginal = Cortex.get_variable_marginal(Cortex.get_variable(engine, variable_id))
        for factor_id in Cortex.get_connected_factor_ids(engine, variable_id)
            Cortex.add_dependency!(
                marginal, Cortex.get_connection_message_to_variable(engine, variable_id, factor_id); intermediate = true
            )
        end
        return nothing
    end

    function Cortex.resolve_factor_dependencies!(::MeanFieldResolver, engine::Cortex.InferenceEngine, factor_id)
        variable_ids_connected_to_factor = Cortex.get_connected_variable_ids(engine, factor_id)

        for variable_id1 in variable_ids_connected_to_factor, variable_id2 in variable_ids_connected_to_factor
            if variable_id1 !== variable_id2
                Cortex.add_dependency!(
                    Cortex.get_connection_message_to_variable(engine, variable_id1, factor_id),
                    Cortex.get_variable_marginal(Cortex.get_variable(engine, variable_id2));
                    weak = true
                )
            end
        end
    end

    function get_name_of_variable(engine::Cortex.InferenceEngine, variable_id)
        return Cortex.get_variable_name(Cortex.get_variable(engine, variable_id))
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
                return NormalMeanPrecision(
                    mean(Cortex.get_value(dependencies[x])), mean(Cortex.get_value(dependencies[ssnoise]))
                )
            end

            if !isnothing(y) && !isnothing(obsnoise)
                return NormalMeanPrecision(
                    Cortex.get_value(dependencies[y]), mean(Cortex.get_value(dependencies[obsnoise]))
                )
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
        graph = BipartiteFactorGraph(Variable, Factor, Connection)

        ssnoise = add_variable!(graph, Variable(name = :ssnoise))
        obsnoise = add_variable!(graph, Variable(name = :obsnoise))

        x = [add_variable!(graph, Variable(name = :x, index = (i,))) for i in 1:n]
        y = [add_variable!(graph, Variable(name = :y, index = (i,))) for i in 1:n]

        likelihood = [add_factor!(graph, Factor(functional_form = :likelihood)) for i in 1:n]
        transition = [add_factor!(graph, Factor(functional_form = :transition)) for i in 1:(n - 1)]

        for i in 1:n
            add_edge!(graph, y[i], likelihood[i], Connection(label = :out))
            add_edge!(graph, x[i], likelihood[i], Connection(label = :out))
            add_edge!(graph, obsnoise, likelihood[i], Connection(label = :out))
        end

        for i in 1:(n - 1)
            add_edge!(graph, x[i], transition[i], Connection(label = :out))
            add_edge!(graph, x[i + 1], transition[i], Connection(label = :in))
            add_edge!(graph, ssnoise, transition[i], Connection(label = :out))
        end

        engine = Cortex.InferenceEngine(
            model_engine = graph, dependency_resolver = MeanFieldResolver(), inference_request_processor = computer
        )

        # Initial marginals
        Cortex.set_value!(Cortex.get_variable_marginal(Cortex.get_variable(engine, ssnoise)), Gamma(1.0, 1.0))
        Cortex.set_value!(Cortex.get_variable_marginal(Cortex.get_variable(engine, obsnoise)), Gamma(1.0, 1.0))

        for i in 1:n
            Cortex.set_value!(
                Cortex.get_variable_marginal(Cortex.get_variable(engine, x[i])), NormalMeanPrecision(0.0, 1.0)
            )
        end

        return engine, x, y, obsnoise, ssnoise, likelihood, transition
    end

    function experiment(dataset, vmp_iterations)
        n = length(dataset)
        engine, x, y, obsnoise, ssnoise, likelihood, transition = make_ssm_model(n)

        for i in 1:n
            Cortex.set_value!(Cortex.get_variable_marginal(Cortex.get_variable(engine, y[i])), dataset[i])
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

            # Check that the marginals can be updated several times
            Cortex.update_marginals!(engine, ssnoise)
            Cortex.update_marginals!(engine, ssnoise)
            Cortex.update_marginals!(engine, ssnoise)

            # Check that the updates can be merged into a single update
            Cortex.update_marginals!(engine, [ssnoise, obsnoise])
        end

        return (
            x = Cortex.get_value.(Cortex.get_variable_marginal.(Cortex.get_variable.(engine, x))),
            ssnoise = Cortex.get_value(Cortex.get_variable_marginal(Cortex.get_variable(engine, ssnoise))),
            obsnoise = Cortex.get_value(Cortex.get_variable_marginal(Cortex.get_variable(engine, obsnoise)))
        )
    end

    rng = StableRNG(1234)

    n = 100
    ssnoise_real = 100.0
    obsnoise_real = 100.0
    random_walk = [0.0]
    for i in 2:n
        push!(random_walk, rand(rng, NormalMeanPrecision(random_walk[i - 1], ssnoise_real)))
    end

    observations = []
    for i in 1:n
        push!(observations, rand(rng, NormalMeanPrecision(random_walk[i], obsnoise_real)))
    end

    vmp_iterations = 100
    answer = experiment(observations, vmp_iterations)

    # The actual answer isn't precise because of the mean-field assumption
    # as well as the fact that the convergence of the VMP updates 
    # depends on the initial conditions and order of updates
    @test mean(answer.obsnoise) > 50.0
    @test mean(answer.ssnoise) > 50.0
end

@testitem "Inference in a simple SSM model - Structured" setup = [TestUtils, TestDistributions] begin
    using .TestUtils, .TestDistributions
    using JET, BipartiteFactorGraphs, StableRNGs, Random

    struct StructuredResolver <: Cortex.AbstractDependencyResolver end

    function Cortex.resolve_variable_dependencies!(::StructuredResolver, engine::Cortex.InferenceEngine, variable_id)
        return Cortex.resolve_variable_dependencies!(Cortex.DefaultDependencyResolver(), engine, variable_id)
    end

    function Cortex.resolve_factor_dependencies!(
        resolver::StructuredResolver, engine::Cortex.InferenceEngine, factor_id
    )
        factor_data = Cortex.get_factor(engine, factor_id)

        # For likelihood we do mean-field like updates
        if Cortex.get_factor_functional_form(factor_data) === :likelihood
            variable_ids_connected_to_factor = Cortex.get_connected_variable_ids(engine, factor_id)
            for variable_id1 in variable_ids_connected_to_factor, variable_id2 in variable_ids_connected_to_factor
                if variable_id1 !== variable_id2
                    Cortex.add_dependency!(
                        Cortex.get_connection_message_to_variable(engine, variable_id1, factor_id),
                        Cortex.get_variable_marginal(Cortex.get_variable(engine, variable_id2));
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
                name = Cortex.get_variable_name(Cortex.get_variable(engine, variable_id))
                if haskey(clusters, name)
                    push!(clusters[name], variable_id)
                else
                    clusters[name] = [variable_id]
                end
            end

            deps = map(values(clusters)) do cluster
                if length(cluster) == 1
                    return Cortex.get_variable_marginal(Cortex.get_variable(engine, first(cluster)))
                else
                    new_joint_marginal = Cortex.Signal(
                        type = Cortex.InferenceSignalTypes.JointMarginal, metadata = (factor_id, cluster)
                    )
                    for v_id in cluster
                        # Add the linked signal to the variable
                        Cortex.link_signal_to_variable!(Cortex.get_variable(engine, v_id), new_joint_marginal)

                        # Add the joint marginal to the factor
                        Cortex.add_local_marginal_to_factor!(Cortex.get_factor(engine, factor_id), new_joint_marginal)

                        # Should be always weak here?
                        Cortex.add_dependency!(
                            new_joint_marginal,
                            Cortex.get_connection_message_to_factor(engine, v_id, factor_id);
                            weak = true
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
                            Cortex.get_connection_message_to_variable(engine, m1, factor_id),
                            Cortex.get_connection_message_to_factor(engine, m2, factor_id);
                        )
                    end
                end

                for m1 in cluster
                    for (another_index, another_cluster_joint_marginal) in enumerate(deps)
                        if index !== another_index
                            Cortex.add_dependency!(
                                Cortex.get_connection_message_to_variable(engine, m1, factor_id),
                                another_cluster_joint_marginal;
                                weak = true
                            )
                        end
                    end
                end
            end
        end
    end

    function get_name_of_variable(engine::Cortex.InferenceEngine, variable_id)
        return Cortex.get_variable_name(Cortex.get_variable(engine, variable_id))
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

            return MvNormalMeanPrecision(μ, W)

        elseif signal.type == Cortex.InferenceSignalTypes.MessageToVariable
            v, f = (signal.metadata::Tuple{Int, Int})

            factor = Cortex.get_factor(engine, f)

            if Cortex.get_factor_functional_form(factor) === :likelihood
                y = findfirst(d -> get_name_of_variable(engine, first(d.metadata)) == :y, dependencies)
                x = findfirst(d -> get_name_of_variable(engine, first(d.metadata)) == :x, dependencies)
                obsnoise = findfirst(d -> get_name_of_variable(engine, first(d.metadata)) == :obsnoise, dependencies)

                if !isnothing(y) && !isnothing(obsnoise)
                    return NormalMeanPrecision(
                        Cortex.get_value(dependencies[y]), mean(Cortex.get_value(dependencies[obsnoise]))
                    )
                end

                if !isnothing(x) && !isnothing(y)
                    q_out = Cortex.get_value(dependencies[y])
                    q_μ = Cortex.get_value(dependencies[x])
                    θ = 2 / (var(q_μ) + abs2(q_out - mean(q_μ)))
                    α = convert(typeof(θ), 1.5)
                    return Gamma(α, θ)
                end

                error("unreachable reached in likelihood")
            elseif Cortex.get_factor_functional_form(factor) === :transition
                msg = findfirst(d -> d.type == Cortex.InferenceSignalTypes.MessageToFactor, dependencies)
                mrg = findfirst(d -> d.type == Cortex.InferenceSignalTypes.IndividualMarginal, dependencies)
                jmrg = findfirst(d -> d.type == Cortex.InferenceSignalTypes.JointMarginal, dependencies)

                if !isnothing(msg) && !isnothing(mrg)
                    v_msg = Cortex.get_value(dependencies[msg])
                    v_mrg = Cortex.get_value(dependencies[mrg])

                    m_μ_mean = mean(v_msg)
                    m_μ_var = var(v_msg)

                    return NormalMeanPrecision(m_μ_mean, inv(m_μ_var + inv(mean(v_mrg))))
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
        graph = BipartiteFactorGraph(Variable, Factor, Connection)

        ssnoise = add_variable!(graph, Variable(name = :ssnoise))
        obsnoise = add_variable!(graph, Variable(name = :obsnoise))

        x = [add_variable!(graph, Variable(name = :x, index = (i,))) for i in 1:n]
        y = [add_variable!(graph, Variable(name = :y, index = (i,))) for i in 1:n]

        likelihood = [add_factor!(graph, Factor(functional_form = :likelihood)) for i in 1:n]
        transition = [add_factor!(graph, Factor(functional_form = :transition)) for i in 1:(n - 1)]

        for i in 1:n
            add_edge!(graph, y[i], likelihood[i], Connection(label = :out))
            add_edge!(graph, x[i], likelihood[i], Connection(label = :out))
            add_edge!(graph, obsnoise, likelihood[i], Connection(label = :out))
        end

        for i in 1:(n - 1)
            add_edge!(graph, x[i], transition[i], Connection(label = :out))
            add_edge!(graph, x[i + 1], transition[i], Connection(label = :in))
            add_edge!(graph, ssnoise, transition[i], Connection(label = :out))
        end

        engine = Cortex.InferenceEngine(
            model_engine = graph,
            dependency_resolver = StructuredResolver(),
            inference_request_processor = computer,
            trace = true
        )

        # Initial marginals
        Cortex.set_value!(Cortex.get_variable_marginal(Cortex.get_variable(engine, ssnoise)), Gamma(1.0, 1.0))
        Cortex.set_value!(Cortex.get_variable_marginal(Cortex.get_variable(engine, obsnoise)), Gamma(1.0, 1.0))

        for i in 1:n
            Cortex.set_value!(
                Cortex.get_variable_marginal(Cortex.get_variable(engine, x[i])), NormalMeanPrecision(0.0, 1.0)
            )
        end

        return engine, x, y, obsnoise, ssnoise, likelihood, transition
    end

    function experiment(dataset, vmp_iterations)
        n = length(dataset)
        engine, x, y, obsnoise, ssnoise, likelihood, transition = make_ssm_model(n)

        for i in 1:n
            Cortex.set_value!(Cortex.get_variable_marginal(Cortex.get_variable(engine, y[i])), dataset[i])
        end

        for iteration in 1:vmp_iterations
            if div(iteration, 2) == 1
                Cortex.update_marginals!(engine, x)
                Cortex.update_marginals!(engine, ssnoise)
                Cortex.update_marginals!(engine, obsnoise)
            else
                Cortex.update_marginals!(engine, obsnoise)
                Cortex.update_marginals!(engine, ssnoise)
                Cortex.update_marginals!(engine, x)
            end

            Cortex.update_marginals!(engine, ssnoise)
            Cortex.update_marginals!(engine, ssnoise)
            Cortex.update_marginals!(engine, ssnoise)

            Cortex.update_marginals!(engine, x)
            Cortex.update_marginals!(engine, x)

            Cortex.update_marginals!(engine, obsnoise)
            Cortex.update_marginals!(engine, obsnoise)
            Cortex.update_marginals!(engine, obsnoise)

            Cortex.update_marginals!(engine, [ssnoise, obsnoise])

            Cortex.update_marginals!(engine, collect(Iterators.flatten(([ssnoise, obsnoise], x))))
        end

        return (
            engine = engine,
            x = Cortex.get_value.(Cortex.get_variable_marginal.(Cortex.get_variable.(engine, x))),
            ssnoise = Cortex.get_value(Cortex.get_variable_marginal(Cortex.get_variable(engine, ssnoise))),
            obsnoise = Cortex.get_value(Cortex.get_variable_marginal(Cortex.get_variable(engine, obsnoise)))
        )
    end

    rng = StableRNG(1234)

    n = 100
    ssnoise_real = 100.0
    obsnoise_real = 100.0
    random_walk = [0.0]
    for i in 2:n
        push!(random_walk, rand(rng, NormalMeanPrecision(random_walk[i - 1], ssnoise_real)))
    end

    observations = []
    for i in 1:n
        push!(observations, rand(rng, NormalMeanPrecision(random_walk[i], obsnoise_real)))
    end

    vmp_iterations = 100
    answer = experiment(observations, vmp_iterations)

    # The actual answer isn't precise because of the mean-field assumption
    # as well as the fact that the convergence of the VMP updates 
    # depends on the initial conditions and order of updates
    @test mean(answer.obsnoise) > 90
    @test mean(answer.ssnoise) > 90
end

@testitem "Tracing inference in a simple IID model" setup = [TestUtils] begin
    using .TestUtils
    using JET, BipartiteFactorGraphs

    function computer(engine::Cortex.InferenceEngine, signal::Cortex.Signal, dependencies::Vector{Cortex.Signal})
        if signal.type == Cortex.InferenceSignalTypes.MessageToVariable
            _, factor_id = (signal.metadata::Tuple{Int, Int})

            factor = Cortex.get_factor(engine, factor_id)

            if Cortex.get_factor_functional_form(factor) === :likelihood1
                return 2 * Cortex.get_value(dependencies[1])
            elseif Cortex.get_factor_functional_form(factor) === :likelihood2
                return 2 * Cortex.get_value(dependencies[1])
            elseif Cortex.get_factor_functional_form(factor) === :prior
                error("Should not be invoked")
            end
        elseif signal.type == Cortex.InferenceSignalTypes.IndividualMarginal
            return sum(Cortex.get_value.(dependencies))
        end

        error("Unreachable reached")
    end

    graph = BipartiteFactorGraph(Variable, Factor, Connection)

    # The "center" of the model
    p = add_variable!(graph, Variable(name = :p))

    # The observed outcomes
    o1 = add_variable!(graph, Variable(name = :y1))
    o2 = add_variable!(graph, Variable(name = :y2))

    # Priors
    fp = add_factor!(graph, Factor(functional_form = :prior))

    # Likelihoods
    f1 = add_factor!(graph, Factor(functional_form = :likelihood1))
    f2 = add_factor!(graph, Factor(functional_form = :likelihood2))

    # Connections between the parameter `p` and the factors
    add_edge!(graph, p, fp, Connection(label = :out))
    add_edge!(graph, p, f1, Connection(label = :in))
    add_edge!(graph, p, f2, Connection(label = :in))

    # Connections between the observed outcomes and the likelihoods
    add_edge!(graph, o1, f1, Connection(label = :out))
    add_edge!(graph, o2, f2, Connection(label = :out))

    inference_engine = Cortex.InferenceEngine(
        model_engine = graph,
        dependency_resolver = Cortex.DefaultDependencyResolver(),
        inference_request_processor = computer,
        trace = true
    )

    # Set data
    o1_value = 1
    o2_value = 2

    Cortex.set_value!(Cortex.get_connection_message_to_factor(inference_engine, o1, f1), o1_value)
    Cortex.set_value!(Cortex.get_connection_message_to_factor(inference_engine, o2, f2), o2_value)

    # Set prior
    Cortex.set_value!(Cortex.get_connection_message_to_variable(inference_engine, p, fp), 3)

    Cortex.update_marginals!(inference_engine, p)

    @test Cortex.get_value(Cortex.get_variable_marginal(Cortex.get_variable(inference_engine, p))) == 9

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

    @test occursin(
        "MessageToVariable(from = Factor(functional_form = likelihood1), to = Variable(name = p))",
        trace_string_representation
    )
    @test occursin(
        "MessageToVariable(from = Factor(functional_form = likelihood2), to = Variable(name = p))",
        trace_string_representation
    )

    @test occursin("IndividualMarginal(Variable(name = p))", trace_string_representation)
end
