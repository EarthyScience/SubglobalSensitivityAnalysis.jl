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

"""
    generate_design_matrix(estim::SobolSensitivityEstimator, X1, X2)

Generate the design matrix based on the two samples of parameters, where each
row is a parameter sample. For return value see [get_design_matrix](@ref).

If `supports_reloading(estim) != SupportsReloadingNo()`, then after this call
it should be able to recreate its state using method [`reload_design_matrix`](@ref).
"""
generate_design_matrix(estim::SobolSensitivityEstimator, X1, X2) = error(
    "Define generate_design_matrix(estim, X1, X2) for  concrete type $(typeof(estim)).")

"""
Reload the design matrix, 
i.e. recreate the state after last call to [`generate_design_matrix`](@ref)
"""    
reload_design_matrix(estim::SobolSensitivityEstimator) = reload_design_matrix(
    supports_reloading(estim), estim)
# reload_design_matrix(::SupportsReloadingNo, estim::SobolSensitivityEstimator) = error(
#     "Estimator does not support reloading design matrix: " * string(estim))
reload_design_matrix(::SupportsReloadingNo,estim::SobolSensitivityEstimator) = 3
        

struct RSobolEstimator{NS}
    varname::String31     # the name of the object in R
    filename::NS # the filename to which R object is serialized
    # RSobolEstimator{NS}(varname, filename::NS) where {NS} = 
    #     NS <: Union{Nothing,AbstractString} ? new{NS}(varname, filename) : 
    #     error("Only Strings or nothing is allowed")
end
function RSobolEstimator(varname, filename::NS) where {NS <: Union{Nothing,AbstractString}}
    RSobolEstimator{NS}(varname, filename)
end


# Maybe avoid duplication - so far not able to first concantenate strings
# and only thereafter interpolate.
# """
# sens_object is set to the variable named as in String `rest.varname`.
# If variable does not exist, try to initalize it from file `rest.filename`.
# """
# const get_sens_object_str = raw"""
#     sens_object = if (exists($(rest.varname))){
#         get($(rest.varname))
#     } else {
#         .tmp = readRDS($(rest.filename))
#         assign($(rest.varname), .tmp)
#         .tmp
#     }
# """

"""
    get_design_matrix(estim) 

Return the design matrix: a matrix with parameters in rows, for which to compute
the output, whose sensitivty ist studies.    
"""
function get_design_matrix(rest::RSobolEstimator) 
    rcopy(R"""
    sens_object = if (exists($(rest.varname))){
        get($(rest.varname))
    } else {
        message(paste0("reading non-existing ",$(rest.varname)," from ",$(rest.filename)))
        .tmp = readRDS($(rest.filename))
        assign($(rest.varname), .tmp)
        .tmp
    }
    data.matrix(sens_object$X)
    """)
end

"""
    estimate_sobol_indices(rest::RSobolEstimator, y, par_names=missing)

Estimate the Sobol sensitivity indices for the given result, `y`, for each 
row of the desing matrix.

## Value
A DataFrame with columns

- par: parameter name
- par: parameter name from par_names - should match `df_dist_opt.par` 
      from [compute_cp_design_matrix](@ref)
- index: which one of the SOBOL-indices, `:first_order` or `:total`
- value: the estimate
- cf95_lower and cf95_upper: estimates of the 95% confidence interval
"""
function estimate_sobol_indices(rest::RSobolEstimator, y, par_names=missing)
    check_R()
    df_S, df_T = rcopy(R"""
        sens_object = if (exists($(rest.varname))){
            get($(rest.varname))
        } else {
            message(paste0("reading non-existing ",$(rest.varname)," from ",$(rest.filename)))
            .tmp = readRDS($(rest.filename))
            assign($(rest.varname), .tmp)
            .tmp
        }
        tell(sens_object, $(y))
        l <- list(sens_object$S, sens_object$T)
    """)
    tmp = rename!(
        vcat(df_S::DataFrame, df_T::DataFrame), 
        SA[:value, :cf95_lower, :cf95_upper])
    if ismissing(par_names); par_names = "p" .* string.(1:nrow(df_S)); end 
    tmp[!,:par] = vcat(par_names,par_names)
    tmp[!,:index] = collect(Iterators.flatten(
        map(x -> Iterators.repeated(x, nrow(df_S)), (:first_order,:total))))
    select!(tmp, :par, :index, Not([:par, :index]))
end

supports_reloading(rest::RSobolEstimator) = _supports_reloading(rest.filename)
_supports_reloading(::Nothing) = SupportsReloadingNo()
_supports_reloading(::AbstractString) = SupportsReloadingYes()

function reload_design_matrix(rest::RSobolEstimator) 
    supports_reloading(rest) == SupportsReloadingNo() && error(
        "RSobolEstimator does not support reloading: " * string(rest))
    R"""
    message(paste0("reading ",$(rest.varname)," from ",$(rest.filename)))
    .tmp = readRDS($(rest.filename))
    assign($(rest.varname), .tmp)
    .tmp
    """
    get_design_matrix(rest)
end

struct SobolTouati{NT} <: SobolSensitivityEstimator
    conf::NT 
    rest::RSobolEstimator
end

"""
    SobolTouati(;conf = 0.95, rest = RSobolEstimator("sens_touati", nothing))

Concrete type of SobolSensitivityEstimator, based on method `soboltouati` from 
R package sensitivity.

# Arguments

- conf: range of the confidence interval around Sobol indices to be estimated
- rest: Can adjust R variable name of the object, and filename of the 
  backupof this variable. By providing a filename, the estimator can
  be recreated, after needing to restart the R session
  (see [`reload_design_matrix`](@ref)). 
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
reload_design_matrix(estim::SobolTouati) = reload_design_matrix(estim.rest)
