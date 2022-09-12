using SubglobalSensitivityAnalysis
import SubglobalSensitivityAnalysis as CP
using Documenter

# allow plot to work without display
# https://discourse.julialang.org/t/generation-of-documentation-fails-qt-qpa-xcb-could-not-connect-to-display/60988/2
ENV["GKSwstype"] = "100"

DocMeta.setdocmeta!(SubglobalSensitivityAnalysis, :DocTestSetup, :(using SubglobalSensitivityAnalysis); recursive=true)

makedocs(;
    #modules=[SubglobalSensitivityAnalysis], # uncomment to show warnings on non-included docstrings
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
        "Getting started" => "getting_started.md",
        "How to" => [
            "Reload the design matrix" => "reload_design.md"
        ],
        "Reference" => [
            "Public" => [
                "Subglobal SA" => "estimate_subglobal.md",
                "R dependencies" => "install_R_dependencies.md",
                "Sobol methods" => "SobolSensitivityEstimator.md",
            ],
            "Internal" => "internal.md",
        ],
    ],
)

deploydocs(;
    repo="github.com/bgctw/SubglobalSensitivityAnalysis.jl",
    devbranch="main",
)
