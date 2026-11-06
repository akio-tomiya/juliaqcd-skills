---
name: juliaqcd-setup
description: "Check and pin the JuliaQCD environment: Julia version (1.11, 1.12), package versions, Manifest.toml, GPU backends through JACC, and MPI. Use before the first run on a new machine, when a run fails at import or kernel launch, or when results must be reproducible."
---

# juliaqcd-setup

Status: placeholder. Not written yet.

## When this skill is called

Tell the user that this skill is not written yet; GPU and MPI have no tested procedure here. For a CPU environment, use the setup step of `juliaqcd-generate` (one environment, its `Manifest.toml` kept with the results) and run `check_hmc.jl` there as the smoke test. An error about an old function name is not an environment problem: translate the code with `juliaqcd/references/legacy-api.md`.

## Planned scope

- Version check and pinning (save Manifest.toml with the results)
- Record seed, commit, and machine information
- Minimal GPU and MPI smoke tests
