using Cortex
using Test
using Aqua
using JET
using TestItemRunner

@testmodule TestUtils begin
    using Reexport
    @reexport using BipartiteFactorGraphs
    @reexport using Cortex

    import Cortex: Variable, Factor, Connection

    export Variable, Factor, Connection
end

@testset "Cortex.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(Cortex)
    end

    @testset "Code linting (JET.jl)" begin
        JET.test_package(Cortex; target_defined_modules = true)
    end

    TestItemRunner.@run_package_tests()
end
