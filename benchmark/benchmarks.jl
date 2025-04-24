using Cortex
using BenchmarkTools

SUITE = BenchmarkGroup()

# Add your benchmarks here
SUITE["rand"] = @benchmarkable rand(10)

SUITE["another"]["suite"] = @benchmarkable rand(100)
