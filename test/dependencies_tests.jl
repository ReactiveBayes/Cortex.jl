@testitem "resolve_dependencies! must resolve all variables and factors in the model" setup = [TestUtils] begin
    using .TestUtils

    struct CustomDependencyResolver <: Cortex.AbstractDependencyResolver
        resolved_factors::Set{Any}
        resolved_variables::Set{Any}

        CustomDependencyResolver() = new(Set{Any}(), Set{Any}())
    end

    function Cortex.resolve_variable_dependencies!(
        ::CustomDependencyResolver, engine::Cortex.InferenceEngine, variable_id
    )
        push!(resolver.resolved_variables, variable_id)
    end

    function Cortex.resolve_factor_dependencies!(::CustomDependencyResolver, engine::Cortex.InferenceEngine, factor_id)
        push!(resolver.resolved_factors, factor_id)
    end

    graph = BipartiteFactorGraph()

    x = add_variable!(graph, Variable(:x))
    y = add_variable!(graph, Variable(:y))
    z = add_variable!(graph, Variable(:z))

    f1 = add_factor!(graph, Factor(:f1))
    f2 = add_factor!(graph, Factor(:f2))

    engine = Cortex.InferenceEngine(model_backend = graph)
    resolver = CustomDependencyResolver()

    Cortex.resolve_dependencies!(resolver, engine)

    @test resolver.resolved_variables == Set([x, y, z])
    @test resolver.resolved_factors == Set([f1, f2])
end

@testitem "The default dependency resolution algorithm should properly resolve dependencies #1" setup = [TestUtils] begin
    using BipartiteFactorGraphs
    using .TestUtils

    graph = BipartiteFactorGraph()

    v1 = add_variable!(graph, Variable(:v1))
    v2 = add_variable!(graph, Variable(:v2))
    v3 = add_variable!(graph, Variable(:v3))

    f1 = add_factor!(graph, Factor(:f1))
    f2 = add_factor!(graph, Factor(:f2))

    add_edge!(graph, v1, f1, Connection(:out))
    add_edge!(graph, v2, f1, Connection(:out))
    add_edge!(graph, v2, f2, Connection(:out))
    add_edge!(graph, v3, f2, Connection(:out))

    engine = Cortex.InferenceEngine(model_backend = graph)

    Cortex.resolve_dependencies!(Cortex.DefaultDependencyResolver(), engine)

    v1_marginal = Cortex.get_marginal(engine, v1)
    v1_marginal_deps = Cortex.get_dependencies(v1_marginal)
    @test length(v1_marginal_deps) == 1
    @test any(d -> d === Cortex.get_message_to_variable(engine, v1, f1), v1_marginal_deps)

    v2_marginal = Cortex.get_marginal(engine, v2)
    v2_marginal_deps = Cortex.get_dependencies(v2_marginal)
    @test length(v2_marginal_deps) == 2
    @test any(d -> d === Cortex.get_message_to_variable(engine, v2, f1), v2_marginal_deps)
    @test any(d -> d === Cortex.get_message_to_variable(engine, v2, f2), v2_marginal_deps)

    v3_marginal = Cortex.get_marginal(engine, v3)
    v3_marginal_deps = Cortex.get_dependencies(v3_marginal)
    @test length(v3_marginal_deps) == 1
    @test any(d -> d === Cortex.get_message_to_variable(engine, v3, f2), v3_marginal_deps)

    message_from_f1_to_v2 = Cortex.get_message_to_variable(engine, v2, f1)
    message_from_f1_to_v2_deps = Cortex.get_dependencies(message_from_f1_to_v2)
    @test length(message_from_f1_to_v2_deps) == 1
    @test any(d -> d === Cortex.get_message_to_factor(engine, v1, f1), message_from_f1_to_v2_deps)

    message_from_f2_to_v2 = Cortex.get_message_to_variable(engine, v2, f2)
    message_from_f2_to_v2_deps = Cortex.get_dependencies(message_from_f2_to_v2)
    @test length(message_from_f2_to_v2_deps) == 1
    @test any(d -> d === Cortex.get_message_to_factor(engine, v3, f2), message_from_f2_to_v2_deps)

    message_from_v2_to_f1 = Cortex.get_message_to_factor(engine, v2, f1)
    message_from_v2_to_f1_deps = Cortex.get_dependencies(message_from_v2_to_f1)
    @test length(message_from_v2_to_f1_deps) == 1
    @test any(d -> d === Cortex.get_message_to_variable(engine, v2, f2), message_from_v2_to_f1_deps)

    message_from_v2_to_f2 = Cortex.get_message_to_factor(engine, v2, f2)
    message_from_v2_to_f2_deps = Cortex.get_dependencies(message_from_v2_to_f2)
    @test length(message_from_v2_to_f2_deps) == 1
    @test any(d -> d === Cortex.get_message_to_variable(engine, v2, f1), message_from_v2_to_f2_deps)
end