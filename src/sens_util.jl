"""
    estimate_subglobal_sobol_indices(f, paramsModeUpperRows, p0; 
        estim::SobolSensitivityEstimator=SobolTouati(),
        n_sample = 500, δ_cp = 0.1, names_opt, targets)

Estimate the Sobol sensitivity indices for a subspace of the global space around
parameter vector `p0`.

The subspace to sample is determined by an area in the cumulative
probability function, specifically for parameter i_par: cdf(p0) ± δ_cp.
Samples are drawn from this cdf-scale and converted back to quantiles
at the parameter scale.

Sobol indices are estimated using the method of Touati (2016), which
has a total cost of ``(p+2)×n``, where p is the number of parameters
and n is the number of samples in each of the two random parameter samples.

## Arguments

- `f`: a function to compute a set of results, whose sensitivity is to be inspected,
  from parameters `(p1, p2, ...) -> NamedTuple{NTuple{N,NT}} where NT <: Number`, 
  for example `fsens = (a,b) -> (;target1 = a + b -1, target2 = a + b -0.5)`.
- `paramsModeUpperRows`: a Vector of Tuples of the form 
  `(:par_name, Distribution, mode, 95%_quantile)` where Distribution is
  a non-parameterized Object from Distributions.jl such as `LogNormal`.
  Alternatively, the argument can be the DataFrame with columns `par` and `dist`,
  such as the result of [`fit_distributions`](@ref)
- `p0`: the parameter vector around which subspace is constructed.

Optional

- `estim`: The [`SobolSensitivityEstimator`](@ref), responsible for generating the 
  design matrix and computing the indices for a given result
- `n_sample = 500`: the number of parameter-vectors in each of the samples
   used by the sensitivity method.
- `δ_cp = 0.1`: the range around cdf(p0_i) to sample.
- `min_quant=0.005` and `max_quant=0.995`: to constrain the range of 
  cumulative probabilities when parameters are near the ends of the distribution.
- `targets`: a `NTuple{Symbol}` of subset of the outputs of f, to constrain the 
  computation to specific outputs.
- `names_opt`: a `NTuple{Symbol}` of subset of the parameters given with paramsModeUpperRows
  
## Return value
A DataFrame with columns

- `par`: parameter name 
- `index`: which one of the SOBOL-indices, `:first_order` or `:total`
- `value`: the estimate
- `cf_lower` and `cf_upper`: estimates of the 95% confidence interval
- `target`: the result, for which the sensitivity has been computed

## Example
```@example
using Distributions
paramsModeUpperRows = [
    (:a, LogNormal, 0.2 , 0.5),
    (:b, LogitNormal, 0.7 , 0.9),
];
p0 = Dict(:a => 0.34, :b => 0.6)
fsens = (a,b) -> (;target1 = 10a + b -1, target2 = a + b -0.5)
# note, for real analysis use larger sample size
df_sobol = estimate_subglobal_sobol_indices(fsens, paramsModeUpperRows, p0; n_sample = 50)
```
"""
function estimate_subglobal_sobol_indices(f, paramsModeUpperRows, p0; kwargs...)
    df_dist = fit_distributions(paramsModeUpperRows)
    estimate_subglobal_sobol_indices(f, df_dist, p0; kwargs...)
end
function estimate_subglobal_sobol_indices(
    f, df_dist::DataFrame, p0; 
    estim::SobolSensitivityEstimator=SobolTouati(),
    n_sample=500, δ_cp=0.1, targets=missing, names_opt=missing)
    #
    set_reference_parameters!(df_dist, p0)
    if ismissing(names_opt)
        names_opt = df_dist.par
        df_dist_opt = df_dist
    else
        df_dist_opt = subset(df_dist, :par => ByRow(x -> x ∈ names_opt))
    end
    calculate_parbounds!(df_dist_opt; δ_cp)
    X1 = get_uniform_cp_sample(df_dist_opt, n_sample);
    X2 = get_uniform_cp_sample(df_dist_opt, n_sample);
    cp_design = generate_design_matrix(estim, X1, X2)
    q_design = transform_cp_design_to_quantiles(df_dist_opt, cp_design)
    res = map(r -> f(r...), eachrow(q_design))
    if ismissing(targets); targets = propertynames(first(res)); end
    dfs = map(targets) do target
        y = [tup[target] for tup in res]
        df_sobol =  estimate_sobol_indices(estim, y, df_dist_opt.par)
        transform!(df_sobol, [] => ByRow(() -> target) => :target)
    end
    vcat(dfs...)
end

"""
    check_R()

load R libraries and if not found, try to install them before
to session-specific library path.
"""
function check_R()
    lib = rcopy(R"file.path(tempdir(),'session-library')")
    install_R_dependencies(["sensitivity"]; lib)
    R"library(sensitivity)"
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
function fit_distributions(paramsModeUpperRows::AbstractVector{T}; 
    cols = (:par, :dType, :mode, :upper)) where T <: Tuple
    #
    df = rename!(DataFrame(Tables.columntable(paramsModeUpperRows)), collect(cols))
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
        (:sens_lower,:sens_upper,:cp_ref,:cp_sens_lower,:cp_sens_upper)
        }(ntuple(_ -> missing,5)))
    cp_ref = cdf(dist, x)
    cp_sens_lower = max(min_quant, cp_ref - δ_cp)
    cp_sens_upper = min(max_quant, cp_ref + δ_cp)
    qs = quantile.(dist, (cp_sens_lower, cp_sens_upper))
    (;sens_lower=qs[1], sens_upper=qs[2], cp_ref, cp_sens_lower, cp_sens_upper)
end,
function calculate_parbounds!(df; kwargs...)
    f2v = (ref, dist) -> calculate_parbounds(dist,ref; kwargs...)
    transform!(df, [:ref,:dist,] => ByRow(f2v) => AsTable)
end

"get matrix (n_sample, n_par) with uniformly sampled in cumaltive p domain"
function get_uniform_cp_sample(df_dist, n_sample)
    tmp = map(Tables.namedtupleiterator(select(df_dist, :cp_sens_lower, :cp_sens_upper))) do (lower,upper)
        rand(Uniform(lower, upper), n_sample)
    end
    hcat(tmp...)
    # # mutating single-allocation version
    # X1 = Matrix{eltype(df_dist.cp_sens_lower)}(undef, n_sample, nrow(df_dist))
    # X2 = copy(X1)
    # for (i, (lower, upper)) in enumerate(Tables.namedtupleiterator(select(df_dist, :cp_sens_lower, :cp_sens_upper)))
    #     dunif = Uniform(lower, upper)
    #     X1[:,i] .= rand(dunif, n_sample)
    #     X2[:,i] .= rand(dunif, n_sample)
    # end
end

"""
    transform_cp_design_to_quantiles(df_dist_opt, cp_design)

Transform cumulative probabilities back to quantiles.
"""
function transform_cp_design_to_quantiles(df_dist_opt, cp_design)
    q_design = similar(cp_design)
    for (i_par, col_design) in enumerate(eachcol(cp_design))
        q_design[:,i_par] .= quantile.(df_dist_opt.dist[i_par], col_design)
    end
    q_design
end
