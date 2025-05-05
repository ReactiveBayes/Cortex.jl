using Cortex
using BenchmarkTools

SUITE = BenchmarkGroup()

include("src/signal_benchmarks.jl")
