## Provide different methods of estimating Sobol indices

The Subglobal sensitivity analysis (SA) is a global SA around a subspace
of the entire parameter space. One kind of global SA is the computation of Sobol indices and
there are many methods of computing these (see e.g. help of the `sensitivity` R package ).

In order to combine Subglobal SA with different methods of estimation of Sobol
indices, there is interface [`SobolSensitivityEstimator`](@ref), which can be
implemented to support other methods.

The first method, [`generate_design_matrix`](@ref), creates a design matrix (n_rec × n_par) with parameter vectors in rows. 

The second method, [`estimate_sobol_indices`](@ref), takes a vector of computed results for each
of the design matrix parameters, and computes first and total Sobol indices.

### Index
```@index
Pages = ["SobolSensitivityEstimator.md",]
```

### Types
```@docs
SensitivityEstimator
SobolSensitivityEstimator
generate_design_matrix
get_design_matrix
estimate_sobol_indices
```

### supports_reloading trait 

Reference for the concept explained at [How to reload design matrix](@ref)

```@docs
supports_reloading
reload_design_matrix
```

### Sobol estiamtion methods
```@docs
SobolTouati
```
