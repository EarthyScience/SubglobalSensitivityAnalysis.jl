module SubglobalSensitivityAnalysis

# Write your package code here.
using DistributionFits
using DataFrames, Tables
using RCall
using Chain
using StaticArrays

using Infiltrator

export estimate_subglobal_sobol_indices, fit_distributions

include("sens_util.jl")

end
