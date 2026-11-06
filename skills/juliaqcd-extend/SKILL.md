---
name: juliaqcd-extend
description: "Develop new features on top of JuliaQCD: a new gauge group (including real and pseudo-real groups such as SO(N), Sp(2N), G2), a new action, smearing, Dirac operator, or flow, or a change of group (for example U(1) to SU(N)) or of dimension. Use when the request goes beyond what JuliaQCD v1 or the tested scripts provide (for example HMC with the Iwasaki or Symanzik action), and for questions about a gauge group itself (is a representation real, complex, or pseudo-real; generators; center), which it answers numerically. Reuse existing parts, keep the extension portable, and write tests."
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
map, membership, projection (idempotent, nearest, stable), the invariant
bilinear forms, and Haar random elements, including the Frobenius–Schur
indicator. The scripts need only the Julia standard library (no
`--project`). One group takes 10 to 20 seconds and under 1 GB of memory;
the full self-test takes about a minute. Run from the skill folder, or give
the full path to the script.

To answer "is this group complex, real, or pseudo-real?", report the
measured values, not only PASS: PASS says the result agrees with the kind
the code declares. The line "invariant bilinear forms" is exact (none,
one symmetric, or one antisymmetric form, from the Lie algebra alone), and
the line "Haar: E[tr U^2]" gives the measured indicator with its error.

To add a group, follow "Adding a group" in `references/groups.md`. For
SO(N), first settle which theory the user means (lattice SO(N), SU(N)/Z_N,
or a fermion representation); `references/groups.md` lists the options.

Whether Wilsonloop, the Gaugefields HMC parts, and the QCDMeasurements
normalizations accept real element types is not documented. Test each part
on a small lattice with the reference implementation before putting it in
the table of reusable parts.

When nothing in JuliaQCD can generate the configurations yet (no SO(N)
update exists), the common workflow stops after the settings table and the
plan: present the table of parts, the missing pieces, and the tests the
new code must pass, and ask the user before writing the package.

## Another gauge action (Iwasaki, Symanzik, DBW2)

Gaugefields builds any action from Wilson loops, so this needs
configuration of JuliaQCD, not new physics code; `hmc_puregauge.jl` itself
has only the Wilson action and no `action=` argument. Before writing
anything, settle with the user the normalization, for example
S = β Σ [c0 (1 − Re tr P / N) + c1 (1 − Re tr R / N)] with c0 = 1 − 8 c1,
the value of c1 (from the paper they follow), and the number of
trajectories; the β of an improved action is not comparable with a Wilson
β. Then, in the user's project folder:

- Build the action as `wilson_action` in
  `juliaqcd-generate/scripts/common.jl` does: `make_loops_fromname` with
  `"plaquette"` and `"rectangular"` (Wilsonloop 0.1.5), each appended with
  its adjoint, pushed with its coefficient. Count the loops per site to
  confirm that both orientations of the rectangle are there, and that the
  coefficients follow the β/2 rule of the Wilson case.
- Check on 4⁴: with c1 = 0 the run must reproduce `hmc_puregauge.jl` with
  the same seed trajectory by trajectory; reversibility, rms ΔH ∝ δτ², and
  ⟨exp(−ΔH)⟩ = 1 as in `check_hmc.jl`; β = 0 gives ⟨P⟩ = 0. The strong-
  and weak-coupling values of `check_hmc.jl` hold for the Wilson action
  only; for the improved action compare with a plaquette value from the
  paper the user names.
- To run it, copy `hmc_puregauge.jl` (and `common.jl`) into the user's
  project folder and change only the action, after the user agrees (glue
  code). Keep the `history.csv` header so that `monitor.jl` works, and
  record c1 in `meta.toml`. The reversibility and ΔH checks of
  `check_hmc.jl` test its own action, so repeat them on the copy with a
  small glue script modeled on `check_hmc.jl`.
- An improved action has larger forces (c0 > 1), so start with more MD
  steps than the f^(1/4) rule of `juliaqcd-generate` gives, and tune.
- Report the results as unverified by this skill set.

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
