---
name: juliaqcd
description: "Entry point for lattice gauge theory work with JuliaQCD (Gaugefields.jl, LatticeDiracOperators.jl, QCDMeasurements.jl, LatticeMatrices.jl, Wilsonloop.jl, LatticeQCD.jl), v1 and later. Use when the user wants to generate gauge configurations, measure observables, analyze lattice data, reproduce a paper or an ILDG ensemble, change the gauge group or the dimension, or develop a new group, action, operator, or flow in Julia, or when code written for an old version (v0.6 or earlier, for example an UndefVarError for an old function name) must be translated to v1. Tested so far: pure-gauge generation and measurement, quenched Wilson and Wilson-clover meson correlators, and gauge-group checks; dynamical fermions are not covered yet. Routes the request to the matching juliaqcd-* skill and enforces the common workflow (settings table, small-lattice trial, verification, approval before production)."
---

# JuliaQCD

Status: v0.0.1. Written and tested: pure-gauge HMC and its monitoring (`juliaqcd-generate`), pure-gauge measurements with the gradient flow, t0, w0, Wilson loops, and the potential, and quenched Wilson and Wilson–clover meson correlators with effective masses (`juliaqcd-measure`), and the gauge-group reference implementation (`juliaqcd-extend`). The other sub-skills are placeholders.

## Common workflow

Every request that runs a simulation or a measurement follows these four steps, in this order. A question that needs no lattice (for example a property of a group) skips them and goes straight to the matching check. A diagnosis (low acceptance, an error message) starts by reading the user's files and output; it needs a settings table only when it leads to a new run.

1. Show a settings table. For generation: group, dimension, lattice size, action and couplings, boundary conditions, algorithm, number of configurations (and whether it includes thermalization), seed. For measurements: input ensemble (path, format, number of configurations), operator and its parameters (mass or κ, c_SW, fermion boundary conditions, smearing), and exactly what to compute (which observable, which eigenvalues and how many, flow times, source positions). Each entry carries its source (the user's message, a paper with page and equation number, or a default). Physics parameters (group, dimension, lattice size, action, couplings, masses, c_SW, boundary conditions, input ensemble) must come from the user or a paper: leave them blank and ask, never fill them in by guessing. "QCD" means SU(3) in four dimensions. Algorithmic parameters (number of MD steps, trajectory length, seed, start, length of a trial run) may take a default, marked "default" in the table.
2. Run a small lattice first. The checks choose their own couplings, so they can run before the user has given the production values.
3. Pass the verification checks for the case at hand: `check_hmc.jl` in `juliaqcd-generate` for HMC, `check_measure.jl` in `juliaqcd-measure` for measurements and the flow, `check_fermion.jl` in `juliaqcd-measure` for Wilson-type operators and meson correlators, `check_group.jl` in `juliaqcd-extend` for a gauge-group implementation. When no check covers the request, say so in the table and in the result.
4. Show the cost estimate (hours, memory, disk, number of configurations) and get the user's approval before any production run or job submission. Measure the cost with a short trial; do not quote a time from general knowledge.

Do not overwrite existing configurations.

## Where files go

Work in the user's project folder, never inside the plugin. Write `SKILLS` for the plugin's `skills` folder: the parent of this skill's base directory, which contains `juliaqcd-generate/`, `juliaqcd-measure/`, and the others. The commands in the skills use these paths:

- `env/`: the Julia environment, created once in the project folder (`juliaqcd-generate`, step 2). Keep its `Manifest.toml` with the results.
- `runs/NAME/`: one generated ensemble, written by `hmc_puregauge.jl`; measurements go to `runs/NAME/measure/`.
- `$SKILLS/<skill>/scripts/<script>.jl`: the scripts, called in place. For example `julia --project=env $SKILLS/juliaqcd-generate/scripts/check_hmc.jl colors=3 lattice=4,4,4,4`.

The scripts of one skill load files from another (for example `check_hmc.jl` loads `juliaqcd-extend/scripts/GaugeGroups.jl` by relative path). To run on another machine, copy the whole `skills` folder there, directly (not through a laptop for large data), and set `SKILLS` to the copy. Every script stops on an argument it does not know; read its header for the accepted ones.

## Which machine

Creating the environment downloads the packages and precompiles them (several minutes, network access). Anything that loads JuliaQCD compiles first: about 1.5 to 2 GB of memory and a minute before the first result. The checks take 30 seconds to a few minutes on one core.

- Scripts that use only the standard library (`monitor.jl`, `analyze_ensemble.jl`, `analyze_mesons.jl`, `selftest_analysis.jl`, `check_group.jl`) are light and may run anywhere.
- Checks and cost trials: on a laptop, ask the user first, giving the memory and time; a workstation needs no question, but ask which host to use if the user has not said.
- Production runs and full-ensemble measurements: on a workstation or cluster node. If the user has only a laptop, show the estimate and let them decide.
- The scripts run as one process on the CPU (`process_grid` = 1). GPU and MPI have no tested procedure here (`juliaqcd-setup`).

## Routing

| Request | Skill | Status here |
|---|---|---|
| Install, versions, a `MethodError` or `UndefVarError` from inside a package, GPU, MPI | `juliaqcd-setup` | placeholder; CPU environment in `juliaqcd-generate` |
| Generate configurations (Wilson action), monitor thermalization, acceptance, autocorrelation, topology freezing, low acceptance | `juliaqcd-generate` | tested |
| Plaquette, Wilson loops, potential, gradient flow scales, topological charge, meson correlators | `juliaqcd-measure` | tested |
| Polyakov loop | `juliaqcd-generate` (recorded in `history.csv`) | recorded, no check |
| Dirac eigenvalues | `juliaqcd-measure` | not yet: JuliaQCD function only (feature map) |
| Jackknife, effective masses, fits, extrapolations, error budget | `juliaqcd-analyze` | jackknife and m_eff tested; fits not yet |
| Figures, histograms | `juliaqcd-visualize` | placeholder |
| Reproduce an arXiv paper, or measure on configurations from elsewhere (ILDG, NERSC, a colleague) | `juliaqcd-reproduce` | placeholder |
| New group, action (Iwasaki, Symanzik), smearing, operator, flow; change dimension or group | `juliaqcd-extend` | groups tested |
| Properties of a gauge group (kind of representation, generators, invariant tensors) | `juliaqcd-extend` (`check_group.jl`, `references/groups.md`) | tested |
| First steps for a beginner | this skill: run `check_hmc.jl` on 4⁴ (no β needed), then a short chain, `monitor.jl`, and `check_measure.jl`. The chain needs a β and a lattice from the user; a beginner without one can take them from their supervisor or a textbook example they name | tested |

## Scope

Only JuliaQCD v1 and later, on the standard path built on LatticeMatrices.jl and JACC. If the user pastes code written for v0.6 or earlier, translate it with `references/legacy-api.md` instead of running it as is. If the old name comes from inside a package (for example `run_wizard()` failing with a `MethodError`), the environment mixes old and new versions: see `juliaqcd-setup`.

Before claiming that a feature exists, check it against `references/feature-map.md` (versions, what each package provides, and what is not available) and, when in doubt, against the installed package source (`pathof(Gaugefields)` gives its folder).

## Requests outside what is tested here

The physics belongs to JuliaQCD; these skills check it and run it. When a request is not covered by a tested script (dynamical fermions, eigenvalues, other actions, other file formats, fits, susceptibilities, histograms):

1. Tell the user that no tested procedure or verification script exists here for it, and what is tested nearby.
2. If JuliaQCD provides it (feature map, package source), use that function as is: LatticeQCD.jl for dynamical-fermion HMC, `EigenvalueMeasurement` for Wilson eigenvalues, `GaugeAction` with `Wilsonloop` loops for other actions.
3. Glue code is allowed after the user agrees: loops over configurations, file conversion, collecting outputs, counting a histogram, a ratio such as χ_t = ⟨Q²⟩/V. Use the tested helpers (`jackknife` and `choose_bin` in `juliaqcd-measure/scripts/analysis.jl`) for errors. Write it in the user's project folder, not in the plugin.
4. Do not write new physics code: no new action force, integrator, Dirac operator, solver, eigensolver, file-format reader for binary links, or fitting routine. If JuliaQCD lacks it, say so; the user can ask the JuliaQCD developers (issue tracker of the package).
5. Check whatever you can on a small lattice (a cold configuration, a known limit, a dense diagonalization of a 2⁴ operator, agreement with the tested scripts), and present the results as unverified by this skill set.

## Values from the literature

Do not take a lattice spacing, a scale (√t0, r0, w0 in fm), a critical κ, or a c_SW from memory, not even for a rough statement. Ask the user, or read the paper they name and quote it with page, table, or equation number. When the paper and the user's request disagree (for example a β the paper does not have), show both and let the user choose.
