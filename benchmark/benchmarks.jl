using Cortex
using BenchmarkTools

SUITE = BenchmarkGroup()

include("src/value_benchmarks.jl")
