@testitem "resolve_dependencies! must resolve all variables and factors in the model" setup = [ModelUtils] begin
    import Cortex: add_variable_to_model!, add_factor_to_model!, add_edge_to_model!

    struct CustomDependencyResolver <: AbstractDependencyResolver
        resolved::Set{Any}
    end

    model = Model()

    x = add_variable_to_model!(model, :x)
    y = add_variable_to_model!(model, :y)
    z = add_variable_to_model!(model, :z)

    f1 = add_factor_to_model!(model, :f1)
    f2 = add_factor_to_model!(model, :f2)

    resolve_dependencies!(model)

    @test get_variable_dependencies(model, x) == [f1]

    return model
end

@testitem "The default dependency resolution algorithm should properly resolve dependencies #1" setup = [ModelUtils] begin
    using BipartiteFactorGraphs
    using .ModelUtils

    model = Model()

    v1 = add_variable_to_model!(model, :v1)
    v2 = add_variable_to_model!(model, :v2)
    v3 = add_variable_to_model!(model, :v3)

    f1 = add_factor_to_model!(model, :f1)
    f2 = add_factor_to_model!(model, :f2)

    add_edge_to_model!(model, v1, f1)
    add_edge_to_model!(model, v2, f1)
    add_edge_to_model!(model, v2, f2)
    add_edge_to_model!(model, v3, f2)

    Cortex.resolve_dependencies!(Cortex.DefaultDependencyResolver(), model)

    v1_marginal = Cortex.get_variable_marginal(model, v1)
    v1_marginal_deps = Cortex.get_dependencies(v1_marginal)
    @test length(v1_marginal_deps) == 1
    @test any(d -> d === Cortex.get_edge_message_to_variable(model, v1, f1), v1_marginal_deps)

    v2_marginal = Cortex.get_variable_marginal(model, v2)
    v2_marginal_deps = Cortex.get_dependencies(v2_marginal)
    @test length(v2_marginal_deps) == 2
    @test any(d -> d === Cortex.get_edge_message_to_variable(model, v2, f1), v2_marginal_deps)
    @test any(d -> d === Cortex.get_edge_message_to_variable(model, v2, f2), v2_marginal_deps)

    v3_marginal = Cortex.get_variable_marginal(model, v3)
    v3_marginal_deps = Cortex.get_dependencies(v3_marginal)
    @test length(v3_marginal_deps) == 1
    @test any(d -> d === Cortex.get_edge_message_to_variable(model, v3, f2), v3_marginal_deps)

    message_from_f1_to_v2 = Cortex.get_edge_message_to_variable(model, v2, f1)
    message_from_f1_to_v2_deps = Cortex.get_dependencies(message_from_f1_to_v2)
    @test length(message_from_f1_to_v2_deps) == 1
    @test any(d -> d === Cortex.get_edge_message_to_factor(model, v1, f1), message_from_f1_to_v2_deps)

    message_from_f2_to_v2 = Cortex.get_edge_message_to_variable(model, v2, f2)
    message_from_f2_to_v2_deps = Cortex.get_dependencies(message_from_f2_to_v2)
    @test length(message_from_f2_to_v2_deps) == 1
    @test any(d -> d === Cortex.get_edge_message_to_factor(model, v3, f2), message_from_f2_to_v2_deps)

    message_from_v2_to_f1 = Cortex.get_edge_message_to_factor(model, v2, f1)
    message_from_v2_to_f1_deps = Cortex.get_dependencies(message_from_v2_to_f1)
    @test length(message_from_v2_to_f1_deps) == 1
    @test any(d -> d === Cortex.get_edge_message_to_variable(model, v2, f2), message_from_v2_to_f1_deps)

    message_from_v2_to_f2 = Cortex.get_edge_message_to_factor(model, v2, f2)
    message_from_v2_to_f2_deps = Cortex.get_dependencies(message_from_v2_to_f2)
    @test length(message_from_v2_to_f2_deps) == 1
    @test any(d -> d === Cortex.get_edge_message_to_variable(model, v2, f1), message_from_v2_to_f2_deps)
end