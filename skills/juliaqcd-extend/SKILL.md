---
name: juliaqcd-extend
description: "Develop new features on top of JuliaQCD: a new gauge group (including real and pseudo-real groups such as SO(N), Sp(2N), G2), a new action, smearing, Dirac operator, or flow, or a change of dimension. Use when the request goes beyond what JuliaQCD v1 provides. Reuse existing parts, keep the extension portable, and write tests."
---

# juliaqcd-extend

Status: the gauge-group part is written and tested. Actions, smearing,
operators, flows, and lattice-level tests (gauge invariance, forces, HMC) are
not written yet.

## Before writing code

Show the user a table: which existing JuliaQCD parts will be combined, how,
and what is missing. Write new code only for the missing rows.

Recommend building the feature as a separate package that depends on
JuliaQCD before patching JuliaQCD itself. Add new groups and operators by
type and multiple dispatch, not by branching on strings. Write kernels with
JACC, not CUDA alone. Do not change public APIs.

## Gauge groups

JuliaQCD v1 provides SU(Nc) and U(1) only. For any other group, or before
changing the group of existing code, read `references/groups.md`. It explains
the three kinds of representation (complex, real, pseudo-real), what each
changes in the physics and in the code, and pitfalls that have produced wrong
answers.

`scripts/GaugeGroups.jl` is a reference implementation of SU(N), SO(N),
Sp(2N), and G₂ that uses only the Julia standard library. It is the oracle
for testing production code, not production code.

Run the checks:

```
julia scripts/check_group.jl SU 3     # or SO 5, Sp 4, G2, all
julia scripts/selftest.jl             # all groups pass, broken groups fail
```

Each check prints PASS or FAIL, and the exit code is nonzero on failure. The
checks cover the generators (count, normalization, closure), the exponential
map, membership, projection (idempotent, nearest, stable), and Haar random
elements, including the Frobenius–Schur indicator that confirms the declared
kind of representation. The full self-test takes about a minute on a laptop.

To add a group, follow "Adding a group" in `references/groups.md`.

## Planned

- Lattice-level tests: gauge invariance under random gauge transformations,
  analytic force against finite differences and Enzyme, HMC reversibility,
  ΔH scaling with the step size squared, ⟨exp(−ΔH)⟩ = 1, known values (free
  field, strong coupling, published plaquettes), agreement between serial,
  threaded, GPU, and two-rank MPI runs with the same seed, regression.
- Heat bath for groups other than SU(N), with the ergodicity check on the
  subgroups.
- New actions through Wilsonloop, new flows through the existing flow
  interface, new smearings through the common iterative smearing API.
