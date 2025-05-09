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
        AbstractCortexModel,
        VariableId,
        FactorId,
        EdgeId,
        add_factor_to_model!,
        add_variable_to_model!,
        add_edge_to_model!,
        get_factor_display_name,
        get_variable_display_name,
        get_edge_display_name,
        get_variable_marginal,
        get_edge_message_to_variable,
        get_edge_message_to_factor,
        get_factor_neighbors,
        get_variable_neighbors,
        get_variables,
        get_factors

    struct IncorrectlyImplementedCortexModel <: AbstractCortexModel end

    @test_throws CortexModelInterfaceNotImplementedError(
        :add_factor_to_model!, IncorrectlyImplementedCortexModel(), (identity,)
    ) add_factor_to_model!(IncorrectlyImplementedCortexModel(), identity)

    @test_throws CortexModelInterfaceNotImplementedError(
        :add_variable_to_model!, IncorrectlyImplementedCortexModel(), (:x, 1)
    ) add_variable_to_model!(IncorrectlyImplementedCortexModel(), :x, 1)

    @test_throws CortexModelInterfaceNotImplementedError(
        :add_edge_to_model!, IncorrectlyImplementedCortexModel(), (VariableId(1), FactorId(2))
    ) add_edge_to_model!(IncorrectlyImplementedCortexModel(), VariableId(1), FactorId(2))

    @test_throws CortexModelInterfaceNotImplementedError(
        :get_factor_display_name, IncorrectlyImplementedCortexModel(), (FactorId(1),)
    ) get_factor_display_name(IncorrectlyImplementedCortexModel(), FactorId(1))

    @test_throws CortexModelInterfaceNotImplementedError(
        :get_variable_display_name, IncorrectlyImplementedCortexModel(), (VariableId("x"),)
    ) get_variable_display_name(IncorrectlyImplementedCortexModel(), VariableId("x"))

    @test_throws CortexModelInterfaceNotImplementedError(
        :get_edge_display_name, IncorrectlyImplementedCortexModel(), (VariableId(1), FactorId(2))
    ) get_edge_display_name(IncorrectlyImplementedCortexModel(), VariableId(1), FactorId(2))

    @test_throws CortexModelInterfaceNotImplementedError(
        :get_variable_marginal, IncorrectlyImplementedCortexModel(), (VariableId(1),)
    ) get_variable_marginal(IncorrectlyImplementedCortexModel(), VariableId(1))

    @test_throws CortexModelInterfaceNotImplementedError(
        :get_edge_message_to_variable, IncorrectlyImplementedCortexModel(), (VariableId(1), FactorId(2))
    ) get_edge_message_to_variable(IncorrectlyImplementedCortexModel(), VariableId(1), FactorId(2))

    @test_throws CortexModelInterfaceNotImplementedError(
        :get_edge_message_to_factor, IncorrectlyImplementedCortexModel(), (VariableId(1), FactorId(2))
    ) get_edge_message_to_factor(IncorrectlyImplementedCortexModel(), VariableId(1), FactorId(2))

    @test_throws CortexModelInterfaceNotImplementedError(
        :get_factor_neighbors, IncorrectlyImplementedCortexModel(), (FactorId(1),)
    ) get_factor_neighbors(IncorrectlyImplementedCortexModel(), FactorId(1))

    @test_throws CortexModelInterfaceNotImplementedError(
        :get_variable_neighbors, IncorrectlyImplementedCortexModel(), (VariableId(1),)
    ) get_variable_neighbors(IncorrectlyImplementedCortexModel(), VariableId(1))

    @test_throws CortexModelInterfaceNotImplementedError(:get_variables, IncorrectlyImplementedCortexModel(), ()) get_variables(
        IncorrectlyImplementedCortexModel()
    )

    @test_throws CortexModelInterfaceNotImplementedError(:get_factors, IncorrectlyImplementedCortexModel(), ()) get_factors(
        IncorrectlyImplementedCortexModel()
    )
end

@testmodule ModelUtils begin
    using Reexport
    using MappedArrays

    import Cortex
    import Cortex:
        AbstractCortexModel,
        VariableId,
        FactorId,
        EdgeId,
        Signal,
        add_variable_to_model!,
        add_factor_to_model!,
        add_edge_to_model!

    export Variable, Factor, Edge, Model
    export make_empty_model, add_variable_to_model!, add_factor_to_model!, add_edge_to_model!

    @reexport using BipartiteFactorGraphs

    struct Model{G} <: AbstractCortexModel
        graph::G
    end

    struct Factor
        type::Any
    end

    function Cortex.add_factor_to_model!(model::Model, type::Any)
        return FactorId(BipartiteFactorGraphs.add_factor!(model.graph, Factor(type)))
    end

    struct Variable
        name::Any
        index::Any
        marginal::Signal

        Variable(name, index...) = new(
            name, index, Signal(type = Cortex.InferenceSignalTypes.IndividualMarginal, metadata = (name, index))
        )
    end

    function Cortex.add_variable_to_model!(model::Model, name::Any, index...)
        return VariableId(BipartiteFactorGraphs.add_variable!(model.graph, Variable(name, index...)))
    end

    struct Edge
        message_to_variable::Signal
        message_to_factor::Signal

        function Edge(v, f)
            message_to_variable = Signal(type = Cortex.InferenceSignalTypes.MessageToVariable, metadata = (v, f))
            message_to_factor = Signal(type = Cortex.InferenceSignalTypes.MessageToFactor, metadata = (v, f))
            return new(message_to_variable, message_to_factor)
        end
    end

    function Cortex.add_edge_to_model!(model::Model, v::VariableId, f::FactorId)
        BipartiteFactorGraphs.add_edge!(model.graph, v.id, f.id, Edge(v.id, f.id))
        return EdgeId(v, f)
    end

    Model() = Model(BipartiteFactorGraphs.BipartiteFactorGraph(Variable, Factor, Edge))

    function Cortex.get_variable_display_name(model::Model, v::VariableId)
        v = BipartiteFactorGraphs.get_variable_data(model.graph, v.id)
        if isnothing(v.index) || isempty(v.index)
            return v.name
        else
            return string(v.name, "[", join(v.index, ","), "]")
        end
    end

    function Cortex.get_factor_display_name(model::Model, f::FactorId)
        f = BipartiteFactorGraphs.get_factor_data(model.graph, f.id)
        return "Factor(" * string(f.type) * ")"
    end

    function Cortex.get_edge_display_name(model::Model, v::VariableId, f::FactorId)
        v = Cortex.get_variable_display_name(model, v)
        f = Cortex.get_factor_display_name(model, f)
        return string("Edge(", v, " --- ", f, ")")
    end

    function Cortex.get_variable_marginal(model::Model, v::VariableId)
        v = BipartiteFactorGraphs.get_variable_data(model.graph, v.id)
        return v.marginal
    end

    function Cortex.get_edge_message_to_variable(model::Model, v::VariableId, f::FactorId)
        e = BipartiteFactorGraphs.get_edge_data(model.graph, v.id, f.id)
        return e.message_to_variable
    end

    function Cortex.get_edge_message_to_factor(model::Model, v::VariableId, f::FactorId)
        e = BipartiteFactorGraphs.get_edge_data(model.graph, v.id, f.id)
        return e.message_to_factor
    end

    function Cortex.get_factor_neighbors(model::Model, f::FactorId)
        return Iterators.map(VariableId, BipartiteFactorGraphs.neighbors(model.graph, f.id))
    end

    function Cortex.get_variable_neighbors(model::Model, v::VariableId)
        return Iterators.map(FactorId, BipartiteFactorGraphs.neighbors(model.graph, v.id))
    end

    function Cortex.get_variables(model::Model)
        return Iterators.map(VariableId, BipartiteFactorGraphs.variables(model.graph))
    end

    function Cortex.get_factors(model::Model)
        return Iterators.map(FactorId, BipartiteFactorGraphs.factors(model.graph))
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
        v = add_variable_to_model!(model, "x")
        f = add_factor_to_model!(model, identity)
        e = add_edge_to_model!(model, v, f)

        @test length(variables(model.graph)) == 1
        @test length(factors(model.graph)) == 1
        @test length(edges(model.graph)) == 1

        @test Cortex.get_variable_neighbors(model, v) |> collect == [f]
        @test Cortex.get_factor_neighbors(model, f) |> collect == [v]
    end
end

@testitem "The test model should properly implement the Cortex model interface" setup = [ModelUtils] begin
    using BipartiteFactorGraphs
    using .ModelUtils

    @testset let model = Model()
        v = add_variable_to_model!(model, "x", 1)
        f = add_factor_to_model!(model, identity)

        add_edge_to_model!(model, v, f)

        @test Cortex.get_variable_display_name(model, v) == "x[1]"
        @test Cortex.get_factor_display_name(model, f) == "Factor(identity)"
        @test Cortex.get_edge_display_name(model, v, f) == "Edge(x[1] --- Factor(identity))"

        @test Cortex.get_variable_marginal(model, v) isa Cortex.Signal
        @test_broken Cortex.get_factor_local_marginal(model, f) isa Cortex.Signal
        @test Cortex.get_edge_message_to_variable(model, v, f) isa Cortex.Signal
        @test Cortex.get_edge_message_to_factor(model, v, f) isa Cortex.Signal

        @test Cortex.get_variable_neighbors(model, v) |> collect == [f]
        @test Cortex.get_factor_neighbors(model, f) |> collect == [v]

        @test Cortex.get_variables(model) |> collect == [v]
        @test Cortex.get_factors(model) |> collect == [f]
    end
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
