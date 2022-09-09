"""
    estimate_subglobal_sobol_indices(f, parmsModeUpperRows, p0; 
        n_sample = 500, δ_cp = 0.1, names_opt, targets)

Estimate the Sobol sensitivity indices for a subspace of the global space around
parameter vector `p0`.

The subspace to sample is determined by an area in the cumulative
probability function, specifically for parameter i: cdf(p0) ± δ_cp.
Samples are drawn from this cdf-scale and converted back to quantiles
at the parameter scale.

Sobol indices are estimated using the method of Touati (2016), which
has a total cost of ``(p+2)×n``, where p is the number of parameters
and n is the number of samples in each of the two random parameter samples.

## Arguments

- `f`: a function to compute a set of results, whose sensitivity is to be inspected,
  from parametes `(p1, p2, ...) -> NamedTuple{NTuple{N,NT}} where NT <: Number`, 
  for example `fsens = (a,b) -> (;target1 = a + b -1, target2 = a + b -0.5)`.
- `parmsModeUpperRows`: a Vector of Tuples of the form 
  `(:par_name, Distribution, mode, 95%_quantile)` where Distribution is
  a non-parameterized Object from Distributions.jl such as `LogNormal`.
  Alternatively, the argument can be the result of [`fit_distributions`](@ref)
- `p0`: the parameter around which the samples are drawn.

Optional

- `n_sample = 500`: the number of parameter-vectors in each of the samples
   used by the sensitivity method.
- `δ_cp = 0.1`: the range around cdf(p0_i) to sample.
- `min_quant=0.005` and `max_quant=0.995`: to constrain the range of 
  cumulative probabilities when parameters are near the ends of the distribution.
- `targets`: a `NTuple{Symbol}` of subset of the outputs of f, to constrain the 
  computation to specific outputs.
- `names_opt`: a `NTuple{Symbol}` of subset of the parameters given with parmsModeUpperRows
  
## Return value
A DataFrame with columns

- `par`: parameter name 
- `index`: which one of the SOBOL-indices, `:first_order` or `:total`
- `value`: the estimate
- `cf95_lower` and `cf95_upper`: estimates of the 95% confidence interval
- `target`: the result, for which the sensitivity has been computed
"""
function estimate_subglobal_sobol_indices(f, parmsModeUpperRows, p0; kwargs...)
    df_dist = fit_distributions(parmsModeUpperRows)
    estimate_subglobal_sobol_indices(f, df_dist, p0; kwargs...)
end
function estimate_subglobal_sobol_indices(
    f, df_dist::DataFrame, p0; 
    n_sample=500, δ_cp=0.1, targets=missing, names_opt=missing)
    #
    set_reference_parameters!(df_dist, p0)
    calculate_parbounds!(df_dist; δ_cp)
    if ismissing(names_opt); names_opt = df_dist.par; end
    # only works since 1.7: (;cp_design, df_cfopt, path_sens_object) = compute_cp_design_matrix(
    # need to care for argument order
    (cp_design, df_cfopt, path_sens_object) = compute_cp_design_matrix(
            df_dist, names_opt, n_sample)
        q_design = transform_cp_design_to_quantiles(df_cfopt, cp_design)
    res = map(r -> f(r...), eachrow(q_design))
    if ismissing(targets); targets = propertynames(first(res)); end
    dfs = map(targets) do target
        y = [tup[target] for tup in res]
        df_sobol =  compute_sobol_indices(y, path_sens_object, df_cfopt.par)
        transform!(df_sobol, [] => ByRow(() -> target) => :target)
    end
    vcat(dfs...)
end

"""
    check_R()

load libraries and if not found, try to install them before.    
"""
function check_R()
    res = rcopy(R"""
      if (!requireNamespace("sensitivity")) {
        #install.packages("sensitivity", method="curl")
        install.packages("sensitivity")
      }
      library(sensitivity)
      """)
end

i_tmp = () -> begin
    rcopy(R"remove.packages('units')")
    rcopy(R"library(sensitivity)")
    rcopy(R".libPaths()")
    rcopy(R"install.packages('units', method='curl')")
end

"""
    fit_distributions(tups)
    fit_distributions!(df)

For each row, fit a distribution of type `dType` to `mode` and `upper` quantile.

In the first variant, parameters are specified as a vector of tuples, which are 
converted to a `DataFrame`.
A new column `:dist` with a concrete Distribution is added.
The second variant modifies a `DataFrame` with corresponding input columns.
"""
function fit_distributions(parmsModeUpperRows::AbstractVector{T}; 
    cols = (:par, :dType, :mode, :upper)) where T <: Tuple
    #
    df = rename!(DataFrame(Tables.columntable(parmsModeUpperRows)), collect(cols))
    @assert all(df[:,2] .<: Distribution) "Expected all second tuple " * 
    "components to be Distributions."
    # @assert all(isa.(df[:,3], Number)) "Expected all third tuple components (mode)" * 
    # " to be Numbers."
    # @assert all(isa.(df[:,4], Number)) "Expected all forth tuple components " 
    #* "(upper quantile) to be Numbers."
    @assert all(df[:,3] .<= df[:,4]) "Expected all third tuple components (mode) to be " *
    "smaller than forth tuple components (upper quantile)"
    fit_distributions!(df)
end
function fit_distributions!(df::DataFrame)
    f1v = (dType, mode, upper) -> fit(dType, @qp_m(mode), @qp_uu(upper))
    transform!(df, Cols(:dType,:mode,:upper) => ByRow(f1v) => :dist)
end    

"""
    set_reference_parameters!(df, par_dict)

Set the :ref column to given parameters for keys in par_dict matching column :par.   
Non-matching keys are set to missing.
"""
function set_reference_parameters!(df, par_dict)
    df[!,:ref] = get.(Ref(par_dict), df.par, missing)
    df
end


"""
    calculate_parbounds(dist, x; δ_cp = 0.1 )

compute the values at quantiles ±δ_cp around x
with δ_cp difference in the cumulated probability. 
The quantiles are constrained to not extend beyond `min_quant` and `max_quant`.

It returns a NamedTuple of
- sens_lowe: lower quantile
- sens_upper: upper quantile
- cp_ref: cdf of x (cumulative distribution function, i.e. p-value)
- cp_sens_lower: cdf of lower quantile
- cp_sens_upper: cdf of upper quantile

A wider distribution prior distribution will result in a wider intervals.

The DataFrame variant assumes x as column :ref to be present and 
adds/modifies output columns (named as above outputs).
"""
function calculate_parbounds(dist, x; δ_cp=0.1, min_quant=0.005, max_quant=0.995 )
    ismissing(x) && return(NamedTuple{
        (:sens_lower,:sens_upper,:cp_par,:cp_sens_lower,:cp_sens_upper)
        }(ntuple(_ -> missing,5)))
    cp_par = cdf(dist, x)
    cp_sens_lower = max(min_quant, cp_par - δ_cp)
    cp_sens_upper = min(max_quant, cp_par + δ_cp)
    qs = quantile.(dist, (cp_sens_lower, cp_sens_upper))
    (;sens_lower=qs[1], sens_upper=qs[2], cp_par, cp_sens_lower, cp_sens_upper)
end,
function calculate_parbounds!(df; kwargs...)
    f2v = (ref, dist) -> calculate_parbounds(dist,ref; kwargs...)
    transform!(df, [:ref,:dist,] => ByRow(f2v) => AsTable)
end

"""
    compute_cp_design_matrix(df_dist, names_opt, N; path_sens_object=tempname()*".rds")

Compute the design matrix for two symples of size N from cumulative probability ranges.
Returns a NamedTuple: 
- cp_design: Matrix (n_row x n_param) for wich output needs to be computed
- path_sens_object: path to the file that stores the R sensitivity object
"""
function compute_cp_design_matrix(df_dist, names_opt, N; path_sens_object=tempname()*".rds")
    # ranges of cumulative probabilities given to R
    df_cfopt = Chain.@chain df_dist begin
        select(:par, :cp_sens_lower, :cp_sens_upper, :dist) 
        subset(:par => ByRow(x -> x ∈ names_opt))
    end
    check_R()
    cp_design = rcopy(R"""
        #library(sensitivity) # moved to check_R() that installs
        # for sobolowen X1,X2,X3 need to be data.frames, and need to convert
        # design matrix (now also a data.frame) to array
        set.seed(0815)
        N = $(N)
        path_sens <- $(path_sens_object)
        dfr <- $(select(df_cfopt, :par, :cp_sens_lower, :cp_sens_upper))
        get_sample <- function(){
        setNames(data.frame(sapply(1:nrow(dfr), function(i){
            runif(N, min = dfr$cp_sens_lower[i], max = dfr$cp_sens_upper[i])
        })), dfr$par)
        }
        #plot(density(get_sample()$k_L))
        #lines(density(get_sample()$k_R))
        #sensObject <- sobolSalt(NULL,get_sample(), get_sample(), nboot=100) 
        sensObject <- soboltouati(NULL,get_sample(), get_sample(), nboot=100) 
        # sobolowen returned fluctuating results on repeated sample matrices
        # sensObject <- sobolowen(...)
        saveRDS(sensObject, path_sens)
        # str(sensObject$X)
        data.matrix(sensObject$X)
        """);
    (;cp_design, df_cfopt, path_sens_object)
end


"""
    transform_cp_design_to_quantiles(df_cfopt, cp_design)

Transform cumulative probabilities back to quantiles.
"""
function transform_cp_design_to_quantiles(df_cfopt, cp_design)
    q_design = similar(cp_design)
    for (i_par, col_design) in enumerate(eachcol(cp_design))
        q_design[:,i_par] .= quantile.(df_cfopt.dist[i_par], col_design)
    end
    q_design
end

"""
    compute_sobol_indices(y, path_sens_object, par_names)

Tell the results, `y`,to sensitivity object in R, deserialized from `path_sens_object`
and compute first order and total SOBOL effects and its uncertainty.

Returns a DataFrame with columns 
- par: parameter name from par_names - should match `df_cfopt.par` 
      from [compute_cp_design_matrix](@ref)
- index: which one of the SOBOL-indices, `:first_order` or `:total`
- value: the estimate
- cf95_lower and cf95_upper: estimates of the 95% confidence interval
""" 
function compute_sobol_indices(y, path_sens_object, par_names)
    check_R()
    df_S, df_T = rcopy(R"""
        y = $(y)
        path_sens = $(path_sens_object)
        #library(sensitivity) # moved to check_R
        sensObject = readRDS(path_sens)
        tell(sensObject, y)
        l <- list(sensObject$S, sensObject$T)
        # lapply(l, function(o){
        #     colnames(o) <- gsub(" ","", colnames(o)); o
        # })
        """)
        tmp = rename!(
            vcat(df_S::DataFrame, df_T::DataFrame), SA[:value, :cf95_lower, :cf95_upper])
        tmp[!,:par] = vcat(par_names,par_names)
        tmp[!,:index] = collect(Iterators.flatten(
            map(x -> Iterators.repeated(x, nrow(df_S)), (:first_order,:total))))
        select!(tmp, :par, :index, Not([:par, :index]))
end
