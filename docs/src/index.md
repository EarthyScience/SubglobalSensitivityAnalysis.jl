```@meta
CurrentModule = SubglobalSensitivityAnalysis
```

# SubglobalSensitivityAnalysis

Documentation for package 
[SubglobalSensitivityAnalysis.jl](https://github.com/bgctw/SubglobalSensitivityAnalysis.jl).

Estimating Sobol sensitivity indices for a subspace of the global space 
around a parameter vector `p0`.

## Problem
Results of global sensitivity analysis (SA) are sometimes strongly influenced
by outliers resulting from unreasonable parameter combinations.

The idea is to still apply global SA, but only to a subset of the entire
possible parameter region around a reasonable parameter set.

The user specifies a probability distribution function of each parameter,
and the subglobal method ensures that a parameter range is sampled, so that
a given proportion (default %20) under its prior pdf is covered.

This ensures that for a parameter with wide distribution also a wide
range is sampled, and that more samples are drawn where the prior probability
of the parameter is higher.

## How 
Setup arguments and call the main function [`estimate_subglobal_sobol_indices`](@ref),
as described in the example doctest.
