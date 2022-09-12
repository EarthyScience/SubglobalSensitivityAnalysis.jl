
struct SobolTouati{NT} <: SobolSensitivityEstimator
    conf::NT 
    rest::RSobolEstimator
end

"""
    SobolTouati(;conf = 0.95, rest = RSobolEstimator("sens_touati", nothing))

Concrete type of `SobolSensitivityEstimator`, based on method `soboltouati` from 
the sensitivityR package . It computes both first-order and total indices using 
correlation coefficients-based formulas, at a total cost of ``n(p+2)×n`` model evaluations.
It also computes their confidence intervals based on asymptotic properties of 
empirical correlation coefficients.

# Arguments

- `conf`: range of the confidence interval around Sobol indices to be estimated
- `rest=RSobolEstimator(varname, filename)`: Can adjust R variable name of the 
  sensitivity object, and the filename of the 
  backupof this object. By providing a filename, the estimator can
  be recreated, after needing to restart the R session
  (see [How to reload the design matrix](@ref)). 
"""
function SobolTouati(;
    conf = 0.95,
    rest = RSobolEstimator("sens_touati", nothing),
)
    SobolTouati(conf, rest)
end

function generate_design_matrix(estim::SobolTouati, X1, X2) 
    check_R()
    R"""
    X1 = $(X1)
    X2 = $(X2)
    tmp <- soboltouati(NULL,X1,X2, conf=$(estim.conf))
    assign($(estim.rest.varname), tmp)
    if (!is.null($(estim.rest.filename))) saveRDS(tmp, $(estim.rest.filename))
    """
    get_design_matrix(estim)
end

get_design_matrix(estim::SobolTouati) = get_design_matrix(estim.rest)
estimate_sobol_indices(estim::SobolTouati, args...; kwargs...) = estimate_sobol_indices(
    estim.rest, args...; kwargs...)
supports_reloading(estim::SobolTouati) = supports_reloading(estim.rest)
reload_design_matrix(::SupportsReloadingYes, estim::SobolTouati) = reload_design_matrix(estim.rest)
