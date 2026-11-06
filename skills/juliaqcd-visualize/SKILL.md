---
name: juliaqcd-visualize
description: "Make figures from JuliaQCD runs and measurements: Monte Carlo histories, autocorrelation, flow curves, effective-mass plots, fit results, and visualizations of gauge-field configurations. Use when the user asks for a plot or a picture of the vacuum."
---

# juliaqcd-visualize

Status: placeholder. Not written yet.

## When this skill is called

Tell the user that this skill is not written yet and has no tested plotting procedure. Plot from the files the other skills write (`history.csv` of `juliaqcd-generate`; `flow.csv`, `wilson_loops.csv`, `mesons.csv`, and `results.toml` of `juliaqcd-measure`) rather than recomputing the numbers, and draw error bars from the errors in those files. If the user has their own conventions for figures, follow them.

A histogram with error bars (of Q, of eigenvalues, of the plaquette) is analysis, not plotting: count per configuration, then take binned jackknife errors over configurations with `jackknife` and `choose_bin` from `juliaqcd-measure/scripts/analysis.jl`, as glue code labeled unverified. Say which bin size of the Monte Carlo chain was used.

## Planned scope

- Run-quality plots (histories, autocorrelation)
- Measurement plots (flow, effective mass, fits)
- Field visualization
