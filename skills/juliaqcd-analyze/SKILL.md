---
name: juliaqcd-analyze
description: "Statistical analysis of lattice data from JuliaQCD runs: jackknife, bootstrap, correlated fits, chi^2/dof, model averaging, continuum, finite-volume and chiral extrapolation, and an error budget that separates statistical and systematic errors. Use when the user has measurements and wants results with errors."
---

# juliaqcd-analyze

Status: placeholder. Not written yet.

## When this skill is called

Tell the user that this skill is not written yet, so fits, extrapolations, and error budgets have no tested procedure here. Then follow the common workflow of the `juliaqcd` skill.

What is tested already: the binned jackknife (`jackknife`, `choose_bin` in `juliaqcd-measure/scripts/analysis.jl`) and the Gamma method for the integrated autocorrelation time (`gamma_method` in `juliaqcd-generate/scripts/stats.jl`). `selftest_analysis.jl` shows that the binned error matches the true spread on autocorrelated data and that the unbinned error is too small. Use these for the error of a single observable, and say that anything beyond them was not checked by this skill.

## Planned scope

- Jackknife and bootstrap
- Correlated fits, chi^2/dof, AIC model averaging
- Always show how the result moves with the fit range
- Error budget table
