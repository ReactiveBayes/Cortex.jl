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

@testmodule InferenceUtils begin
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

        function Connection(label, index = 0)
            return new(
                label,
                index,
                Cortex.Signal(type = Cortex.InferenceSignalTypes.MessageToVariable),
                Cortex.Signal(type = Cortex.InferenceSignalTypes.MessageToFactor)
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

@testitem "Test inference related functions for custom inference engine in `InferenceUtils`" setup = [InferenceUtils] begin
    using .InferenceUtils
    using BipartiteFactorGraphs

    graph = BipartiteFactorGraph()

    variable_id_1 = add_variable!(graph, Variable(:a))
    variable_id_2 = add_variable!(graph, Variable(:b, 1))
    variable_id_3 = add_variable!(graph, Variable(:c, 2, 3))

    inference_engine = Cortex.InferenceEngine(model_backend = graph)

    # Here we check that the variable data structure returned from the inference engine's backend is correct
    @test Cortex.get_variable(inference_engine, variable_id_1).name == :a
    @test Cortex.get_variable(inference_engine, variable_id_2).name == :b
    @test Cortex.get_variable(inference_engine, variable_id_3).name == :c
    @test Cortex.get_variable(inference_engine, variable_id_1).index == ()
    @test Cortex.get_variable(inference_engine, variable_id_2).index == (1,)
    @test Cortex.get_variable(inference_engine, variable_id_3).index == (2, 3)

    # We check that the marginal of the variable is a `Signal` object
    @test Cortex.get_marginal(Cortex.get_variable(inference_engine, variable_id_1)) isa Cortex.Signal
    @test Cortex.get_marginal(Cortex.get_variable(inference_engine, variable_id_2)) isa Cortex.Signal
    @test Cortex.get_marginal(Cortex.get_variable(inference_engine, variable_id_3)) isa Cortex.Signal

    # We check that the marginal of the variable is the same as the one returned from the inference engine's backend
    @test Cortex.get_marginal(inference_engine, variable_id_1) ===
        Cortex.get_marginal(Cortex.get_variable(inference_engine, variable_id_1))
    @test Cortex.get_marginal(inference_engine, variable_id_2) ===
        Cortex.get_marginal(Cortex.get_variable(inference_engine, variable_id_2))
    @test Cortex.get_marginal(inference_engine, variable_id_3) ===
        Cortex.get_marginal(Cortex.get_variable(inference_engine, variable_id_3))

    # Here we check that the factor data structure returned from the inference engine's backend is correct
    factor_id_1 = add_factor!(graph, Factor(:f1))
    factor_id_2 = add_factor!(graph, Factor(:f2))

    # We check that the factor data structure returned from the inference engine's backend is correct
    @test Cortex.get_factor(inference_engine, factor_id_1).fform === :f1
    @test Cortex.get_factor(inference_engine, factor_id_2).fform === :f2

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
end

@testitem "An empty inference round should be created for an empty model that has no pending messages" setup = [
    InferenceUtils
] begin
    using .InferenceUtils
    using JET

    @testset let graph = BipartiteFactorGraph()
        f1 = add_factor!(graph, Factor(:left))
        f2 = add_factor!(graph, Factor(:right))
        vc = add_variable!(graph, Variable(:center))

        add_edge!(graph, vc, f1, Connection(:param))
        add_edge!(graph, vc, f2, Connection(:param))

        inference_engine = Cortex.InferenceEngine(model_backend = graph)

        inference_task = Cortex.create_inference_task(inference_engine, vc)
        inference_steps = Cortex.scan_inference_task(inference_task)

        @test length(inference_steps) == 0
    end
end

@testitem "A non-empty inference round should be created for a model that has pending messages" setup = [InferenceUtils] begin
    using .InferenceUtils
    using JET

    function make_small_node_variable_node_model()
        graph = BipartiteFactorGraph()

        f1 = add_factor!(graph, Factor(:left))
        f2 = add_factor!(graph, Factor(:right))
        vc = add_variable!(graph, Variable(:center))

        add_edge!(graph, vc, f1, Connection(:param))
        add_edge!(graph, vc, f2, Connection(:param))

        inference_engine = Cortex.InferenceEngine(model_backend = graph)

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

        inference_task = Cortex.create_inference_task(inference_engine, vc)
        inference_steps = Cortex.scan_inference_task(inference_task)

        @test length(inference_steps) == 1
        @test inference_steps[1] == Cortex.get_message_to_variable(inference_engine, vc, f1)
    end

    # f2 -> vc is pending, should be in the inference round
    @testset let (inference_engine, f1, f2, vc, left, right) = make_small_node_variable_node_model()
        Cortex.set_value!(right, 1.0)

        inference_task = Cortex.create_inference_task(inference_engine, vc)
        inference_steps = Cortex.scan_inference_task(inference_task)

        @test length(inference_steps) == 1
        @test inference_steps[1] == Cortex.get_message_to_variable(inference_engine, vc, f2)
    end

    # f1 -> vc and f2 -> vc are pending, should be in the inference round
    @testset let (inference_engine, f1, f2, vc, left, right) = make_small_node_variable_node_model()
        Cortex.set_value!(left, 1.0)
        Cortex.set_value!(right, 1.0)

        inference_task = Cortex.create_inference_task(inference_engine, vc)
        inference_steps = Cortex.scan_inference_task(inference_task)

        @test length(inference_steps) == 2
        @test inference_steps[1] == Cortex.get_message_to_variable(inference_engine, vc, f1)
        @test inference_steps[2] == Cortex.get_message_to_variable(inference_engine, vc, f2)
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
            v, f = signal.metadata

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

            x = findfirst(d -> first(d.metadata) == :x, dependencies)
            y = findfirst(d -> first(d.metadata) == :y, dependencies)
            ssnoise = findfirst(d -> first(d.metadata) == :ssnoise, dependencies)
            obsnoise = findfirst(d -> first(d.metadata) == :obsnoise, dependencies)

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

            if filter(d -> first(d.metadata) == :x, dependencies) |> collect |> length == 2
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
