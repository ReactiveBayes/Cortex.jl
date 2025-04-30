using Cortex
using Test
using Aqua
using JET
using TestItemRunner

@testset "Cortex.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(Cortex)
    end

    @testset "Code linting (JET.jl)" begin
        JET.test_package(Cortex; target_defined_modules = true)
    end

    TestItemRunner.@run_package_tests()
end

@testitem "tmp" begin
    using JET
    using BenchmarkTools

    abstract type AT end

    struct A <: AT
        x::Int
    end

    struct B <: AT
        y::String
    end

    struct C <: AT
        z::Float64
    end

    struct D <: AT
        w::Bool
    end

    struct E <: AT
        v::Vector{Int}
    end

    mutable struct F{T} <: AT
        x::T
    end

    struct G{F} <: AT
        f::F
    end

    foo(a::AT)::Int = error("Not implemented")
    foo(a::A)::Int = a.x
    foo(b::B)::Int = length(b.y)
    foo(c::C)::Int = Int(c.z)
    foo(d::D)::Int = d.w ? 1 : 0
    foo(e::E)::Int = sum(e.v)
    foo(f::F{Int})::Int = f.x
    foo(f::F{String})::Int = length(f.x)
    foo(g::G)::Int = g.f()::Int

    collection = AT[
        A(1),
        B("22"),
        A(1),
        B("22"),
        C(3.0),
        C(4.0),
        D(true),
        D(false),
        E([1, 2, 3]),
        F(1),
        F("22"),
        G(() -> 1),
        G(() -> 2),
        G(() -> 3)
    ]

    @test @inferred(mapreduce(i -> foo(i)::Int, +, collection)) == 29

    # @show @benchmark mapreduce(foo, +, $collection; init = 0)
    # @show @benchmark sum(Iterators.map(foo, $collection))

    struct Wrapper
        type::UInt8
        wrapped::AT
    end

    Wrapper(a::A) = Wrapper(0x1, a)
    Wrapper(b::B) = Wrapper(0x2, b)
    Wrapper(c::C) = Wrapper(0x3, c)
    Wrapper(d::D) = Wrapper(0x4, d)
    Wrapper(e::E) = Wrapper(0x5, e)
    Wrapper(f::F) = Wrapper(0x6, f)
    Wrapper(g::G) = Wrapper(0x7, g)

    function foo(w::Wrapper)::Int
        if w.type == 0x1
            return foo(w.wrapped::A)
        elseif w.type == 0x2
            return foo(w.wrapped::B)
        elseif w.type == 0x3
            return foo(w.wrapped::C)
        elseif w.type == 0x4
            return foo(w.wrapped::D)
        elseif w.type == 0x5
            return foo(w.wrapped::E)
        elseif w.type == 0x6
            return foo(w.wrapped::F)
        elseif w.type == 0x7
            return foo(w.wrapped::G)
        else
            error("Unknown type")
        end
    end

    wrapped_collection = map(Wrapper, collection)

    # @show @benchmark mapreduce(foo, +, $wrapped_collection; init = 0)
    # @show @benchmark sum(Iterators.map(foo, $wrapped_collection))
end