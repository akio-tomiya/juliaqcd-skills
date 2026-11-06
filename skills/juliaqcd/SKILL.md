---
name: juliaqcd
description: "Entry point for lattice gauge theory work with JuliaQCD (Gaugefields.jl, LatticeDiracOperators.jl, QCDMeasurements.jl, LatticeMatrices.jl, Wilsonloop.jl, LatticeQCD.jl), v1 and later. Use when the user wants to generate gauge configurations, measure observables, analyze lattice data, reproduce a paper or an ILDG ensemble, change the gauge group or the dimension, or develop a new group, action, operator, or flow in Julia, or when code written for an old version (v0.6 or earlier, for example an UndefVarError for an old function name) must be translated to v1. Tested so far: pure-gauge generation and measurement, quenched Wilson and Wilson-clover meson correlators, and gauge-group checks; dynamical fermions are not covered yet. Routes the request to the matching juliaqcd-* skill and enforces the common workflow (settings table, small-lattice trial, verification, approval before production)."
---

# JuliaQCD

Status: v0.0.1. Written and tested: pure-gauge HMC and its monitoring (`juliaqcd-generate`), pure-gauge measurements with the gradient flow, t0, w0, Wilson loops, and the potential, and quenched Wilson and Wilson–clover meson correlators with effective masses (`juliaqcd-measure`), and the gauge-group reference implementation (`juliaqcd-extend`). The other sub-skills are placeholders.

## Common workflow

Every request that runs a simulation or a measurement follows these four steps, in this order. A question that needs no lattice (for example a property of a group) skips them and goes straight to the matching check.

1. Show a settings table. For generation: group, dimension, lattice size, action and couplings, boundary conditions, algorithm, number of configurations, seed. For measurements: input ensemble (path, format, number of configurations), operator and its parameters (mass or κ, fermion boundary conditions, smearing), and exactly what to compute (which observable, which eigenvalues and how many, flow times, source positions). Each entry carries its source (the user's message, a paper with page and equation number, or a default). Physics parameters (group, dimension, lattice size, couplings, masses, boundary conditions, input ensemble) must come from the user or a paper: leave them blank and ask, never fill them in by guessing. Algorithmic parameters (number of MD steps, trajectory length, seed, start, length of a trial run) may take a default, marked "default" in the table.
2. Run a small lattice first. The checks choose their own couplings, so they can run before the user has given the production values.
3. Pass the verification checks for the case at hand: `check_hmc.jl` in `juliaqcd-generate` for HMC, `check_measure.jl` in `juliaqcd-measure` for measurements and the flow, `check_fermion.jl` in `juliaqcd-measure` for Wilson-type operators and meson correlators, `check_group.jl` in `juliaqcd-extend` for a gauge-group implementation.
4. Show the cost estimate (hours, memory, disk, number of configurations) and get the user's approval before any production run or job submission.

Do not run heavy jobs on a laptop. Do not overwrite existing configurations.

## Routing

| Request | Skill |
|---|---|
| Install, versions, GPU, MPI | `juliaqcd-setup` |
| Generate configurations, monitor thermalization, acceptance, autocorrelation, topology freezing | `juliaqcd-generate` |
| Plaquette, Wilson loops, Polyakov loop, gradient flow scales, correlators, topology, eigenvalues | `juliaqcd-measure` |
| Jackknife, bootstrap, fits, extrapolations, error budget | `juliaqcd-analyze` |
| Figures and visualization | `juliaqcd-visualize` |
| Reproduce an ILDG ensemble or an arXiv paper | `juliaqcd-reproduce` |
| New group, action, smearing, operator, flow; change dimension or group | `juliaqcd-extend` |
| Properties of a gauge group (kind of representation, generators, invariant tensors) | `juliaqcd-extend` (`check_group.jl`, `references/groups.md`) |

The scripts of one skill may load files from another (for example
`check_hmc.jl` loads `juliaqcd-extend/scripts/GaugeGroups.jl` by relative
path). When copying scripts to another machine, copy the whole `skills`
folder.

## Scope

Only JuliaQCD v1 and later, on the standard path built on LatticeMatrices.jl and JACC. If the user pastes code written for v0.6 or earlier, translate it with `references/legacy-api.md` instead of running it as is.

Before claiming that a feature exists, check it against `references/feature-map.md` (versions, what each package provides, and what is not available). If it is not in the map, say so and route to `juliaqcd-extend`.

Quenched meson correlators with Wilson or Wilson–clover valence quarks are in `juliaqcd-measure` (conventions in its `references/mesons.md`). The rest of the fermion side (dynamical-fermion HMC, staggered and domain-wall operators, eigenvalues, the PCAC mass) is in JuliaQCD (see the map) but not yet in these skills. For those, tell the user that no tested procedure or verification script exists here for them. If they still want to go ahead, follow the common workflow, check every API against the map and the package documentation, and present the results as unverified by this skill set.
