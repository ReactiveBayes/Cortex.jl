
@testmodule GraphUtils begin
    import Cortex
    import Cortex: AbstractVariable, Value, getname, getindex, getdisplayname, getmarginal

    export Variable

    struct Variable <: AbstractVariable
        name::Symbol
        index::Any
        marginal::Value

        Variable(name::Symbol, index::Any = nothing) = new(name, index, Value())
    end

    Cortex.getname(v::Variable) = v.name
    Cortex.getindex(v::Variable) = v.index
    Cortex.getdisplayname(v::Variable) =
        isnothing(v.index) ? string(v.name) : string(v.name, "[", join(v.index, ", "), "]")
    Cortex.getmarginal(v::Variable) = v.marginal
end

@testitem "`IncorrectVariableImplementation` should have a readable error message" begin
    import Cortex: AbstractVariable, InterfaceNotImplementedError, getname, getindex, getdisplayname, getmarginal

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
    import Cortex: AbstractVariable, InterfaceNotImplementedError, getname, getindex, getdisplayname, getmarginal

    # No methods implemented
    struct IncorrectVariableImplementation <: AbstractVariable end

    @test_throws InterfaceNotImplementedError getname(IncorrectVariableImplementation())
    @test_throws InterfaceNotImplementedError getindex(IncorrectVariableImplementation())
    @test_throws InterfaceNotImplementedError getdisplayname(IncorrectVariableImplementation())
    @test_throws InterfaceNotImplementedError getmarginal(IncorrectVariableImplementation())
end

@testitem "Variable implementation of `AbstractVariable` from `GraphUtils`" setup = [GraphUtils] begin
    using .GraphUtils

    import Cortex: Value, getname, getindex, getdisplayname, getmarginal

    v = Variable(:x, 1)
    @test getname(v) == :x
    @test getindex(v) == 1
    @test getdisplayname(v) == "x[1]"
    @test getmarginal(v) isa Value
end

@testitem "VariableData show method" begin
    import Cortex: VariableData

    @test repr(VariableData()) == "VariableData(marginal=Value(#undef, pending=false, computed=false))"
end