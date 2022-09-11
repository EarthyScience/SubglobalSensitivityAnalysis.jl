module SubglobalSensitivityAnalysis

# Write your package code here.
using DistributionFits
using DataFrames, Tables
using RCall
using Chain
using StaticArrays
using InlineStrings

using Infiltrator

export SensitivityEstimator, SobolSensitivityEstimator
export supports_reloading, SupportsReloading, SupportsReloadingNo, SupportsReloadingYes
export generate_design_matrix, get_design_matrix, estimate_sobol_indices, reload_design_matrix
include("Sobol.jl")

export RSobolEstimator
include("rsobol/RSobolEstimator.jl")

export SobolTouati
include("rsobol/SobolTouati.jl")

export estimate_subglobal_sobol_indices, fit_distributions, set_reference_parameters!
include("sens_util.jl")

export install_R_dependencies
include("r_helpers.jl")

end
