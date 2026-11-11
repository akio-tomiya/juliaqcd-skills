---
name: juliaqcd-analyze
description: "Statistical analysis of lattice data from JuliaQCD runs: jackknife, bootstrap, correlated fits, chi^2/dof, model averaging, continuum, finite-volume and chiral extrapolation, and an error budget that separates statistical and systematic errors. Use when the user has measurements and wants results with errors."
---

# juliaqcd-analyze

Status: the binned jackknife and the effective masses of `juliaqcd-measure`
are tested, and BlockJackknife.jl agrees with them (below). Fits,
extrapolations, and error budgets are not written.

## When this skill is called

Tell the user that fits, extrapolations, and error budgets have no tested procedure here. What is tested:

- `juliaqcd-measure/scripts/analyze_ensemble.jl` (t0, w0, Wilson loops, potential, Creutz ratios, Q) and `analyze_mesons.jl` (folded correlators, cosh effective masses), with binned jackknife errors and WARN lines. Run these first on data from `juliaqcd-measure`.
- The helpers they use: `jackknife`, `choose_bin`, `fold_correlator`, `effective_mass_cosh` in `juliaqcd-measure/scripts/analysis.jl`, and `gamma_method` for τ_int in `juliaqcd-generate/scripts/stats.jl`. `selftest_analysis.jl` shows that the binned error matches the true spread on autocorrelated data and that the unbinned error is too small.

The common workflow of the `juliaqcd` skill applies in this form: the settings table lists the input files, the thermalization cut, the bin size, the quantity, and any fit range; there is no small-lattice step; the check is that the tested scripts above run cleanly on the same data.

Whether an error is too small or too large is decided from the same data: the binned error against the unbinned one, the bin-size table, and τ_int. Do not compare it with a "typical" error size from memory or from other ensembles. Tell the user both possibilities: an unbinned error is too small on autocorrelated data, and an average over the whole lattice, such as the plaquette, can have a genuinely small error. The bin-size table tells them apart: the error grows with the bin size, or it stays flat.

For a mass, give the plateau of m_eff with its error and Δt range, and say that it is not a fit. If the user wants a fit, write it as glue code (entry skill, "Requests outside what is tested here"): use an existing fitting package as is (for example LsqFit.jl), errors from the binned jackknife with the same bins as above, a correlated fit only when there are many more bins than data points, and a table of the result against the fit range. Label it unverified by this skill set. If the user has their own jackknife or fitting tool, use theirs.

## BlockJackknife.jl for glue code

For errors in the user's own analysis (glue code), use the registered
package BlockJackknife.jl (formerly JkTools; `Pkg.add("BlockJackknife")`,
standard library only, Julia 1.10 or later, so it shares an environment
with JuliaQCD). On 2026-11-11, BlockJackknife 1.0.0 gave the same value and
error as `jackknife` in `analysis.jl` to about 1e-15 on synthetic
autocorrelated data, for a mean and for a ratio of two series, unbinned and
with blocks, including a length not divisible by the block size (both drop
the leading remainder). Its `jk_tau_int` agreed with `gamma_method` within
their errors (the windowing rules differ).

| Task | BlockJackknife | Note |
|---|---|---|
| Mean and error | `jk_meanerror(x; block=b)` | returns `(value, error)` |
| f of means of several series measured on the same configurations | `jk_meanerror((a, b) -> f(mean(a), mean(b)), A, B; block=b)` | pass all series to one call, so their correlations enter the error |
| Statistic of the raw samples (susceptibility, Binder ratio) | `jk_meanerror(x, "sus"; block=b)`, `jk_meanerror(x, func; block=b)` | `func` receives the samples, not their mean |
| Correlator `C[config, t]`, effective mass, covariance for a fit | `jk_meanerror(C, func; block=b)`, `jk_meancov` | one row per configuration |
| Histogram with error bars (Q, eigenvalues per configuration) | `jk_hist(samples; bins, block=b)` | each element is one configuration; NaN and values outside the edges are ignored |
| Block size | `jk_tau_int`, `jk_block_scan` | |

Choose the block size as in `analysis.jl`: about 4 τ_int, with at least 20
blocks left (`choose_bin` gives this; `jk_block_scan` shows the plateau).
Say which block size was used. The block is in units of the spacing of the
series: for measurements on every k-th trajectory, τ_int of the measured
series, not of the HMC history.

## Planned scope

- Jackknife and bootstrap
- Correlated fits, chi^2/dof, AIC model averaging
- Always show how the result moves with the fit range
- Error budget table
