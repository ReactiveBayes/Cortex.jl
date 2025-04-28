
@testmodule GraphUtils begin
    import Cortex
    import Cortex: AbstractVariable, Value, get_name, get_index, get_display_name, get_marginal

    export Variable

    struct Variable <: AbstractVariable
        name::Symbol
        index::Any
        marginal::Value

        Variable(name::Symbol, index::Any = nothing) = new(name, index, Value())
    end

    # Required by the `AbstractVariable` interface
    function Cortex.get_name(v::Variable)
        return v.name
    end

    # Required by the `AbstractVariable` interface
    function Cortex.get_index(v::Variable)
        return v.index
    end

    # Required by the `AbstractVariable` interface
    function Cortex.get_display_name(v::Variable)
        return isnothing(v.index) ? string(v.name) : string(v.name, "[", join(v.index, ", "), "]")
    end

    # Required by the `AbstractVariable` interface
    function Cortex.get_marginal(v::Variable)
        return v.marginal
    end
end

@testitem "`IncorrectVariableImplementation` should have a readable error message" begin
    import Cortex: AbstractVariable, InterfaceNotImplementedError

    @test_throws "An object of type `String` does not implement the method `keys`, which is required by the interface of `AbstractDict`." throw(
        InterfaceNotImplementedError("oops", AbstractDict, :keys)
    )
    @test_throws "An object of type `Vector{Any}` does not implement the method `pairs`, which is required by the interface of `AbstractDict`." throw(
        InterfaceNotImplementedError([], AbstractDict, :pairs)
    )
    @test_throws "An object of type `Dict{Any, Any}` does not implement the method `occursin`, which is required by the interface of `AbstractString`." throw(
        InterfaceNotImplementedError(Dict{Any, Any}(), AbstractString, :occursin)
    )
end

@testitem "An incorrect implementation of AbstractVariable should throw an error on required methods" begin
    import Cortex: AbstractVariable, InterfaceNotImplementedError, get_name, get_index, get_display_name, get_marginal

    # No methods implemented
    struct IncorrectVariableImplementation <: AbstractVariable end

    @test_throws InterfaceNotImplementedError get_name(IncorrectVariableImplementation())
    @test_throws InterfaceNotImplementedError get_index(IncorrectVariableImplementation())
    @test_throws InterfaceNotImplementedError get_display_name(IncorrectVariableImplementation())
    @test_throws InterfaceNotImplementedError get_marginal(IncorrectVariableImplementation())
end

@testitem "Check correctness of `Variable` implementation of `AbstractVariable` from `GraphUtils`" setup = [GraphUtils] begin
    using .GraphUtils

    import Cortex: Value, get_name, get_index, get_display_name, get_marginal

    @testset let v = Variable(:x)
        @test get_name(v) == :x
        @test get_index(v) === nothing
        @test get_display_name(v) == "x"
        @test get_marginal(v) isa Value
    end

    @testset let v = Variable(:x, 1)
        @test get_name(v) == :x
        @test get_index(v) === 1
        @test get_display_name(v) == "x[1]"
        @test get_marginal(v) isa Value
    end

    @testset let v = Variable(:x, (1, 2, 3))
        @test get_name(v) == :x
        @test get_index(v) === (1, 2, 3)
        @test get_display_name(v) == "x[1, 2, 3]"
        @test get_marginal(v) isa Value
    end
end