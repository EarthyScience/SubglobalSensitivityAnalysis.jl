## How to reload the design matrix

### Problem
Computation of outputs for many parameter vectors can take long. It may happen
that the Julia session or the associated R session in which the sensitivity
object was constructed has been lost such as a disconnected ssh-session. 

If the information on
the design matrix has been lost, the computed outputs cannot be used any more.
Hence, the SobolTouati estimator class provides a method to save intermediate results to file 
and to be reconstructed from there.

### Providing the filename
We reuse the example from [Getting started](@ref).

```@example reload1
using SubglobalSensitivityAnalysis, Distributions
fsens = (a,b) -> (;target1 = 10a + b -1, target2 = a + b -0.5)
parmsModeUpperRows = [
    (:a, LogNormal, 0.2 , 0.5),
    (:b, LogitNormal, 0.7 , 0.9),
]
p0 = Dict(:a => 0.34, :b => 0.6)
nothing # hide
``` 

The back-filename is provided to a a custom sobol estimator where we specify the filename argument:
```@example reload1
some_tmp_dir = mktempdir()
fname = joinpath(some_tmp_dir,"sensobject.rds")
estim_file = SobolTouati(;rest=RSobolEstimator("sens_touati", fname))
nothing # hide
``` 

### Performing the sensitivity analysis
Instead of letting [`estimate_subglobal_sobol_indices`](@ref) call our
model, here, we do the steps by hand.

First, we estimate the distributions and add the center parameter values.
```@example reload1
df_dist = fit_distributions(parmsModeUpperRows)
set_reference_parameters!(df_dist, p0)
nothing # hide
``` 

Next, we compute the ranges of the parameters in
cumulative probability space and draw two samples. 
We need to use unexported functions and qualify their names.
```@example reload1
import SubglobalSensitivityAnalysis as CP
CP.calculate_parbounds!(df_dist)
n_sample = 10
X1 = CP.get_uniform_cp_sample(df_dist, n_sample);
X2 = CP.get_uniform_cp_sample(df_dist, n_sample);
nothing # hide
``` 

Next, we create the design matrix using the samples.
```@example reload1
cp_design = generate_design_matrix(estim_file, X1, X2);
size(cp_design)
``` 

Next, we
- transform the design matrix from cumulative to original parameter space, 
- compute outputs for each of the parameter vectors in rows, and 
- extract the first output from the result as a vector.
```@example reload1
q_design = CP.transform_cp_design_to_quantiles(df_dist, cp_design);
res = map(r -> fsens(r...), eachrow(q_design));
y = [tup[:target1] for tup in res];
nothing # hide
``` 

Now we can tell the output to the estimator and compute sobol indices:
```@example reload1
df_sobol = estimate_sobol_indices(estim_file, y)
``` 

### Reloading
Assume that after computing the outputs and backing them up to a file, our Julia
session has been lost. The original samples to create the design matrix are lost,
and we need to recreate the estimator object.

We set up a new estimator object with the same file name from above and
tell it to reload the design matrix from the file.

```@example reload1
estim_file2 = SobolTouati(;rest=RSobolEstimator("sens_touati", fname))
cp_design2 = reload_design_matrix(estim_file2)
nothing # hide
``` 

Now our new estimator object is in the state of the former estimator object
and we can use is to compute sensitivity indices.
```@example reload1
df_sobol2 = estimate_sobol_indices(estim_file2, y)
all(isapprox.(df_sobol2.value, df_sobol.value))
``` 

```@setup reload1
rm(some_tmp_dir, recursive=true)
``` 


