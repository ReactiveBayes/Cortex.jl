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

        inference_task = Cortex.create_inference_task(model, vc)
        inference_steps = Cortex.scan_inference_task(inference_task)

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

        inference_task = Cortex.create_inference_task(model, vc)
        inference_steps = Cortex.scan_inference_task(inference_task)

        @test length(inference_steps) == 1
        @test inference_steps[1] == Cortex.get_edge_message_to_variable(model, vc, f1)
    end

    # f2 -> vc is pending, should be in the inference round
    @testset let (model, f1, f2, vc, left, right) = make_small_node_variable_node_model()
        Cortex.set_value!(right, 1.0)

        inference_task = Cortex.create_inference_task(model, vc)
        inference_steps = Cortex.scan_inference_task(inference_task)

        @test length(inference_steps) == 1
        @test inference_steps[1] == Cortex.get_edge_message_to_variable(model, vc, f2)
    end

    # f1 -> vc and f2 -> vc are pending, should be in the inference round
    @testset let (model, f1, f2, vc, left, right) = make_small_node_variable_node_model()
        Cortex.set_value!(left, 1.0)
        Cortex.set_value!(right, 1.0)

        inference_task = Cortex.create_inference_task(model, vc)
        inference_steps = Cortex.scan_inference_task(inference_task)

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

    inference_task = Cortex.create_inference_task(model, v2)
    inference_steps = Cortex.scan_inference_task(inference_task)

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

    Cortex.resolve_dependencies!(Cortex.DefaultDependencyResolver(), model)

    # Set data
    Cortex.set_value!(Cortex.get_edge_message_to_factor(model, o1, f1), 1)
    Cortex.set_value!(Cortex.get_edge_message_to_factor(model, o2, f2), 2)

    # Set prior
    Cortex.set_value!(Cortex.get_edge_message_to_variable(model, p, fp), 3)

    function computer(model::Model, signal::Cortex.Signal, dependencies::Vector{Cortex.Signal})
        if signal.type == Cortex.InferenceSignalTypes.MessageToVariable
            f = Cortex.get_metadata(signal, :f, Int)

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

    Cortex.update_posterior!(computer, model, p)

    @test Cortex.get_value(Cortex.get_variable_marginal(model, p)) == 9
end

@testitem "Inference in Beta-Bernoulli model" setup = [ModelUtils] begin
    using .ModelUtils
    using JET, BipartiteFactorGraphs, StableRNGs

    struct Beta
        a::Float64
        b::Float64
    end

    struct Bernoulli
        y::Bool
    end

    function make_beta_bernoulli_model(n)
        model = Model()

        p = add_variable_to_model!(model, :p)
        o = []
        f = []

        for i in 1:n
            oi = add_variable_to_model!(model, :o, i)
            fi = add_factor_to_model!(model, Bernoulli)

            push!(o, oi)
            push!(f, fi)

            add_edge_to_model!(model, p, fi)
            add_edge_to_model!(model, oi, fi)
        end

        Cortex.resolve_dependencies!(Cortex.DefaultDependencyResolver(), model)

        return model, p, o, f
    end

    function computer(model::Model, signal::Cortex.Signal, dependencies::Vector{Cortex.Signal})
        if signal.type == Cortex.InferenceSignalTypes.MessageToVariable
            f = Cortex.get_metadata(signal, :f, Int)

            factor = get_factor_data(model.graph, f)

            if factor.type === Bernoulli
                r = Cortex.get_value(dependencies[1])::Bool
                return Beta(one(r) + r, 2one(r) - r)
            elseif factor.type === :prior
                error("Should not be invoked")
            end
        elseif signal.type == Cortex.InferenceSignalTypes.IndividualMarginal
            answer = Cortex.get_value(dependencies[1])::Beta
            for i in 2:length(dependencies)
                @inbounds next = Cortex.get_value(dependencies[i])::Beta
                answer = Beta(answer.a + next.a - 1, answer.b + next.b - 1)
            end
            return answer
        end

        error("Unreachable reached")
    end

    function experiment(dataset)
        n = length(dataset)
        model, p, o, f = make_beta_bernoulli_model(n)

        for i in 1:n
            Cortex.set_value!(Cortex.get_edge_message_to_factor(model, o[i], f[i]), dataset[i])
        end

        Cortex.update_posterior!(computer, model, p)

        return Cortex.get_value(Cortex.get_variable_marginal(model, p))
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

@testitem "Inference in a simple SSM model - Belief Propagation" setup = [ModelUtils] begin
    using .ModelUtils
    using JET, BipartiteFactorGraphs, StableRNGs

    struct Normal
        mean::Float64
        variance::Float64
    end

    # In this model, we assume that both the likelihood and the transition are Normal
    # with fixed variance equal to 1.0.
    function make_ssm_model(n)
        model = Model()

        x = [add_variable_to_model!(model, :x, i) for i in 1:n]
        y = [add_variable_to_model!(model, :y, i) for i in 1:n]

        likelihood = [add_factor_to_model!(model, :likelihood) for i in 1:n]
        transition = [add_factor_to_model!(model, :transition) for i in 1:(n - 1)]

        for i in 1:n
            add_edge_to_model!(model, y[i], likelihood[i])
            add_edge_to_model!(model, x[i], likelihood[i])
        end

        for i in 1:(n - 1)
            add_edge_to_model!(model, x[i], transition[i])
            add_edge_to_model!(model, x[i + 1], transition[i])
        end

        Cortex.resolve_dependencies!(Cortex.DefaultDependencyResolver(), model)

        return model, x, y, likelihood, transition
    end

    function product(left::Normal, right::Normal)
        xi = left.mean / left.variance + right.mean / right.variance
        w = 1 / left.variance + 1 / right.variance
        variance = 1 / w
        mean = variance * xi
        return Normal(mean, variance)
    end

    function computer(model::Model, signal::Cortex.Signal, dependencies::Vector{Cortex.Signal})
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

    function experiment(dataset)
        n = length(dataset)
        model, x, y, likelihood, transition = make_ssm_model(n)

        for i in 1:n
            Cortex.set_value!(Cortex.get_edge_message_to_factor(model, y[i], likelihood[i]), dataset[i])
        end

        Cortex.update_posterior!(computer, model, x)

        return Cortex.get_value.(Cortex.get_variable_marginal.(model, x))
    end

    rng = StableRNG(1234)
    dataset = rand(rng, 100)

    answer = experiment(dataset)
end

@testitem "Inference in a simple SSM model - Mean Field" setup = [ModelUtils] begin
    using .ModelUtils
    using JET, BipartiteFactorGraphs, StableRNGs

    struct Normal
        mean::Float64
        precision::Float64
    end

    struct Gamma
        shape::Float64
        scale::Float64
    end

    mean(g::Gamma) = g.shape * g.scale

    mean(n::Normal) = n.mean
    var(n::Normal) = 1 / n.precision

    struct MeanFieldResolver <: Cortex.AbstractDependencyResolver end

    function Cortex.resolve_variable_dependencies!(resolver::MeanFieldResolver, model::Model, variable)
        factors_connected_to_variable = Cortex.get_variable_neighbors(model, variable)

        marginal = Cortex.get_variable_marginal(model, variable)
        for factor in factors_connected_to_variable
            Cortex.add_dependency!(
                marginal, Cortex.get_edge_message_to_variable(model, variable, factor); intermediate = true
            )
        end

        return nothing
    end

    function Cortex.resolve_factor_dependencies!(resolver::MeanFieldResolver, model::Model, factor)
        variables_connected_to_factor = Cortex.get_factor_neighbors(model, factor)

        for v1 in variables_connected_to_factor, v2 in variables_connected_to_factor
            if v1 !== v2
                Cortex.add_dependency!(
                    Cortex.get_edge_message_to_variable(model, v1, factor),
                    Cortex.get_variable_marginal(model, v2);
                    weak = true
                )
            end
        end
    end

    function make_ssm_model(n)
        model = Model()

        ssnoise = add_variable_to_model!(model, :ssnoise)
        obsnoise = add_variable_to_model!(model, :obsnoise)

        x = [add_variable_to_model!(model, :x, i) for i in 1:n]
        y = [add_variable_to_model!(model, :y, i) for i in 1:n]

        likelihood = [add_factor_to_model!(model, :likelihood) for i in 1:n]
        transition = [add_factor_to_model!(model, :transition) for i in 1:(n - 1)]

        for i in 1:n
            add_edge_to_model!(model, y[i], likelihood[i])
            add_edge_to_model!(model, x[i], likelihood[i])
            add_edge_to_model!(model, obsnoise, likelihood[i])
        end

        for i in 1:(n - 1)
            add_edge_to_model!(model, x[i], transition[i])
            add_edge_to_model!(model, x[i + 1], transition[i])
            add_edge_to_model!(model, ssnoise, transition[i])
        end

        Cortex.resolve_dependencies!(MeanFieldResolver(), model)

        # Initial marginals
        Cortex.set_value!(Cortex.get_variable_marginal(model, ssnoise), Gamma(1.0, 1.0))
        Cortex.set_value!(Cortex.get_variable_marginal(model, obsnoise), Gamma(1.0, 1.0))

        for i in 1:n
            Cortex.set_value!(Cortex.get_variable_marginal(model, x[i]), Normal(0.0, 1.0))
        end

        return model, x, y, obsnoise, ssnoise, likelihood, transition
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

    function computer(model::Model, signal::Cortex.Signal, dependencies::Vector{Cortex.Signal})
        if signal.type == Cortex.InferenceSignalTypes.IndividualMarginal
            return reduce(product, Cortex.get_value.(dependencies))
        elseif signal.type == Cortex.InferenceSignalTypes.MessageToFactor
            return reduce(product, Cortex.get_value.(dependencies))
        elseif signal.type == Cortex.InferenceSignalTypes.MessageToVariable
            @assert length(dependencies) == 2

            x = findfirst(d -> Cortex.get_metadata(d, :name, Symbol) == :x, dependencies)
            y = findfirst(d -> Cortex.get_metadata(d, :name, Symbol) == :y, dependencies)
            ssnoise = findfirst(d -> Cortex.get_metadata(d, :name, Symbol) == :ssnoise, dependencies)
            obsnoise = findfirst(d -> Cortex.get_metadata(d, :name, Symbol) == :obsnoise, dependencies)

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

            if filter(d -> Cortex.get_metadata(d, :name, Symbol) == :x, dependencies) |> collect |> length == 2
                q_out = Cortex.get_value(dependencies[1])
                q_μ = Cortex.get_value(dependencies[2])
                θ = 2 / (var(q_out) + var(q_μ) + abs2(mean(q_out) - mean(q_μ)))
                α = convert(typeof(θ), 1.5)
                return Gamma(α, θ)
            end

            error("Unreachable reached", dependencies)
        end

        error("Unreachable reached")
    end

    function experiment(dataset, vmp_iterations)
        n = length(dataset)
        model, x, y, obsnoise, ssnoise, likelihood, transition = make_ssm_model(n)

        for i in 1:n
            Cortex.set_value!(Cortex.get_variable_marginal(model, y[i]), dataset[i])
        end

        for iteration in 1:vmp_iterations
            Cortex.update_posterior!(computer, model, x)
            Cortex.update_posterior!(computer, model, ssnoise)
            Cortex.update_posterior!(computer, model, obsnoise)
        end

        return (
            x = Cortex.get_value.(Cortex.get_variable_marginal.(model, x)),
            ssnoise = Cortex.get_value(Cortex.get_variable_marginal(model, ssnoise)),
            obsnoise = Cortex.get_value(Cortex.get_variable_marginal(model, obsnoise))
        )
    end

    rng = StableRNG(1234)
    dataset = rand(rng, 10)

    answer = experiment(dataset, 100)

    @show answer.ssnoise
end