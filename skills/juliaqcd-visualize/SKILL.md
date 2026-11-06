---
name: juliaqcd-visualize
description: "Make figures from JuliaQCD runs and measurements: Monte Carlo histories, autocorrelation, flow curves, effective-mass plots, fit results, and visualizations of gauge-field configurations. Use when the user asks for a plot or a picture of the vacuum."
---

# juliaqcd-visualize

Status: placeholder. Not written yet.

## When this skill is called

Tell the user that this skill is not written yet and has no tested plotting procedure. Plot from the files the other skills write (`history.csv` of `juliaqcd-generate`; `flow.csv`, `wilson_loops.csv`, and `results.toml` of `juliaqcd-measure`) rather than recomputing the numbers, and draw error bars from the errors in those files. If the user has their own conventions for figures, follow them.

## Planned scope

- Run-quality plots (histories, autocorrelation)
- Measurement plots (flow, effective mass, fits)
- Field visualization
