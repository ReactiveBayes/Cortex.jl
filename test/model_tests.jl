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
        get_edge_message_to_node

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
        :get_edge_message_to_variable, IncorrectlyImplementedCortexModel(), (1 => 2,)
    ) get_edge_message_to_variable(IncorrectlyImplementedCortexModel(), 1 => 2)

    @test_throws CortexModelInterfaceNotImplementedError(
        :get_edge_message_to_node, IncorrectlyImplementedCortexModel(), (1 => 2,)
    ) get_edge_message_to_node(IncorrectlyImplementedCortexModel(), 1 => 2)
end

@testmodule ModelUtils begin
    import BipartiteFactorGraphs, Cortex
    import Cortex: Value

    export Variable, Factor, Edge, Model
    export make_empty_model

    struct Variable
        name::String
        index::Any
        marginal::Value

        Variable(name, index...) = new(name, index, Value())
    end

    struct Factor
        type::Any
    end

    struct Edge
        message_to_variable::Value
        message_to_node::Value

        Edge() = new(Value(), Value())
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

    function Cortex.get_edge_message_to_node(model::Model, vi, fi)
        e = BipartiteFactorGraphs.get_edge_data(model.graph, vi, fi)
        return e.message_to_node
    end
    
end

@testitem "ModelUtils: The `Model` function should return an empty model" setup=[ModelUtils] begin
    using BipartiteFactorGraphs
    using .ModelUtils

    @testset let model = Model()
        @test length(variables(model.graph)) == 0
        @test length(factors(model.graph)) == 0
        @test length(edges(model.graph)) == 0
    end
end

@testitem "ModelUtils: It should be possible to add variables, nodes and edges to the model" setup=[ModelUtils] begin
    using BipartiteFactorGraphs
    using .ModelUtils

    @testset let model = Model()
        v = add_variable!(model.graph, Variable("x"))
        f = add_factor!(model.graph, Factor(identity))
        e = add_edge!(model.graph, v, f, Edge())

        @test length(variables(model.graph)) == 1
        @test length(factors(model.graph)) == 1
        @test length(edges(model.graph)) == 1

        @test neighbors(model.graph, v) == [f]
        @test neighbors(model.graph, f) == [v]
    end
end

@testitem "The test model should properly implement the Cortex model interface" setup=[ModelUtils] begin
    using BipartiteFactorGraphs
    using .ModelUtils

    @testset let model = Model()
        v = add_variable!(model.graph, Variable("x", 1))
        f = add_factor!(model.graph, Factor(identity))
        
        add_edge!(model.graph, v, f, Edge())

        @test Cortex.get_variable_display_name(model, v) == "x[1]"
        @test Cortex.get_factor_display_name(model, f) == "Factor(identity)"
        @test Cortex.get_edge_display_name(model, v, f) == "Edge(x[1] --- Factor(identity))"

        @test Cortex.get_variable_marginal(model, v) isa Cortex.Value
        @test_broken Cortex.get_factor_local_marginal(model, f) isa Cortex.Value
        @test Cortex.get_edge_message_to_variable(model, v, f) isa Cortex.Value
        @test Cortex.get_edge_message_to_node(model, v, f) isa Cortex.Value
    end
end