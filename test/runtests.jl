using SubglobalSensitivityAnalysis
import SubglobalSensitivityAnalysis as CP
using Test

using DataFrames
using Distributions

@testset "SubglobalSensitivityAnalysis.jl" begin
    #include("test/test_subglobalsens.jl")
    include("test_subglobalsens.jl")
end
