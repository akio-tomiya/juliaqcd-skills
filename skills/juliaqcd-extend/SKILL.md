---
name: juliaqcd-extend
description: "Develop new features on top of JuliaQCD: a new gauge group (including real and pseudo-real groups such as SO(N), Sp(2N), G2), a new action, smearing, Dirac operator, or flow, or a change of dimension. Use when the request goes beyond what JuliaQCD v1 provides. Reuse existing parts, keep the extension portable, and write tests."
---

# juliaqcd-extend

Status: placeholder. Not written yet.

## Planned scope

- First, a table of existing parts to combine and what is missing
- Group as one component, added by type and multiple dispatch: dimension, generators, projection, exponential map, Haar-random element, invariant tensors, representation type (complex, real, pseudo-real)
- Kernels in JACC, MPI halo exchange through the existing mechanism, no change to public APIs
- Recommend a separate package depending on JuliaQCD before patching the core
- Tests: group properties, gauge invariance, force vs finite differences and Enzyme, HMC reversibility and ΔH scaling, known values, backend agreement, regression
