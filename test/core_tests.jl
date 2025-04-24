@testitem "Value can be created" begin
    import Cortex: Value, iscomputed, ispending

    @testset "An empty Value can be created" begin
        value = Value()
        @test !iscomputed(value)
        @test !ispending(value)
    end

    @testset "A Value can be created with a scalar" begin
        value = Value(1)
        @test iscomputed(value)
        @test !ispending(value)
    end

    @testset "A Value can be created with a vector" begin
        value = Value([1, 2, 3])
        @test iscomputed(value)
        @test !ispending(value)
    end
end

@testitem "Value can be updated" begin
    import Cortex: Value, iscomputed, ispending, setvalue!

    value = Value()
    @test !iscomputed(value)
    @test !ispending(value)
    setvalue!(value, 1)
    @test iscomputed(value)
    @test !ispending(value)
end

@testitem "Value can be set to pending" begin
    import Cortex: Value, iscomputed, ispending, setpending!, setvalue!

    value = Value()
    @test !iscomputed(value)
    @test !ispending(value)

    setpending!(value)
    @test !iscomputed(value)
    @test ispending(value)

    setvalue!(value, 1)
    @test iscomputed(value)
    @test !ispending(value)
end

@testitem "Value can be pretty-printed" begin
    import Cortex: Value, iscomputed, ispending

    @test repr(Value()) == "Value(#undef, pending=false, computed=false)"
    @test repr(Value(1)) == "Value(1, pending=false, computed=true)"
end
