---
name: juliaqcd-analyze
description: "Statistical analysis of lattice data from JuliaQCD runs: jackknife, bootstrap, correlated fits, chi^2/dof, model averaging, continuum, finite-volume and chiral extrapolation, and an error budget that separates statistical and systematic errors. Use when the user has measurements and wants results with errors."
---

# juliaqcd-analyze

Status: placeholder. Not written yet.

## When this skill is called

Tell the user that this skill is not written yet: fits, extrapolations, and error budgets have no tested procedure here. What is tested:

- `juliaqcd-measure/scripts/analyze_ensemble.jl` (t0, w0, Wilson loops, potential, Creutz ratios, Q) and `analyze_mesons.jl` (folded correlators, cosh effective masses), with binned jackknife errors and WARN lines. Run these first on data from `juliaqcd-measure`.
- The helpers they use: `jackknife`, `choose_bin`, `fold_correlator`, `effective_mass_cosh` in `juliaqcd-measure/scripts/analysis.jl`, and `gamma_method` for τ_int in `juliaqcd-generate/scripts/stats.jl`. `selftest_analysis.jl` shows that the binned error matches the true spread on autocorrelated data and that the unbinned error is too small.

The common workflow of the `juliaqcd` skill applies in this form: the settings table lists the input files, the thermalization cut, the bin size, the quantity, and any fit range; there is no small-lattice step; the check is that the tested scripts above run cleanly on the same data.

For a mass, give the plateau of m_eff with its error and Δt range, and say that it is not a fit. If the user wants a fit, write it as glue code (entry skill, "Requests outside what is tested here"): use an existing fitting package as is (for example LsqFit.jl), errors from the binned jackknife with the same bins as above, a correlated fit only when there are many more bins than data points, and a table of the result against the fit range. Label it unverified by this skill set. If the user has their own jackknife or fitting tool, use theirs.

## Planned scope

- Jackknife and bootstrap
- Correlated fits, chi^2/dof, AIC model averaging
- Always show how the result moves with the fit range
- Error budget table
