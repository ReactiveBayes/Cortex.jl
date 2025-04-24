using Cortex
using Test
using Aqua
using JET

@testset "Cortex.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(Cortex)
    end
    @testset "Code linting (JET.jl)" begin
        JET.test_package(Cortex; target_defined_modules = true)
    end
    # Write your tests here.
end
