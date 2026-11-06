# Wilson and Wilson–clover fermions: conventions and checks

For quenched meson correlators with `check_fermion.jl`, `measure_mesons.jl`,
and `analyze_mesons.jl`. Versions checked: LatticeDiracOperators 1.1.4,
QCDMeasurements 1.0.1, LatticeMatrices 1.2.9, Gaugefields 1.1.11.

## Conventions

| Item | JuliaQCD v1 |
|---|---|
| Wilson operator | D = 1 − κ Σ_μ [(r − γ_μ) U_μ(x) δ_{x+μ̂,y} + (r + γ_μ) U_μ(x−μ̂)† δ_{x−μ̂,y}], r = 1 |
| κ and the bare mass | κ = 1/(2 m₀ + 8r); the free massless point is κ = 1/8 |
| γ matrices | chiral basis of Bridge++: γ_k = [0 −iσ_k; iσ_k 0], γ_4 = [0 −1; −1 0], γ_5 = γ_1γ_2γ_3γ_4 |
| clover term | −κ c_SW Σ_{μ<ν} γ_μγ_ν F_μν, F_μν = (Q_μν − Q_μν†)/8 with Q the four-leaf clover. Equal to the Sheikholeslami–Wohlert term −(κ c_SW/2) Σ_{μ,ν} σ_μν F̂_μν with σ_μν = (i/2)[γ_μ, γ_ν] and the Hermitian F̂ = −iF |
| boundary phases | default (1, 1, 1, −1): periodic in space, antiperiodic in time |
| meson correlator | C(Δt, p) = −Σ_x e^{−ip·(x−x₀)} tr[Γ₂ S(x,x₀) γ₄Γ₁†γ₄ γ₅S(x,x₀)†γ₅] over x at Δt from the source; for Γ = γ₅ this is Σ tr[S S†] > 0 |
| channels | scalar 1, pseudoscalar γ₅, vector γ_μ, axial γ_μγ₅, tensor [γ_μ, γ_ν]/2 |

Other codes write the operator differently. Grid uses D = (4 + m) − H/2, so
its correlators are 4κ² times these (the QCDMeasurements README states the
comparison). Before comparing with a paper, check its γ basis, its sign of
the hopping term, and whether κ or m₀ is quoted.

## Traps found while writing the checks

- The boundary phases that act are those stored in the fermion field.
  `Initialize_pseudofermion_fields(U[1], "Wilson"; boundarycondition=...)`
  drops the keyword and always gives (1, 1, 1, −1), and the
  `"boundarycondition"` entry of the operator parameters is not used. No
  error is raised. `fermion_field` in `fermion_common.jl` calls
  `Initialize_WilsonFermion(U[1]; nowing=true, boundarycondition=...)`,
  which does honor it, and checks `x.f.phases`.
- `MesonCorrelatorMeasurement` accepts only the default phases: anything
  else stops with an AssertionError when measured. Antiperiodic time is the
  usual choice, so this rarely matters.
- `eps_CG` bounds the squared residual. With the QCDMeasurements default
  1e-14 the true relative residual is about 1e-7, enough for most
  correlators but visible against a 1e-9 comparison. The scripts here use
  1e-20 (about 1e-10) and record the true residual of every configuration
  in `solver.csv`.
- After changing the links in place, a clover operator built with
  `LatticeMatrices.WilsonDiracCloverOperator4D` must be refreshed with
  `update_clover!`. The scripts build a new measurement for each
  configuration instead.

## What the checks test

`check_fermion.jl` compares JuliaQCD with `scripts/FermionReference.jl`, an
independent implementation on plain arrays (standard library only), on the
same links and spinors:

| Check | What a failure means |
|---|---|
| γ: Clifford algebra, Hermitian, equal to JuliaQCD | the reference uses another basis; nothing below can be compared |
| spinor round trip and boundary phases | the conversion used by the checks is broken, or the field does not carry the phases asked for |
| Wilson / clover: D ψ and D† ψ equal the reference | κ, r, c_SW, sign, γ basis, boundary phase, or the adjoint |
| γ5 D γ5 = D† | the adjoint is wrong (a property every Wilson-type operator must have) |
| gauge covariance | a hop uses the wrong link or the wrong end of it |
| free field: spectrum | compared with 1 − 2κ Σ cos p ± 2iκ (Σ sin² p)^{1/2}; independent of the γ basis |
| free field: pion correlator equals the Fourier sum | the propagator from a momentum-space sum, a different algorithm from the solver |
| 16 channels × 3 momenta equal the reference | contraction, source position, momentum phase, or solver |
| pion correlator positive | C_PP = Σ tr[S S†] cannot be negative |

`selftest_fermion.jl` breaks four things on purpose and confirms the
expected checks fail: periodic instead of antiperiodic time (seen by the
phases, the operator check, and the free spectrum), c_SW halved (seen only by
the reference: γ5-hermiticity and gauge covariance still hold), D used for
D† (seen by the adjoint check and γ5-hermiticity), and the source one site
off (seen only on the rough field: the free field is translation
invariant).

## Not in these scripts yet

Fits of the correlator (a correlated fit with its fit-range dependence
belongs to `juliaqcd-analyze`), the PCAC mass (`PCACMassMeasurement` exists
in QCDMeasurements), smeared sources, disconnected diagrams, staggered and
domain-wall fermions, Dirac eigenvalues, and dynamical fermions.
