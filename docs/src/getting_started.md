## Getting started

Assume we have a simple model, `fsens`, 
which depends on two parameters, `a` and `b`
and produces two outputs, `target1` and `target2`.

```@example gs1
fsens = (a,b) -> (;target1 = 10a + b -1, target2 = a + b -0.5)
nothing # hide
``` 

Our knowledge about reasonable model parameters is encoded by a prior
probability distribution. We can specify those by the kind of distribution,
its mode and an upper quantile. 

```@example gs1
using SubglobalSensitivityAnalysis, Distributions
install_R_dependencies(["sensitivity"])

paramsModeUpperRows = [
    (:a, LogNormal, 0.2 , 0.5),
    (:b, LogitNormal, 0.7 , 0.9),
]
nothing # hide
``` 

The output DataFrame reports 

- the estimated index and confidence bounds (column value, cf_lower, cf_upper)
- for each of the parameter/index_type/output combinations

We can provide this directly to `estimate_subglobal_sobol_indices` below, or we 
estimate/specify distribution parameters directly in a DataFrame with
column `:dist`.

```@example gs1
df_dist = fit_distributions(paramsModeUpperRows)
``` 

While these distributions are reasonable for each parameter, there are 
probably parameter combinations that produce unreasonable results. Hence, we
want to restrict our analysis to a parameter space around a central parameter
vector, `p0`.

```@example gs1
p0 = Dict(:a => 0.34, :b => 0.6)
nothing # hide
``` 

By default a range around `p0` is created that covers 20% of the cumulative
probability range, i.e a span of 0.2.

```@setup gs1
import SubglobalSensitivityAnalysis as CP
using Plots, StatsPlots
df2 = copy(df_dist)
set_reference_parameters!(df2, p0)
CP.calculate_parbounds!(df2; δ_cp = 0.1)
ipar = 2
ipar = 1
pl_cdf = plot(df2.dist[ipar], xlabel=df2.par[ipar], ylabel="cumulative probability", 
    label=nothing; func = cdf)
vline!([df2.ref[ipar]], color = "orange", label = "p0")
hline!([df2.cp_ref[ipar]], color = "maroon", linestyle=:dash, label = "cdf(p0)")
hspan!(collect(df2[ipar,[:cp_sens_lower,:cp_sens_upper]]), 
    color = "maroon", alpha = 0.2, label = "cdf(sens_range)")
vspan!(collect(df2[ipar,[:sens_lower,:sens_upper]]), 
    color = "blue", label = "sens_range", alpha = 0.2)

pl_pdf = plot(df2.dist[ipar], xlabel=df2.par[ipar], ylabel="probability density", 
    label=nothing)
vline!([df2.ref[ipar]], color = "orange", label = "p0")
vspan!(collect(df2[ipar,[:sens_lower,:sens_upper]]), 
    color = "blue", label = "sens_range", alpha = 0.2)
``` 
```@example gs1
pl_cdf # hide
``` 

For this range 20% of the area under the probability density 
function is covered.

```@example gs1
pl_pdf # hide
``` 

The design matrix for the sensitivity analysis is  constructed in the 
cumulative densities and transformed to parameter values.
For each of the parameter vectors of the design matrix an output is
computed. 
Now the Sobol indices and their confidence ranges can be computed for this output.

All this encapsulated by function [`estimate_subglobal_sobol_indices`](@ref).

```@example gs1
install_R_dependencies(["sensitivity"]) # hide
# note, for real analysis use a larger sample size
df_sobol = estimate_subglobal_sobol_indices(fsens, df_dist, p0; n_sample = 50)
df_sobol
``` 

The resulting DataFrame reports:
- the estimated Sobol indices and their confidence bounds 
  (columns value, cf_lower, cf_upper)
- for all the combinations of parameter, which index, and output
  (columns par, index, target)   

