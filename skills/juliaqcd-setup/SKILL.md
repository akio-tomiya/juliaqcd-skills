---
name: juliaqcd-setup
description: "Check and pin the JuliaQCD environment: Julia version (1.11, 1.12), package versions, Manifest.toml, GPU backends through JACC, and MPI. Use before the first run on a new machine, when a run fails at import or kernel launch, when results changed after a package update, or when results must be reproducible."
---

# juliaqcd-setup

Status: placeholder. Not written yet.

## When this skill is called

Tell the user that this skill is not written yet; GPU and MPI have no tested procedure here. Then, by case:

- A new machine, CPU: check `julia --version` (1.11 or 1.12; the Julia project recommends installing it with juliaup), create the environment with step 2 of `juliaqcd-generate` in the user's project folder, compare `Pkg.status()` with the versions in `juliaqcd/references/feature-map.md`, and run `check_hmc.jl` on 4⁴ as the smoke test (ask first on a laptop).
- An error from the user's own old code (`UndefVarError` for an old name): not an environment problem. Translate the code with `juliaqcd/references/legacy-api.md`.
- Use the Julia minor version that created the environment's `Manifest.toml` (`julia +1.11` with juliaup when the default is newer). A Manifest made with 1.11 and run with 1.12 fails with "could not find source path for package ..._jll" (seen with MbedTLS_jll); create a new environment for the newer Julia instead.
- An error from inside a package (`run_wizard()`, `run_LQCD`, a `MethodError` in a JuliaQCD function the user did not write): usually an environment that mixes versions. Ask for `Pkg.status()` and `versioninfo()`; LatticeQCD 1.x is pre-v1 (see the version notes in the feature map). Mixed versions usually come from the global environment (`~/.julia/environments/v1.x`) or an old `Manifest.toml` copied with a project. Fix it with a fresh project environment in the user's folder, never by editing the global one without asking: `julia --project=lqcd -e 'using Pkg; Pkg.add(name="LatticeQCD", version="2"); Pkg.status()'`, then `julia --project=lqcd -e 'using LatticeQCD; run_wizard()'`. The wizard itself is untested by these skills; offer the tested path as well (`check_hmc.jl`, then `hmc_puregauge.jl` and `monitor.jl` in `juliaqcd-generate`).
- Results changed after a package update: do not name a cause before comparing. Ask for the old and the new `Manifest.toml` (each run of `hmc_puregauge.jl` keeps one) and list the packages whose versions differ. Rule out the normalization change from pre-v1 code first (`calculate_Plaquette` returned a sum, `measure_plaquette` is normalized; `legacy-api.md`). Then run the same small check in two environments, one per Manifest, with the same seed and lattice (`check_hmc.jl` on 4⁴, or the user's measurement on one stored configuration), and compare the numbers. If one package version changes the result, update the packages one at a time to find it, and report it to the user for the package's issue tracker. A changed random stream alone changes a chain but not its averages beyond the errors.
- A cluster or GPU: the scripts here run as one process on the CPU (`process_grid` = 1) and have no `mpiexec` or GPU path. A 32⁴ SU(3) link field is about 0.6 GB, so a pure-gauge run often fits one node or one GPU. Ask for the batch system, account, partition, and how Julia is provided; the batch script follows the site's documentation. Run the CPU smoke test in a short job first, and submit nothing without the user's approval. A GPU or MPI run uses JuliaQCD as is (JACC backend, `process_grid`) and is unverified by this skill set.

## Planned scope

- Version check and pinning (save Manifest.toml with the results)
- Record seed, commit, and machine information
- Minimal GPU and MPI smoke tests
