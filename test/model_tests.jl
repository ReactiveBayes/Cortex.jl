@testitem "`CortexModelInterfaceNotImplementedError` should have a readable error message" begin
    import Cortex: CortexModelInterfaceNotImplementedError

    @test_throws "The method `get_factor_display_name` is not implemented for the model object of type `String`. The arguments passed to the method were: 1 (Int64)" throw(
        CortexModelInterfaceNotImplementedError(:get_factor_display_name, "String", (1,))
    )

    @test_throws "The method `get_variable_display_name` is not implemented for the model object of type `String`. The arguments passed to the method were: x (String)" throw(
        CortexModelInterfaceNotImplementedError(:get_variable_display_name, "String", ("x",))
    )
end

@testitem "The functions required by the Cortex model interface should throw a `CortexModelInterfaceNotImplementedError` if not implemented" begin
    import Cortex:
        CortexModelInterfaceNotImplementedError,
        get_factor_display_name,
        get_variable_display_name,
        get_edge_display_name,
        get_variable_marginal,
        get_factor_local_marginal,
        get_edge_message_to_variable,
        get_edge_message_to_factor

    struct IncorrectlyImplementedCortexModel end

    @test_throws CortexModelInterfaceNotImplementedError(
        :get_factor_display_name, IncorrectlyImplementedCortexModel(), (1,)
    ) get_factor_display_name(IncorrectlyImplementedCortexModel(), 1)

    @test_throws CortexModelInterfaceNotImplementedError(
        :get_variable_display_name, IncorrectlyImplementedCortexModel(), ("x",)
    ) get_variable_display_name(IncorrectlyImplementedCortexModel(), "x")

    @test_throws CortexModelInterfaceNotImplementedError(
        :get_edge_display_name, IncorrectlyImplementedCortexModel(), (1, 2)
    ) get_edge_display_name(IncorrectlyImplementedCortexModel(), 1, 2)

    @test_throws CortexModelInterfaceNotImplementedError(
        :get_variable_marginal, IncorrectlyImplementedCortexModel(), ("x",)
    ) get_variable_marginal(IncorrectlyImplementedCortexModel(), "x")

    @test_throws CortexModelInterfaceNotImplementedError(
        :get_factor_local_marginal, IncorrectlyImplementedCortexModel(), (1,)
    ) get_factor_local_marginal(IncorrectlyImplementedCortexModel(), 1)

    @test_throws CortexModelInterfaceNotImplementedError(
        :get_edge_message_to_variable, IncorrectlyImplementedCortexModel(), (1, 2)
    ) get_edge_message_to_variable(IncorrectlyImplementedCortexModel(), 1, 2)

    @test_throws CortexModelInterfaceNotImplementedError(
        :get_edge_message_to_factor, IncorrectlyImplementedCortexModel(), (1, 2)
    ) get_edge_message_to_factor(IncorrectlyImplementedCortexModel(), 1, 2)
end

@testmodule ModelUtils begin
    using Reexport

    import Cortex
    import Cortex: Value, Signal

    export Variable, Factor, Edge, Model
    export make_empty_model

    @reexport using BipartiteFactorGraphs

    struct Variable
        name::Any
        index::Any
        marginal::Signal

        Variable(name, index...) = new(name, index, Signal(type = Cortex.InferenceSignalTypes.IndividualMarginal))
    end

    struct Factor
        type::Any
    end

    struct Edge
        message_to_variable::Signal
        message_to_factor::Signal

        function Edge(vi, f)
            message_to_variable = Signal(type = Cortex.InferenceSignalTypes.MessageToVariable, metadata = (vi, f))
            message_to_factor = Signal(type = Cortex.InferenceSignalTypes.MessageToFactor, metadata = (vi, f))
            return new(message_to_variable, message_to_factor)
        end
    end

    struct Model{G}
        graph::G
    end

    Model() = Model(BipartiteFactorGraphs.BipartiteFactorGraph(Variable, Factor, Edge))

    function Cortex.get_variable_display_name(model::Model, vi)
        v = BipartiteFactorGraphs.get_variable_data(model.graph, vi)
        if isnothing(v.index) || isempty(v.index)
            return v.name
        else
            return string(v.name, "[", join(v.index, ","), "]")
        end
    end

    function Cortex.get_factor_display_name(model::Model, fi)
        f = BipartiteFactorGraphs.get_factor_data(model.graph, fi)
        return "Factor(" * string(f.type) * ")"
    end

    function Cortex.get_edge_display_name(model::Model, vi, fi)
        v = Cortex.get_variable_display_name(model, vi)
        f = Cortex.get_factor_display_name(model, fi)
        return string("Edge(", v, " --- ", f, ")")
    end

    function Cortex.get_variable_marginal(model::Model, vi)
        v = BipartiteFactorGraphs.get_variable_data(model.graph, vi)
        return v.marginal
    end

    function Cortex.get_factor_local_marginal(model::Model, fi)
        error("Not implemented")
    end

    function Cortex.get_edge_message_to_variable(model::Model, vi, fi)
        e = BipartiteFactorGraphs.get_edge_data(model.graph, vi, fi)
        return e.message_to_variable
    end

    function Cortex.get_edge_message_to_factor(model::Model, vi, fi)
        e = BipartiteFactorGraphs.get_edge_data(model.graph, vi, fi)
        return e.message_to_factor
    end

    function Cortex.get_factor_neighbors(model::Model, fi)
        return BipartiteFactorGraphs.neighbors(model.graph, fi)
    end

    function Cortex.get_variable_neighbors(model::Model, vi)
        return BipartiteFactorGraphs.neighbors(model.graph, vi)
    end

    export BeliefPropagation
    export resolve_dependencies!

    struct BeliefPropagation end

    function resolve_dependencies!(model::Model, ::BeliefPropagation)
        # For each variable
        for vi in variables(model.graph)
            for fi in neighbors(model.graph, vi)
                # for a marginal of a variable, we add a dependency on the message to the variable from each of its neighbors
                Cortex.add_dependency!(
                    Cortex.get_variable_marginal(model, vi), Cortex.get_edge_message_to_variable(model, vi, fi)
                )

                # And for each individual edge, we add a dependency on the message from the factor to the variable
                for e_fi in neighbors(model.graph, vi)
                    if fi !== e_fi
                        Cortex.add_dependency!(
                            Cortex.get_edge_message_to_factor(model, vi, fi),
                            Cortex.get_edge_message_to_variable(model, vi, e_fi)
                        )
                    end
                end
            end
        end

        # For each factor, we add a dependency on the inbound messages from its neighbors (excluding self-references)
        for fi in factors(model.graph)
            for vi in neighbors(model.graph, fi)
                for e_vi in neighbors(model.graph, fi)
                    if vi !== e_vi
                        Cortex.add_dependency!(
                            Cortex.get_edge_message_to_variable(model, vi, fi),
                            Cortex.get_edge_message_to_factor(model, e_vi, fi)
                        )
                    end
                end
            end
        end
    end
end

@testitem "ModelUtils: The `Model` function should return an empty model" setup = [ModelUtils] begin
    using BipartiteFactorGraphs
    using .ModelUtils

    @testset let model = Model()
        @test length(variables(model.graph)) == 0
        @test length(factors(model.graph)) == 0
        @test length(edges(model.graph)) == 0
    end
end

@testitem "ModelUtils: It should be possible to add variables, nodes and edges to the model" setup = [ModelUtils] begin
    using BipartiteFactorGraphs
    using .ModelUtils

    @testset let model = Model()
        v = add_variable!(model.graph, Variable("x"))
        f = add_factor!(model.graph, Factor(identity))
        e = add_edge!(model.graph, v, f, Edge(v, f))

        @test length(variables(model.graph)) == 1
        @test length(factors(model.graph)) == 1
        @test length(edges(model.graph)) == 1

        @test neighbors(model.graph, v) == [f]
        @test neighbors(model.graph, f) == [v]
    end
end

@testitem "The test model should properly implement the Cortex model interface" setup = [ModelUtils] begin
    using BipartiteFactorGraphs
    using .ModelUtils

    @testset let model = Model()
        v = add_variable!(model.graph, Variable("x", 1))
        f = add_factor!(model.graph, Factor(identity))

        add_edge!(model.graph, v, f, Edge(v, f))

        @test Cortex.get_variable_display_name(model, v) == "x[1]"
        @test Cortex.get_factor_display_name(model, f) == "Factor(identity)"
        @test Cortex.get_edge_display_name(model, v, f) == "Edge(x[1] --- Factor(identity))"

        @test Cortex.get_variable_marginal(model, v) isa Cortex.Signal
        @test_broken Cortex.get_factor_local_marginal(model, f) isa Cortex.Signal
        @test Cortex.get_edge_message_to_variable(model, v, f) isa Cortex.Signal
        @test Cortex.get_edge_message_to_factor(model, v, f) isa Cortex.Signal

        @test Cortex.get_variable_neighbors(model, v) == [f]
        @test Cortex.get_factor_neighbors(model, f) == [v]
    end
end

@testitem "The BeliefPropagation algorithm should properly resolve dependencies #1" setup = [ModelUtils] begin
    using BipartiteFactorGraphs
    using .ModelUtils

    model = Model()

    v1 = add_variable!(model.graph, Variable(:v1))
    v2 = add_variable!(model.graph, Variable(:v2))
    v3 = add_variable!(model.graph, Variable(:v3))

    f1 = add_factor!(model.graph, Factor(:f1))
    f2 = add_factor!(model.graph, Factor(:f2))

    add_edge!(model.graph, v1, f1, Edge(v1, f1))
    add_edge!(model.graph, v2, f1, Edge(v2, f1))
    add_edge!(model.graph, v2, f2, Edge(v2, f2))
    add_edge!(model.graph, v3, f2, Edge(v3, f2))

    resolve_dependencies!(model, BeliefPropagation())

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
