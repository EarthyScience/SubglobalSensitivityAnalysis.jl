using SubglobalSensitivityAnalysis
using Documenter

DocMeta.setdocmeta!(SubglobalSensitivityAnalysis, :DocTestSetup, :(using SubglobalSensitivityAnalysis); recursive=true)

makedocs(;
    modules=[SubglobalSensitivityAnalysis],
    authors="Thomas Wutzler <twutz@bgc-jena.mpg.de> and contributors",
    repo="https://github.com/bgctw/SubglobalSensitivityAnalysis.jl/blob/{commit}{path}#{line}",
    sitename="SubglobalSensitivityAnalysis.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://bgctw.github.io/SubglobalSensitivityAnalysis.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/bgctw/SubglobalSensitivityAnalysis.jl",
    devbranch="main",
)
