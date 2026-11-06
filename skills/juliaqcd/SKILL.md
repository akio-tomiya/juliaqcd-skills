---
name: juliaqcd
description: "Entry point for lattice gauge theory work with JuliaQCD (Gaugefields.jl, LatticeDiracOperators.jl, QCDMeasurements.jl, LatticeMatrices.jl, Wilsonloop.jl, LatticeQCD.jl), v1 and later. Use when the user wants to generate gauge configurations, measure observables, analyze lattice data, reproduce a paper or an ILDG ensemble, change the gauge group or the dimension, or develop a new group, action, operator, or flow in Julia. Routes the request to the matching juliaqcd-* skill and enforces the common workflow (settings table, small-lattice trial, verification, approval before production)."
---

# JuliaQCD

Status: skeleton (v0.0.1). The sub-skills are placeholders.

## Common workflow

Every request follows these four steps, in this order.

1. Show a settings table: group, dimension, lattice size, action and couplings, boundary conditions, algorithm, number of configurations, seed. Each entry carries its source (the user's message, a paper with page and equation number, or a default). Leave an entry blank and ask when it cannot be read off; never fill it in by guessing.
2. Run a small lattice first.
3. Pass the verification checks for the case at hand (see `juliaqcd-extend` for the checks by group type).
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

## Scope

Only JuliaQCD v1 and later, on the standard path built on LatticeMatrices.jl and JACC. If the user pastes code written for v0.6 or earlier, translate it to the v1 API instead of running it as is.

Before claiming that a feature exists, check it against the feature map (to be added as `references/feature-map.md`, regenerated for each release). If it is not in the map, say so and route to `juliaqcd-extend`.
