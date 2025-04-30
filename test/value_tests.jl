@testitem "Value can be created" begin
    import Cortex: Value, is_computed, is_pending

    @testset "An empty Value can be created" begin
        value = Value()
        @test !is_computed(value)
        @test !is_pending(value)
    end

    @testset "A Value can be created with a scalar" begin
        value = Value(1)
        @test is_computed(value)
        @test !is_pending(value)
    end

    @testset "A Value can be created with a vector" begin
        value = Value([1, 2, 3])
        @test is_computed(value)
        @test !is_pending(value)
    end
end

@testitem "Operations with the Value must be type-stable" begin
    import Cortex: Value, is_computed, is_pending, set_value!
    import JET

    @test @inferred(Value()) isa Value
    @test @inferred(Value(1)) isa Value
    @test @inferred(Value([1, 2, 3])) isa Value

    JET.@test_opt Value()
    JET.@test_opt Value(1)
    JET.@test_opt Value([1, 2, 3])

    @test @inferred(!is_computed(Value()))
    @test @inferred(is_computed(Value(1)))
    @test @inferred(is_computed(Value([1, 2, 3])))

    JET.@test_opt is_computed(Value())
    JET.@test_opt is_computed(Value(1))
    JET.@test_opt is_computed(Value([1, 2, 3]))

    @test @inferred(!is_pending(Value()))
    @test @inferred(!is_pending(Value(1)))
    @test @inferred(!is_pending(Value([1, 2, 3])))

    JET.@test_opt is_pending(Value())
    JET.@test_opt is_pending(Value(1))
    JET.@test_opt is_pending(Value([1, 2, 3]))

    @test @inferred(set_value!(Value(), 1)) isa Value
    @test @inferred(set_value!(Value(1), [ 4, 5, 6 ])) isa Value
    @test @inferred(set_value!(Value([1, 2, 3]), 2)) isa Value

    JET.@test_opt set_value!(Value(), 1)
    JET.@test_opt set_value!(Value(1), 2)
    JET.@test_opt set_value!(Value([1, 2, 3]), [4, 5, 6])
    JET.@test_opt set_value!(Value(1), [ 1, 2 ])
    JET.@test_opt set_value!(Value([1, 2, 3]), 2)
end

@testitem "Value can be updated" begin
    import Cortex: Value, is_computed, is_pending, set_value!

    value = Value()
    @test !is_computed(value)
    @test !is_pending(value)
    set_value!(value, 1)
    @test is_computed(value)
    @test !is_pending(value)
end

@testitem "Value can be set to pending" begin
    import Cortex: Value, is_computed, is_pending, set_pending!, set_value!

    value = Value()
    @test !is_computed(value)
    @test !is_pending(value)

    set_pending!(value)
    @test !is_computed(value)
    @test is_pending(value)

    set_value!(value, 1)
    @test is_computed(value)
    @test !is_pending(value)
end

@testitem "The pending status of a Value can be unset" begin
    import Cortex: Value, is_computed, is_pending, set_pending!, unset_pending!

    value = Value()
    @test !is_computed(value)
    @test !is_pending(value)

    set_pending!(value)
    @test is_pending(value)

    unset_pending!(value)
    @test !is_pending(value)
end

@testitem "Value can be pretty-printed" begin
    import Cortex: Value, is_computed, is_pending

    @test repr(Value()) == "Value(#undef, pending=false, computed=false)"
    @test repr(Value(1)) == "Value(1, pending=false, computed=true)"
end