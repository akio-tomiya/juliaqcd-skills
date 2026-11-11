---
name: juliaqcd-extend
description: "Develop new features on top of JuliaQCD: a new gauge group (including real and pseudo-real groups such as SO(N), Sp(2N), G2), a new action, smearing, Dirac operator, propagator, or flow, the method of a paper, or a change of group (for example U(1) to SU(N)), of dimension, or of the fermion representation (adjoint, two-index). Use when the request goes beyond what JuliaQCD v1 or the tested scripts provide (for example HMC with the Iwasaki or Symanzik action), and for questions about a gauge group itself (is a representation real, complex, or pseudo-real; generators; center), which it answers numerically. Also use it to check the user's own HMC, force, or operator code (for example a ΔH that does not shrink with the step size). Reuse existing parts, keep the extension portable, and write tests."
---

# juliaqcd-extend

Status: the gauge-group part is written and tested. For actions, smearing,
operators, and flows there is a procedure and a list of required tests
below, but no tested script yet.

## Before writing code

Show the user a table: which existing JuliaQCD parts will be combined, how,
and what is missing. Write new code only for the missing rows. A part that
JuliaQCD already has (a solver, a field type, an integrator, the gauge
action from Wilson loops, the gradient flow, a file reader) is used as it
is, not rewritten. The plain-array implementations of this plugin
(`FermionReference.jl`, `LatticeReference.jl`, `scripts/GaugeGroups.jl`)
belong in the tests only; the new part itself is built on JuliaQCD (for an
operator, on its Wilson operator and fields from LatticeDiracOperators).
When the request comes from a paper, take the parts
from its equations and cite the equation numbers.

Build the missing parts as a separate package that depends on JuliaQCD,
in the user's project folder, before considering a patch to JuliaQCD
itself. Keep them compatible with JuliaQCD so that its other parts work
on them: use its field types, add new groups, operators, and actions as
new types with multiple dispatch (not by branching on strings), follow the
calling conventions of the package being extended (`mul!` for an
operator, its constructors and keyword names), write loops over sites with
JACC (not CUDA alone), and do not change public APIs. Read
`references/development.md` for the package layout, compat, internals,
tests in CI, comparisons with another code, and mistakes agents made.

## Tests for a new part

Write them in the package's `test/` folder, run them on a small lattice
(2⁴ to 4⁴, or the 2D and 3D analogues) before any production use, and
make each one check the new code against something independent of it:

- An implementation with plain arrays or a dense matrix of the whole
  operator, compared entry by entry (as `check_fermion.jl` in
  `juliaqcd-measure` compares Wilson and clover with
  `FermionReference.jl`).
- Symmetries: gauge covariance under a random gauge transformation,
  γ₅-hermiticity or the antisymmetry the operator must have, translation
  invariance, the boundary conditions.
- Known limits: free field (cold configuration) against the analytic
  spectrum, strong coupling, a published number the user names.
- For anything in molecular dynamics: the force against a finite
  difference of the action, reversibility, rms ΔH ∝ δτ², and
  ⟨exp(−ΔH)⟩ = 1, as `check_hmc.jl` does for the Wilson action.
- For a solver or eigenvalue result: the residual computed independently,
  and a dense diagonalization on the smallest lattice.
- A deliberately broken version (a wrong sign, a dropped term, a wrong
  boundary phase) that the tests must catch, as the `selftest_*.jl`
  scripts here do.

Report which tests passed, with their tolerances, and call the result
unverified by this skill set.

## Checking the user's own code

When the user's own HMC, force, or operator misbehaves (for example ΔH
does not shrink as the step size goes down), do not answer from general
knowledge alone. Apply the tests above to their code, in this order, on
the smallest lattice: the trajectory length held fixed while the step size
changes; the force against a central finite difference of the action on a
few links and all generators; reversibility (forward, flip the momenta,
forward again, to rounding); rms ΔH ∝ δτ² and ⟨exp(−ΔH)⟩ = 1.
`check_hmc.jl` in `juliaqcd-generate` shows each test on the Wilson
action and is the model; `scripts/GaugeGroups.jl` gives exact
exponentials and projections to compare with. Name both in the reply, so
the user can copy the tests. Ask for the code and the output before naming
a cause, and report which test fails.

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

## Fermions in another representation

JuliaQCD v1 has fermions in the defining representation only (code map,
`juliaqcd/references/code-map/LatticeDiracOperators.md`, "Fermion in
another representation"; the adjoint code under `deprecated/` is pre-v1, do
not use it). Build the representation as a map of links, so that the
operator, the action, and the force machinery of JuliaQCD are reused:

1. Settle the theory first: the representation (adjoint, two-index
   symmetric or antisymmetric, other), Dirac or Majorana fermions, Nf, and
   whether the representation is complex, real, or pseudo-real
   (`check_group.jl` and `references/groups.md`; for a real representation
   the fermion determinant may be replaced by a Pfaffian, and the sign
   question has to be answered before any algorithm is chosen).
2. Write the map R(U) from defining links to representation links as a
   link-to-link layer, in the user's package (for the adjoint,
   R(U)^{ab} = 2 tr(T^a U T^b U†) with tr(T^a T^b) = δ^{ab}/2, a real
   matrix of size N² − 1). Treat it like a smearing: forward map and a
   pullback of the force to the defining links, following
   `SmearedFermiAction` (LatticeDiracOperators,
   `src/action/NHYPSmearedFermiAction.jl`).
3. Test the map alone before any fermion code, on random SU(N) matrices:
   homomorphism R(UV) = R(U)R(V); R(U†) = R(U)†; R(U) unitary (orthogonal
   for a real representation) of the expected dimension; the character
   (adjoint: tr R(U) = |tr U|² − 1); the center (the adjoint is invariant
   under U → zU, z ∈ Z_N); and the pullback against a finite difference of
   a scalar function of R(U).
4. Build the Wilson operator on the representation links: create the
   fermion field with the representation dimension as the number of colors
   and pass R(U) as the links (the v1 operator takes the links as given).
   Test it as `check_fermion.jl` tests the defining one: against a dense
   matrix built from the reference operator on R(U); γ₅-hermiticity; gauge
   covariance with R(g) acting on the fermion; the free field (R(1) = 1).
5. Then the action and HMC: the force on the defining links against a
   finite difference of S_F, and the checks of `check_hmc_wilson.jl`
   (heat bath, reversibility, rms ΔH ∝ δτ², ⟨exp(−ΔH)⟩ = 1), which can be
   run on the user's action through the same MD interface.

Present the parts table (step 1 of "Before writing code") with these rows,
and build nothing before the user has answered step 1. Report the results
as unverified by this skill set.

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
