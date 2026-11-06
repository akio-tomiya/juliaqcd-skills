# Gauge groups by kind of representation

Read this before adding a gauge group, changing the group of existing code,
or interpreting results that depend on the group (finite density, chiral
symmetry breaking, Dirac spectra).

## Three kinds

The defining representation of a compact gauge group is one of three kinds.
The kind is fixed by the Frobenius–Schur indicator, the Haar average of
tr(U²):

| Kind | Indicator ⟨tr U²⟩ | Conjugate representation | Groups (defining rep) |
|---|---|---|---|
| Complex | 0 | not equivalent | SU(N), N ≥ 3 |
| Real | +1 | equivalent through a symmetric form | SO(N), G₂ |
| Pseudo-real | −1 | equivalent through an antisymmetric form | SU(2), Sp(2N) |

`scripts/check_group.jl` measures the indicator by Monte Carlo and compares
it with the kind the code declares, so a group declared with the wrong kind
fails.

Note on naming: `Sp(n)` in `GaugeGroups.jl` takes the matrix size n = 2N, so
`Sp(4)` is USp(4) (also written Sp(2)). State the convention whenever you
write Sp.

## Center

The center decides whether the Polyakov loop in the defining
representation can be an order parameter for confinement.

| Group | Center |
|---|---|
| SU(N) | Z_N |
| SO(N), N odd | trivial |
| SO(N), N even | Z₂ |
| Sp(2N) | Z₂ |
| G₂ | trivial |

With a trivial center, gluons screen the defining-representation charge,
and the Polyakov loop is nonzero in both phases.

## Which "SO(3)" the user means

"SO(3) gauge theory" can mean different theories. Ask before building
anything.

- Lattice SO(3): real 3×3 orthogonal links and the Wilson action. The
  same theory can be written with SU(2) links and an action in the adjoint
  representation. It has a first-order bulk transition at strong coupling
  (Greensite and Lautrup, Phys. Rev. Lett. 47 (1981) 9; Bhanot and Creutz,
  Phys. Rev. D 24 (1981) 3212), so the continuum limit is on the
  weak-coupling side of it.
- SU(2)/Z₂: SU(2) links with a Z₂ 2-form gauge field. The local dynamics
  are those of SU(2); the global structure (flux sectors, θ periodicity,
  allowed line operators) differs. Gaugefields has Z(N) 2-form fields and a
  dynamical B field for SU(N)/Z(N) in 4D; check its documentation for which
  ensemble it samples before using it for this.
- With fermions in the vector representation of SO(3), which is the
  adjoint representation of SU(2): a new Dirac operator is needed.

The same question arises for SO(N) and SU(N)/Z_N in general.

## What the kind changes in physics

These are textbook statements for fermions in the defining representation.
Cite the standard references when using them in a paper.

- Finite density. For real and pseudo-real representations the Dirac
  operator at nonzero quark chemical potential has an antiunitary symmetry,
  so its determinant is real; with an even number of degenerate flavors it is
  nonnegative and there is no sign problem. For complex representations
  (QCD) the determinant is complex.
- Chiral symmetry breaking with N_f Dirac flavors:
  complex SU(N_f)_L × SU(N_f)_R → SU(N_f)_V;
  pseudo-real SU(2N_f) → Sp(2N_f);
  real SU(2N_f) → SO(2N_f).
  The extra Goldstone bosons in the last two cases are diquarks.
- Baryons. For real and pseudo-real representations a quark pair can form a
  color singlet, so there are diquark baryons (bosons). In G₂ the invariant
  3-form also allows three-quark baryons, and gluons can screen a single
  quark, so there is no exact center symmetry.
- Random matrix class of the Dirac spectrum near zero: complex → chGUE
  (β = 2), pseudo-real → chGOE (β = 1), real → chGSE (β = 4). For staggered
  fermions at finite lattice spacing the classes β = 1 and β = 4 swap. Check
  which applies before comparing spectra.

## What the kind changes in code

| Task | SU(N) | SO(N) | Sp(2N) | G₂ |
|---|---|---|---|---|
| Field type | complex | real | complex | real |
| Membership | U†U = 1, det U = 1 | real, OᵀO = 1, det O = 1 | U†U = 1, UᵀJU = J | real, OᵀO = 1, U⊗U⊗U φ = φ |
| Algebra dimension | N² − 1 | N(N−1)/2 | N(2N+1) | 14 |
| Projection | polar factor, divide by det^(1/N) choosing the root nearest the polar factor | polar factor | no closed form; iterate | no closed form; iterate |
| Haar random element | QR of a complex Gaussian with phase fix, then det fix | QR of a real Gaussian with sign fix, then flip a column if det = −1 | random walk in the group | random walk in the group |
| Heat bath | SU(2) subgroups (Cabibbo–Marinari) | not written yet | not written yet | not written yet |

For any heat bath built from subgroups, the generators of the subgroups must
generate the whole Lie algebra; otherwise the update is not ergodic. Check
this before trusting the update.

## Pitfalls the checks have caught

Each of these produced a wrong answer in a first draft of `GaugeGroups.jl`
and is now covered by `scripts/selftest.jl`.

- SU(N), N ≥ 3: the principal logarithm of U can have tr log U = 2πi m with
  m ≠ 0. Removing the trace and exponentiating gives U times a center element,
  which is a stationary point of the usual projection iteration. Haar samples
  rarely show this, because their eigenvalues repel; test projections also on
  exp(X) with large X.
- Real groups (SO(N), G₂): when U has a pair of eigenvalues −1, the principal
  logarithm is complex, and a start built from it can sit exactly on a saddle
  of Re tr(g†U). Kick the iterate after convergence.
- The Q factor of a QR decomposition is Haar on U(N) or O(N) only after the
  sign or phase fix with diag(R). Without it, the distribution is wrong, and
  for small real matrices det Q can even be always +1.
- A Julia closure that assigns to a variable with the same name as a local in
  the enclosing function overwrites the outer variable. Use `local` inside the
  closure.

## Adding a group

1. Define a subtype of `GaugeGroup` with five methods: `matrix_size`,
   `field_type`, `algebra_dimension`, `repkind`, and `invariant_tensors`.
   Generators, projection, random elements, and the membership test follow
   from these. Override `initial_guess` or `random_element` only when a closed
   form exists.
2. Run `run_checks` on it and get every check to PASS.
3. Add the group to `MUST_PASS` in `selftest.jl`, and add at least one broken
   variant to `MUST_FAIL` that a plausible mistake would produce.
4. Use the reference implementation as the oracle for the production code:
   feed the same matrices to both and compare membership, projection,
   exponential map, and the Haar moments of the production random elements.
   The production kernels belong in a separate package that depends on
   JuliaQCD (see `SKILL.md`).
