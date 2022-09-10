using SubglobalSensitivityAnalysis
import SubglobalSensitivityAnalysis as CP
using Test

using DataFrames
using Distributions
using RCall

@testset "r_helpers" begin
    #include("test/test_r_helpers.jl")
    include("test_r_helpers.jl")
end

@testset "SubglobalSensitivityAnalysis.jl" begin
    #include("test/test_subglobalsens.jl")
    include("test_subglobalsens.jl")
end

