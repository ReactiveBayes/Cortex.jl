using Cortex
using Documenter

DocMeta.setdocmeta!(Cortex, :DocTestSetup, :(using Cortex); recursive=true)

makedocs(;
    modules=[Cortex],
    authors="Bagaev Dmitry <bvdmitri@gmail.com> and contributors",
    sitename="Cortex.jl",
    format=Documenter.HTML(;
        canonical="https://ReactiveBayes.github.io/Cortex.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Implementation" => "implementation.md",
    ],
)

deploydocs(;
    repo="github.com/ReactiveBayes/Cortex.jl",
    devbranch="main",
)
