"Abstract supertype of Sensitivity Estimators"
abstract type SensitivityEstimator end

"Abstract supertype of Sensitivity Estimators returning Sobol indices"
abstract type SobolSensitivityEstimator <: SensitivityEstimator end

"""
    generate_design_matrix(estim::SobolSensitivityEstimator, X1, X2)

Generate the design matrix based on the two samples of parameters, where each
row is a parameter sample. For return value see [get_design_matrix](@ref).
"""
generate_design_matrix(estim::SobolSensitivityEstimator, X1, X2) = error(
    "Define generate_design_matrix(estim, X1, X2) for  concrete type $(typeof(estim)).")


struct RSobolEstimator
    varname::String31     # the name of the object in R
    filename::String # the filename to which R object is serialized
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
#         so = readRDS($(rest.filename))
#         assign($(rest.varname), so)
#         so
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
        so = readRDS($(rest.filename))
        assign($(rest.varname), so)
        so
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
            so = readRDS($(rest.filename))
            assign($(rest.varname), so)
            so
        }
        tell(sens_object, $(y))
        # assign($(rest.varname), sens_object) # need to tell also original variable
        # saveRDS($(rest.varname), $(rest.filename))
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

struct SobolTouati{NT} <: SobolSensitivityEstimator
    conf::NT 
    rest::RSobolEstimator
end

"""
    SobolTouati(;conf = 0.95, rest = RSobolEstimator("sens_touati", tempname()*".rds"))

Concrete type of SobolSensitivityEstimator, based on method `soboltouati` from 
R package sensitivity.

# Arguments

- conf: range of the confidence interval around Sobol indices to be estimated
- rest: Can adjust R variable name of the object, and filename of the 
  backupof this variable. This is useful, if R session needed to restart before
  telling the outputs and computing Sobol indices.
"""
function SobolTouati(;
    conf = 0.95,
    rest = RSobolEstimator("sens_touati", tempname()*".rds"),
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
    saveRDS(tmp, $(estim.rest.filename))
    """
    get_design_matrix(estim)
end

get_design_matrix(estim::SobolTouati) = get_design_matrix(estim.rest)
estimate_sobol_indices(estim::SobolTouati, args...; kwargs...) = estimate_sobol_indices(
    estim.rest, args...; kwargs...)
    