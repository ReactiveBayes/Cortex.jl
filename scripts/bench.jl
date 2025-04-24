using Cortex
using ArgParse
using BenchmarkTools
using PkgBenchmark
using Dates

mkpath("results")

s = ArgParseSettings()

@add_arg_table s begin
    "--compare-branch"
    help = "Branch to compare benchmark results against"
    arg_type = String
    default = nothing
end

args = parse_args(ARGS, s)

branch = args["compare-branch"]
outputdir = joinpath(pwd(), "benchmark", "results")

if !isnothing(branch)
    name = first(ARGS)
    result = BenchmarkTools.judge(
        Cortex, name; retune = true, judgekwargs = Dict(:time_tolerance => 0.1, :memory_tolerance => 0.05)
    )
    export_markdown(joinpath(outputdir, "benchmark_vs_$(name)_result.md"), result)
else
    result = PkgBenchmark.benchmarkpkg(Cortex; retune = true)
    export_markdown(joinpath(outputdir, "benchmark_$(now()).md"), result)
    export_markdown(joinpath(outputdir, "last.md"), result)
end