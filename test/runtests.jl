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

@testmodule TestDistributions begin
    using Random

    import Base: precision

    struct Beta
        a::Float64
        b::Float64
    end

    struct Bernoulli
        y::Bool
    end

    struct NormalMeanVariance
        mean::Float64
        variance::Float64
    end

    mean(n::NormalMeanVariance) = n.mean
    var(n::NormalMeanVariance) = n.variance
    precision(n::NormalMeanVariance) = 1 / n.variance

    function product(left::NormalMeanVariance, right::NormalMeanVariance)
        xi = left.mean / left.variance + right.mean / right.variance
        w = 1 / left.variance + 1 / right.variance
        variance = 1 / w
        mean = variance * xi
        return NormalMeanVariance(mean, variance)
    end

    Random.rand(rng::AbstractRNG, n::NormalMeanVariance) = n.mean + randn(rng) * sqrt(n.variance)

    struct NormalMeanPrecision
        mean::Float64
        precision::Float64
    end

    mean(n::NormalMeanPrecision) = n.mean
    var(n::NormalMeanPrecision) = 1 / n.precision
    precision(n::NormalMeanPrecision) = n.precision

    Random.rand(rng::AbstractRNG, n::NormalMeanPrecision) = n.mean + randn(rng) / sqrt(n.precision)

    struct Gamma
        shape::Float64
        scale::Float64
    end

    mean(g::Gamma) = g.shape * g.scale
    var(g::Gamma) = g.shape * g.scale^2

    struct MvNormalMeanPrecision
        mean::Vector{Float64}
        precision::Matrix{Float64}
    end

    mean(n::MvNormalMeanPrecision) = n.mean
    cov(n::MvNormalMeanPrecision) = inv(n.precision)
    precision(n::MvNormalMeanPrecision) = n.precision

    function product(left::NormalMeanPrecision, right::NormalMeanPrecision)
        xi = left.mean * left.precision + right.mean * right.precision
        w = left.precision + right.precision
        precision = w
        mean = (1 / precision) * xi
        return NormalMeanPrecision(mean, precision)
    end

    function product(left::Gamma, right::Gamma)
        return Gamma(left.shape + right.shape - 1, (left.scale * right.scale) / (left.scale + right.scale))
    end

    export Beta,
        Bernoulli,
        NormalMeanVariance,
        NormalMeanPrecision,
        Gamma,
        MvNormalMeanPrecision,
        mean,
        var,
        precision,
        cov,
        product
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
