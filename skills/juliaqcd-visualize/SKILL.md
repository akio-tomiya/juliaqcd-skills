---
name: juliaqcd-visualize
description: "Make figures from JuliaQCD runs and measurements (the runs/ folders of juliaqcd-generate and juliaqcd-measure): Monte Carlo histories, histograms with error bars (of the topological charge, the plaquette, eigenvalues), autocorrelation, flow curves, effective-mass plots, fit results, and visualizations of gauge-field configurations. Use when the user asks for a plot, a histogram, or a picture of lattice data or of the vacuum."
---

# juliaqcd-visualize

Status: no tested plotting procedure. The sections below point to packages
that work with JuliaQCD v1; of them, only BlockJackknife.jl has been run by
this skill set.

## When this skill is called

Tell the user that this skill has no tested plotting procedure. Plot from the files the other skills write (`history.csv` of `juliaqcd-generate`; `flow.csv`, `wilson_loops.csv`, `mesons.csv`, and `results.toml` of `juliaqcd-measure`) rather than recomputing the numbers, and draw error bars from the errors in those files. If the user has their own conventions for figures, follow them.

A histogram with error bars (of Q, of eigenvalues, of the plaquette) is analysis, not plotting. Before counting, read the run's `meta.toml` and run `monitor.jl` (`juliaqcd-generate`) for the thermalization cut and any WARN; for Q, ask at which flow time and with which definition (clover, other) it was or will be measured. Then count per configuration after the cut, then take binned jackknife errors over configurations, with `jk_hist` from BlockJackknife.jl (`juliaqcd-analyze`) or with `jackknife` and `choose_bin` from `juliaqcd-measure/scripts/analysis.jl`, as glue code labeled unverified. Say which bin size of the Monte Carlo chain was used.

## Pictures of the gauge field: VisualizingLQCD.jl

For pictures and movies of a configuration (topological-charge density,
action density, a plaquette), use VisualizingLQCD.jl 0.1.0
(`Pkg.add("VisualizingLQCD")`). It shares an environment with JuliaQCD v1;
its developers report `Pkg.test()` passing with Gaugefields 1.1.13,
LatticeDiracOperators 1.1.6, QCDMeasurements 1.0.2, and Julia 1.12.6 (CI on
1.11 and 1.12). It has not been run by this skill set.

```julia
using VisualizingLQCD
U = load_gauge("conf.jld2")                            # a JLD2 written by save_configuration
U = load_gauge("conf.ildg"; lattice=(16, 16, 16, 32))  # ILDG and Bridge++ need the lattice (colors=3 default)
q = measure(TopologicalChargeDensity(method=:clover), U)
s = measure(ActionDensity(), U)                        # E = 2 Σ_{μ<ν} Re tr(1 − U_μν), the flow normalization
snapshot("q.png", q; slice=6, beta=6.0)                # still image of one slice
movie("q.mp4", q; beta=6.0)                            # slices along the fourth direction
series = flow_series(U, TopologicalChargeDensity(); steps=0:10:200)
movie("q_flow.mp4", series; frames=FlowSweep(slice=8)) # along the flow time
```

- The sum of the charge density equals QCDMeasurements' Q (tested by the
  package). The fourth direction in a movie is a Euclidean slice, not a
  real-time evolution: say so in a caption.
- Needs GLMakie and OpenGL; CairoMakie is not supported in 0.1.0. A
  machine without a display may not work: on macOS a machine with a GUI
  login worked over ssh; rendering under xvfb on Linux is untested. Do not
  render on a laptop that is short of memory: five movies and six stills
  of 24³×32 peaked at about 4.6 GB.
- Use the new API (`load_gauge`, `measure`, `snapshot`, `movie`), not
  `create_animation`, which is kept only for compatibility. 0.1.0 is the
  first version of this API and may change in 0.2.
- `ActionDensity` values are 36 times those of 0.0.1 (the flow
  normalization); thresholds are chosen by quantiles, so pictures look the
  same.
- Each movie writes a JSON file with the frame-to-slice map, thresholds,
  and operator definitions; keep it with the movie.

## Marking figures as preliminary

For a figure with unpublished results (a talk, a draft), the user may want
a watermark. GhostStamp.jl adds one to a Plots.jl figure: `add_preliminary!(plt)`
puts a translucent red "PRELIMINARY" at the center of each 2D subplot, and
`add_stamp!(plt; text, fs, angle, color, alpha)` any other label. It is not
in the General registry: `Pkg.add(url="https://github.com/akio-tomiya/GhostStamp.jl")`.
It depends on Plots and Colors only. Ask before adding it; do not mark a
figure unless the user wants it. Not run by this skill set yet (Plots
compiles for minutes; use a workstation).

## Planned scope

- Run-quality plots (histories, autocorrelation)
- Measurement plots (flow, effective mass, fits)
- Field visualization beyond VisualizingLQCD's own tests
