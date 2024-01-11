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
# If variable does not exist, try to initialize it from file `rest.filename`.
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
the output, whose sensitivity is studied.    
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
row of the design matrix.

## Value
A DataFrame with columns

- `par`: parameter name
- `index`: which one of the SOBOL-indices, `:first_order` or `:total`
- `value`: the estimate
- `cf_lower` and `cf_upper`: estimates of the confidence interval. The meaning, 
   i.e. with of the interval is usually parameterized when creating the 
   sensitivity estimator object (see e.g. [`SobolTouati`](@ref)).
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
        SA[:value, :cf_lower, :cf_upper])
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
    R"""
    message(paste0("reading ",$(rest.varname)," from ",$(rest.filename)))
    .tmp = readRDS($(rest.filename))
    assign($(rest.varname), .tmp)
    .tmp
    """
    get_design_matrix(rest)
end

