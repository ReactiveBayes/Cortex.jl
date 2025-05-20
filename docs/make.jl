using Cortex
using Documenter

DocMeta.setdocmeta!(Cortex, :DocTestSetup, :(using Cortex); recursive = true)

makedocs(;
    # warnonly = Documenter.except(),
    modules = [Cortex],
    authors = "Bagaev Dmitry <bvdmitri@gmail.com> and contributors",
    sitename = "Cortex.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://ReactiveBayes.github.io/Cortex.jl",
        edit_link = "main",
        assets = String[],
        size_threshold = 1024 * 1024 * 8, # 8 MB
        size_threshold_warn = 1024 * 1024 # 1 MB
    ),
    pages = [
        "Home" => "index.md",
        "Signals: The Core of Reactivity" => "signals.md",
        "Model Backend: The Foundation" => "model_backend.md",
        "Inference Engine: The Brain" => "inference_engine.md"
    ]
)

deploydocs(; repo = "github.com/ReactiveBayes/Cortex.jl", devbranch = "main")
