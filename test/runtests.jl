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

@testset "SobolSensitivityEstimator" begin
    #include("test/test_SobolSensitivityEstimator.jl")
    include("test_SobolSensitivityEstimator.jl")
end

@testset "SubglobalSensitivityAnalysis" begin
    #include("test/test_subglobalsens.jl")
    include("test_subglobalsens.jl")
end

