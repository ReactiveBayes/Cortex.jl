using Cortex
using BenchmarkTools
using ArgParse
using JSON
using Statistics
using Plots
using Markdown
using Git

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--compare-branch", "-c"
            help = "Branch to compare against (default: main)"
            default = "main"
        "--output", "-o"
            help = "Output directory for benchmark results (default: benchmark/results)"
            default = "benchmark/results"
    end
    return parse_args(s)
end

function get_current_branch()
    return readchomp(`$(git()) rev-parse --abbrev-ref HEAD`)
end

function run_benchmarks()
    SUITE = BenchmarkGroup()
    
    # Add your benchmarks here
    SUITE["rand"] = @benchmarkable rand(10)
    
    return run(SUITE)
end

function save_results(results, output_dir, branch)
    mkpath(output_dir)
    filename = joinpath(output_dir, "benchmark_$(branch).json")
    open(filename, "w") do io
        JSON.print(io, results)
    end
    return filename
end

function load_results(output_dir, branch)
    filename = joinpath(output_dir, "benchmark_$(branch).json")
    if isfile(filename)
        return JSON.parsefile(filename)
    end
    return nothing
end

function compare_benchmarks(current_results, compare_results)
    comparison = Dict()
    
    for (name, current) in current_results
        if haskey(compare_results, name)
            compare = compare_results[name]
            
            # Calculate statistics
            current_time = current.time
            compare_time = compare.time
            time_diff = (current_time - compare_time) / compare_time * 100
            
            current_memory = current.memory
            compare_memory = compare.memory
            memory_diff = (current_memory - compare_memory) / compare_memory * 100
            
            comparison[name] = Dict(
                "current_time" => current_time,
                "compare_time" => compare_time,
                "time_diff" => time_diff,
                "current_memory" => current_memory,
                "compare_memory" => compare_memory,
                "memory_diff" => memory_diff
            )
        end
    end
    
    return comparison
end

function generate_visualizations(comparison, output_dir)
    # Time comparison plot
    p1 = plot(
        title="Benchmark Time Comparison",
        xlabel="Benchmark",
        ylabel="Time (ns)",
        legend=:topleft
    )
    
    # Memory comparison plot
    p2 = plot(
        title="Benchmark Memory Comparison",
        xlabel="Benchmark",
        ylabel="Memory (bytes)",
        legend=:topleft
    )
    
    for (name, data) in comparison
        # Add time data
        bar!(p1, [name], [data["current_time"]], label="Current")
        bar!(p1, [name], [data["compare_time"]], label="Compare")
        
        # Add memory data
        bar!(p2, [name], [data["current_memory"]], label="Current")
        bar!(p2, [name], [data["compare_memory"]], label="Compare")
    end
    
    # Save plots
    savefig(p1, joinpath(output_dir, "time_comparison.png"))
    savefig(p2, joinpath(output_dir, "memory_comparison.png"))
end

function generate_report(current_results, compare_results, current_branch, compare_branch)
    comparison = compare_benchmarks(current_results, compare_results)
    
    report = """
    # Benchmark Comparison Report
    
    ## Comparison Details
    - Current Branch: $(current_branch)
    - Comparison Branch: $(compare_branch)
    
    ## Results
    
    ### Time Comparison
    | Benchmark | Current (ns) | Compare (ns) | Difference (%) |
    |-----------|-------------|--------------|----------------|
    """
    
    for (name, data) in comparison
        report *= "| $(name) | $(round(data["current_time"], digits=2)) | $(round(data["compare_time"], digits=2)) | $(round(data["time_diff"], digits=2)) |\n"
    end
    
    report *= "\n### Memory Comparison\n"
    report *= "| Benchmark | Current (bytes) | Compare (bytes) | Difference (%) |\n"
    report *= "|-----------|----------------|-----------------|----------------|\n"
    
    for (name, data) in comparison
        report *= "| $(name) | $(round(data["current_memory"], digits=2)) | $(round(data["compare_memory"], digits=2)) | $(round(data["memory_diff"], digits=2)) |\n"
    end
    
    report *= "\n## Visualizations\n"
    report *= "![Time Comparison](time_comparison.png)\n"
    report *= "![Memory Comparison](memory_comparison.png)\n"
    
    return report
end

function check_git_status()
    # Get git status output
    status_output = readchomp(`$(git()) status --porcelain`)
    
    if !isempty(status_output)
        println("Error: Working directory is not clean. Please commit or stash your changes before running benchmarks.")
        println("\nUncommitted changes:")
        for line in split(status_output, '\n')
            println("  - $line")
        end
        exit(1)
    end
end

function switch_branch(branch)
    try
        run(`$(git()) checkout $branch`)
        println("Switched to branch: $(branch)")
    catch e
        println("Error switching to branch $(branch): $(e)")
        exit(1)
    end
end

function run_benchmarks_on_branch(branch, output_dir)
    println("Running benchmarks on branch: $(branch)")
    
    # Store original branch
    original_branch = get_current_branch()
    
    try
        # Switch to the branch
        switch_branch(branch)
        
        # Run benchmarks
        results = run_benchmarks()
        
        # Save results
        save_results(results, output_dir, branch)
        
        return results
    finally
        # Always switch back to original branch
        if original_branch != branch
            switch_branch(original_branch)
        end
    end
end

function main()
    args = parse_commandline()
    current_branch = get_current_branch()
    compare_branch = args["compare-branch"]
    output_dir = args["output"]
    
    # Check git status before proceeding
    check_git_status()
    
    println("Running benchmarks on current branch: $(current_branch)")
    current_results = run_benchmarks()
    current_file = save_results(current_results, output_dir, current_branch)
    
    if compare_branch != current_branch
        println("Loading results from comparison branch: $(compare_branch)")
        compare_results = load_results(output_dir, compare_branch)
        
        if compare_results === nothing
            println("No results found for comparison branch. Running benchmarks...")
            compare_results = run_benchmarks_on_branch(compare_branch, output_dir)
        end
        
        # Generate visualizations
        comparison = compare_benchmarks(current_results, compare_results)
        generate_visualizations(comparison, output_dir)
        
        # Generate and save report
        report = generate_report(current_results, compare_results, current_branch, compare_branch)
        report_file = joinpath(output_dir, "benchmark_report.md")
        write(report_file, report)
        println("Report generated at: $(report_file)")
    end
end

main()
