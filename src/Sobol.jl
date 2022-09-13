"""
Trait that indicates that object can be called with method 
[`reload_design_matrix`](@ref).

Implenment this trait by `supports_reloading(subtype) = SupportsReloadingYes()`
"""
abstract type SupportsReloading end,
struct SupportsReloadingNo <: SupportsReloading end,
struct SupportsReloadingYes <: SupportsReloading end,
function supports_reloading(::Any); SupportsReloadingNo(); end


"Abstract supertype of Sensitivity Estimators"
abstract type SensitivityEstimator end

"""
Abstract supertype of Sensitivity Estimators returning Sobol indices.

Subtypes need to implement the following functions:

- [`generate_design_matrix`](@ref)
  - [`get_design_matrix`](@ref)
- [`estimate_sobol_indices`](@ref)

If it implements trait , then it need also implement
  - [`reload_design_matrix`](@ref)
"""
abstract type SobolSensitivityEstimator <: SensitivityEstimator end

"just for testing errors on non-defined methods of the interface."
struct DummySobolSensitivityEstimator <: SobolSensitivityEstimator; end

"""
    generate_design_matrix(estim::SobolSensitivityEstimator, X1, X2)

Generate the design matrix based on the two samples of parameters, where each
row is a parameter sample. For return value see [`get_design_matrix`](@ref).

If the subtype `supports_reloading(subtype) != SupportsReloadingNo()`, then after this 
a call to `generate_design_matrix`
it should be able to recreate its state using method [`reload_design_matrix`](@ref).
"""
function generate_design_matrix(estim::SobolSensitivityEstimator, X1, X2) 
  error(
    "Define generate_design_matrix(estim, X1, X2) for  concrete type $(typeof(estim)).")
end

"""
    reload_design_matrix(::SupportsReloadingYes, estim::SobolSensitivityEstimator) 

Reload the design matrix, 
i.e. recreate the state after last call to [`generate_design_matrix`](@ref).
Called with trait type returned by [`supports_reloading`](@ref).
"""    
function reload_design_matrix(estim::SobolSensitivityEstimator) 
  reload_design_matrix(supports_reloading(estim), estim)
end
function reload_design_matrix(::SupportsReloadingNo, estim::SobolSensitivityEstimator) 
  error("Estimator does not support reloading design matrix: " * string(estim))
end
        

