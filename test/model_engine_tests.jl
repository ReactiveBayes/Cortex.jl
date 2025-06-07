@testitem "It should be possible to create a variable" begin
    import Cortex: Variable, get_variable_name, get_variable_index, get_variable_marginal, get_variable_linked_signals

    for name in [:v, :v1, :v2, :v3]
        v = Variable(name = name)

        @test get_variable_name(v) == name
        @test get_variable_index(v) isa Nothing
        @test get_variable_marginal(v) isa Cortex.Signal
        @test get_variable_linked_signals(v) isa Vector{Cortex.Signal}
    end

    for index in [1, 2, 3]
        v = Variable(name = :v, index = index)

        @test get_variable_name(v) == :v
        @test get_variable_index(v) == index
        @test get_variable_marginal(v) isa Cortex.Signal
        @test get_variable_linked_signals(v) isa Vector{Cortex.Signal}
    end
end

@testitem "Linked signals should be empty by default" begin
    import Cortex: Variable, get_variable_linked_signals

    v = Variable(name = :v)

    @test isempty(get_variable_linked_signals(v))
end

@testitem "It should be possible to create a variable with a marginal" begin
    import Cortex: Variable, get_variable_marginal

    external_signal = Cortex.Signal()

    v = Variable(name = :v, marginal = external_signal)

    @test get_variable_marginal(v) === external_signal
end

@testitem "It should be possible to link signals" begin
    import Cortex: Variable, get_variable_linked_signals, link_signal_to_variable!

    v1 = Variable(name = :v1)

    some_other_signal = Cortex.Signal()

    link_signal_to_variable!(v1, some_other_signal)

    @test !isempty(get_variable_linked_signals(v1))
    @test some_other_signal in get_variable_linked_signals(v1)
end

@testitem "It should be possible to create a factor" begin
    import Cortex: Factor, get_factor_functional_form, get_factor_local_marginals

    for functional_form in [:f, :g, :h]
        f = Factor(functional_form = functional_form)

        @test get_factor_functional_form(f) == functional_form
        @test get_factor_local_marginals(f) isa Vector{Cortex.Signal}
    end
end

@testitem "Local marginals of a factor should be empty by default" begin
    import Cortex: Factor, get_factor_local_marginals

    f = Factor(functional_form = :f)

    @test isempty(get_factor_local_marginals(f))
end

@testitem "It should be possible to add a local marginal to a factor" begin
    import Cortex: Factor, get_factor_local_marginals, add_local_marginal_to_factor!

    f = Factor(functional_form = :f)

    local_marginal = Cortex.Signal()

    add_local_marginal_to_factor!(f, local_marginal)

    @test !isempty(get_factor_local_marginals(f))
    @test local_marginal in get_factor_local_marginals(f)
end

@testitem "It should be possible to create a connection" begin
    import Cortex:
        Connection,
        get_connection_label,
        get_connection_index,
        get_connection_message_to_variable,
        get_connection_message_to_factor

    for label in [:c, :d, :e]
        for index in [1, 2, 3]
            c = Connection(label = label, index = index)

            @test get_connection_label(c) == label
            @test get_connection_index(c) == index
            @test get_connection_message_to_variable(c) isa Cortex.Signal
            @test get_connection_message_to_factor(c) isa Cortex.Signal
        end
    end
end

@testitem "Default index of a connection should be 0" begin
    import Cortex: Connection, get_connection_index

    c = Connection(label = :c)

    @test get_connection_index(c) == 0
end

@testitem "`UnsupportedModelEngineError` should have a human readable message" begin
    import Cortex: UnsupportedModelEngineError
    import Base: showerror

    @test sprint(showerror, UnsupportedModelEngineError(1, nothing)) ==
        "The model engine of type `Int64` is not supported."

    @test sprint(showerror, UnsupportedModelEngineError(1, Cortex.get_variable_data)) ==
        "The model engine of type `Int64` does not implement the function `get_variable_data`."

    @test sprint(showerror, UnsupportedModelEngineError(1, Cortex.get_factor)) ==
        "The model engine of type `Int64` does not implement the function `get_factor`."
end

@testitem "It should not be possible to create an inference engine for an unsupported model backend" begin
    import Cortex: UnsupportedModelEngineError

    @test_throws UnsupportedModelEngineError(1, nothing) Cortex.InferenceEngine(model_engine = 1)
    @test_throws UnsupportedModelEngineError("string", nothing) Cortex.InferenceEngine(model_engine = "string")

    @test_throws "The model engine of type `Int64` is not supported." Cortex.InferenceEngine(model_engine = 1)
    @test_throws "The model engine of type `String` is not supported." Cortex.InferenceEngine(model_engine = "string")

    # Test with a custom, unsupported struct type
    struct MyDummyUnsupportedEngine end

    dummy_engine = MyDummyUnsupportedEngine()
    @test_throws UnsupportedModelEngineError(dummy_engine, nothing) Cortex.InferenceEngine(model_engine = dummy_engine)
end

@testitem "An engine that does not implement interface methods should throw an error" begin
    import Cortex: UnsupportedModelEngineError

    struct UnsupportedEngineThatDoesNotImplementInterfaceMethods end

    dummy_engine = UnsupportedEngineThatDoesNotImplementInterfaceMethods()
    @test_throws UnsupportedModelEngineError(dummy_engine, Cortex.get_variable_data) Cortex.get_variable_data(
        dummy_engine, 1
    )

    @test_throws UnsupportedModelEngineError(dummy_engine, Cortex.get_factor) Cortex.get_factor(dummy_engine, 1)

    @test_throws UnsupportedModelEngineError(dummy_engine, Cortex.get_variable_ids) Cortex.get_variable_ids(
        dummy_engine
    )
    @test_throws UnsupportedModelEngineError(dummy_engine, Cortex.get_factor_ids) Cortex.get_factor_ids(dummy_engine)

    @test_throws UnsupportedModelEngineError(dummy_engine, Cortex.get_connection) Cortex.get_connection(
        dummy_engine, 1, 1
    )

    @test_throws UnsupportedModelEngineError(dummy_engine, Cortex.get_connected_variable_ids) Cortex.get_connected_variable_ids(
        dummy_engine, 1
    )
    @test_throws UnsupportedModelEngineError(dummy_engine, Cortex.get_connected_factor_ids) Cortex.get_connected_factor_ids(
        dummy_engine, 1
    )
end
