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

@testitem "It should not be possible to create an inference engine for an unsupported model backend" begin
    import Cortex: UnsupportedModelBackendError

    @test_throws UnsupportedModelBackendError(1) Cortex.InferenceEngine(model_backend = 1)
    @test_throws UnsupportedModelBackendError("string") Cortex.InferenceEngine(model_backend = "string")

    @test_throws "The model backend of type `Int64` is not supported." Cortex.InferenceEngine(model_backend = 1)
    @test_throws "The model backend of type `String` is not supported." Cortex.InferenceEngine(model_backend = "string")

    # Test with a custom, unsupported struct type
    struct MyDummyUnsupportedBackend end

    dummy_backend = MyDummyUnsupportedBackend()
    @test_throws UnsupportedModelBackendError(dummy_backend) Cortex.InferenceEngine(model_backend = dummy_backend)
end
