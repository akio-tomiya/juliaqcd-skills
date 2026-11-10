---
name: juliaqcd-measure
description: "Measure observables on JuliaQCD gauge configurations and get numbers with errors: Wilson loops, the static potential and Creutz ratios, the gradient flow with t0, w0, and the topological charge (SU(N) in 2, 3, or 4 dimensions; t0, w0, and the topological charge in four only), and quenched Wilson or Wilson-clover meson correlators with effective masses (four dimensions). Every measurement is checked against an independent reference implementation. Use when the user has configurations (for example from juliaqcd-generate) and wants the plaquette, t0, w0, a lattice spacing, the potential or string tension, Q, its histogram, or its susceptibility, a pion, rho, or other meson correlator, or an effective mass. Dirac eigenvalues are not tested yet; this skill says how to use the JuliaQCD function."
---

# juliaqcd-measure

Status: on ensembles written by
`juliaqcd-generate/scripts/hmc_puregauge.jl`, written and tested are the
pure-gauge measurements (Wilson loops W(R,T), the effective potential,
Creutz ratios, the Wilson flow with E(t), t0, w0, and the topological
charge after the flow) and quenched meson correlators with Wilson or
Wilson–clover valence quarks (point source, all 16 local channels, any
momentum) with cosh effective masses. Not written yet: fits of correlators,
the PCAC mass, smeared sources, staggered and domain-wall valence quarks,
Dirac eigenvalues, smearing of the spatial links for Wilson loops,
Polyakov-loop correlators, gauge fixing, and reading ILDG files.

Input: the scripts read only run folders written by `hmc_puregauge.jl`
(`meta.toml`, `history.csv`, `checkpoints/conf_N.jld2`). Configurations
from anywhere else (ILDG, NERSC, another code, a dynamical ensemble) go
through `juliaqcd-reproduce` first. Paths: `$SKILLS` is the plugin's
`skills` folder, and `env` and `runs/` are in the user's project folder
(entry skill, "Where files go").

Quenched means the configurations come from the pure-gauge action: the
valence quarks see no sea quarks. Say so when reporting meson masses.

## Workflow

0. Run `julia $SKILLS/juliaqcd-generate/scripts/monitor.jl runs/NAME`
   (light, standard library only). Do not measure on a run whose monitor
   says FAIL, and report its WARN lines. This applies to every measurement
   below, including meson correlators. A run folder made from outside
   configurations (`juliaqcd-reproduce`) has no HMC history: skip this
   step there and use `therm=0` in the analysis.
1. Fill in the settings table: the run directory, what to measure, the
   largest R and T (default half the extent), the flow step (default
   0.01), the largest flow time (default L²/32, where √(8t) reaches half
   the smallest extent L), and the reference value c = 0.3 for t0 and w0.
   A lattice spacing in fm needs the physical value of √t0 (or w0) and its
   source from the user. Pure gauge theory has no experimental scale, so
   the number depends on the convention the user follows; do not supply
   one.
2. Run the checks with the same group and dimension as the ensemble:
   ```
   julia --project=env $SKILLS/juliaqcd-measure/scripts/check_measure.jl colors=3 lattice=4,4,4,4
   ```
   For other cases keep the group and dimension, for example `colors=2
   lattice=4,6` in two dimensions. Every line must say PASS. About 25
   seconds and 1.7 GB for 4⁴ SU(3) on one core, most of it compilation
   (on a laptop, ask first). The environment is the one of
   `juliaqcd-generate` (it includes `Wilsonloop`). Copy the whole `skills`
   folder when moving the scripts; they load files from
   `juliaqcd-generate` and `juliaqcd-extend`.
3. Measure the cost on a few configurations with `stride=` (every n-th
   configuration), for example `stride=40`. `measure_ensemble.jl` prints
   the seconds per configuration; the first one includes compilation. The
   flow dominates. Its cost grows with the volume times the number of flow
   steps, and the default flow range grows like L², so the cost per
   configuration grows roughly like L^(d+2). Measured on one Apple M4
   core for 6⁴ SU(3): 2.7 s per configuration with the default flow range
   (t ≤ 1.16), 5.6 s with the flow to t = 2.5. Turn off what is not
   wanted: `flow=false` for Wilson loops only, `wilson=false` for the flow
   only, and a smaller `flow_tmax` when only t0 is wanted (stop a little
   beyond the t where t²E reaches 0.3, or about 1.5 × t0 for w0). The
   parameters are fixed by the first call, so when t0 is not known yet,
   find it first in a scratch run folder (a copy of `meta.toml`,
   `history.csv`, and one checkpoint) with the default range, then set
   `flow_tmax` for the real run. On large lattices the default range is
   expensive (it grows like L²). Measuring a whole ensemble
   is a production run in the sense of the entry skill: show the user the
   total time and ask before starting, unless it is a few minutes.
4. Measure, on a workstation or cluster node:
   ```
   julia --project=env $SKILLS/juliaqcd-measure/scripts/measure_ensemble.jl run=runs/NAME
   ```
   Options are listed at the top of the script. It writes only to
   `runs/NAME/measure/` and does not touch the configurations. It skips
   configurations already measured, so it can be run again while the chain
   continues, or after the trial with `stride=`; the rows then come out of
   trajectory order, which the analysis handles. A second call with
   different measurement parameters stops instead of mixing them.
5. Analyze (standard library only, runs anywhere the files are):
   ```
   julia $SKILLS/juliaqcd-measure/scripts/analyze_ensemble.jl runs/NAME
   julia $SKILLS/juliaqcd-measure/scripts/analyze_ensemble.jl runs/NAME sqrt_t0_fm=VALUE
   ```
   It drops the thermalization cut of `monitor.jl`, chooses the jackknife
   bin, and prints t0/a², w0/a, √(8t0)/a, the topological charge, W(R,T),
   a V(R) by T, and the Creutz ratios, each with a table of the result
   against the bin size. Report every WARN line. If the error still grows
   with the bin, the ensemble is too short. The bin is capped so that at
   least 20 bins remain, and a WARN says when the cap made the errors too
   small. In that case quote the error from the largest bin in the table,
   say that it rests on few bins, and recommend a longer chain.
   `bin=N` writes `results_binN.toml` and leaves `results.toml` as it is.

   The script gives a V(R) at each T and does not fit it. When a V(R)
   still changes with T at the largest T (a WARN says so), the last value
   is only an upper estimate of the static potential, and a fit of V(R),
   r0, or σ from it is not meaningful; tell the user that this needs
   larger T or smeared spatial links, which this skill does not have yet.
   A Creutz ratio at small R is not the string tension either.

   Two dimensions are different: the Wilson action gives W(R,T) = u(β)^(RT)
   in infinite volume, so σa² = −log u(β) exactly, with no Coulomb term and
   no excited states, and every Creutz ratio and every a V(R) equals it.
   `check_area_law.jl colors=N beta=B` prints u(β) from the Bessel formula;
   compare the measured Creutz ratios with −log u. On a periodic L × T
   lattice large loops get finite-volume corrections (the complement of
   the loop, of area LT − RT, also contributes), so keep RT well below LT/2.

   Example of a full run (6⁴ SU(3), β = 5.7, cold start, 600 trajectories,
   90 configurations after the cut, default flow range): t0/a² = 1.037 ±
   0.048 (clover E) and 0.704 ± 0.048 (plaquette E), w0/a = 1.010 ±
   0.032; with bin 16, t0/a² = 1.03 ± 0.10. The script warned that the bin
   was capped (4 τ_int = 31 configurations), that √(8t0) = 2.9a exceeds a
   quarter of L, that the two forms of E give t0 differing by 32%, and
   that a V(R) has no plateau at T ≤ 2. All four are correct: this lattice
   is too small, too coarse, and too short in T for a scale or a
   potential.

## Meson correlators (quenched, four dimensions)

The same five steps, with these scripts. Conventions, traps, and what each
check tests are in `references/mesons.md`; read it before comparing with
another code or a paper.

1. Settings table: the run directory, κ, c_SW (0 for the unimproved Wilson
   operator), the channels, the momenta, and the source rule. κ and c_SW
   are physics parameters: ask, never fill them in (`measure_mesons.jl`
   stops without them). For c_SW the user chooses the prescription (tree
   level 1, tadpole-improved, or a nonperturbative formula, which is fitted
   only over a range of β); for κ, quenched Wilson-type quarks have
   exceptional configurations near κ_c, which depends on β and c_SW. Take
   both from the user or a paper they name (entry skill, "Values from the
   literature"). Fermion boundary phases are periodic in space and
   antiperiodic in time; QCDMeasurements 1.0.1 accepts nothing else.
   Channel names: the pion is `pseudoscalar`, the rho is `vector_1`,
   `vector_2`, `vector_3` (averaged by the analysis), and `axial_4` is the
   one the PCAC relation uses; all 16 are in `references/mesons.md`.
2. Checks, with the same number of colors:
   ```
   julia --project=env $SKILLS/juliaqcd-measure/scripts/check_fermion.jl colors=3 lattice=4,4,4,6
   ```
   Every line must say PASS. About 35 seconds and 1.8 GB for SU(3) on one
   core. The environment needs `LatticeDiracOperators` as a direct
   dependency; the environment command of `juliaqcd-generate` includes it,
   and an older environment needs `Pkg.add("LatticeDiracOperators")`.
3. Cost trial with `stride=`. Measured on one Apple M4 core: 2.7 s per
   configuration for 6⁴ SU(3), Wilson, κ = 0.15, five channels (12
   solves). The cost grows with the volume and with 1/(κ_c − κ). The
   clover term adds little per solve; measure it with the trial.
4. Measure:
   ```
   julia --project=env $SKILLS/juliaqcd-measure/scripts/measure_mesons.jl run=runs/NAME kappa=KAPPA csw=CSW
   ```
   Output goes to `runs/NAME/measure/mesons_kappa<κ>_csw<c_SW>/`; with
   `name=k015` it goes to `measure/mesons_k015/` instead. The folder
   holds `meta.toml`, `mesons.csv` (traj, channel, n1, n2, n3, dt, re, im),
   and
   `solver.csv` with the source and the true solver residual of each
   configuration). The source moves from configuration to configuration by
   a fixed rule, which lowers the autocorrelation.
5. Analyze:
   ```
   julia $SKILLS/juliaqcd-measure/scripts/analyze_mesons.jl runs/NAME name=k015
   ```
   `name=` may be left out when the run has a single `mesons_*` folder; it
   accepts `k015` or `mesons_k015`. It writes `results.toml` in that folder.
   It folds C(Δt) with C(L₄ − Δt), averages the spatial directions of the
   vector and axial channels, and prints the cosh effective mass with a
   binned jackknife, a bin-size table, and WARN lines (no plateau, capped
   bin, exceptional configurations, large residuals, m_π L < 4). There is
   no fit. When m_eff has no plateau, the last value is an upper estimate
   of the mass; say so, and do not quote it as the mass. When the user asks
   for "the mass", give the plateau value of m_eff with its error and the Δt
   range, say that no fit was made, and offer a fit only as glue code
   (`juliaqcd-analyze`).

   Example (6⁴ SU(3), β = 5.7, the ensemble above, Wilson κ = 0.150, 90
   configurations): m_eff of the pion falls 2.28, 1.53, 1.33 over Δt = 0,
   1, 2, with a WARN that there is no plateau. With L₄ = 6 the excited
   states have not died out; this lattice is far too short in time for a
   meson mass.

About step 0: the monitor's WARN on the topological charge concerns the
flow time used during generation and does not affect t0, w0, or the
potential. Its count of independent plaquette values does not measure the
statistics of t0 either: in the example above τ_int of t²E was about 38
trajectories, more than twice that of the plaquette.

## Topological charge: histogram and susceptibility

`analyze_ensemble.jl` prints ⟨Q⟩ and ⟨Q²⟩ (Γ-method errors) at the largest
flow time, the fraction of configurations within 0.2 of an integer, and the
number of changes; it warns when Q never changes. It does not make a
histogram or a susceptibility. For those, write glue code on
`measure/flow.csv` (entry skill, "Requests outside what is tested here"):

- Ask at which flow time to take Q and which definition (`Q_clover` or
  `Q_improved`); show how the result moves between two flow times.
  Q is close to integers only once √(8t) is several lattice spacings.
- χ_t = (⟨Q²⟩ − ⟨Q⟩²)/V in lattice units; t0²χ_t needs t0 from the same
  configurations, with the same bins in one jackknife.
- A histogram: count configurations per bin of Q, with jackknife errors
  over blocks of 4 τ_int (τ_int of Q, which is usually much longer than
  that of the plaquette).
- Before any of this, check that topology is not frozen (the monitor and
  the number of changes above).

## Dirac eigenvalues (not tested here)

No script or check here covers them. QCDMeasurements provides
`EigenvalueMeasurement(U; fermiontype="Wilson", κ, nev=10, which=:SM,
isDdagD=false, solver="Arpack", BoundaryCondition)`; `measure(m, U)` builds
D as a sparse matrix and calls Arpack `eigs`. Things to settle with the
user and to check (read the installed source for the version in use):

- κ has a default of 1 in the constructor: always pass the user's κ.
- Which spectrum: D itself (complex, `which=:SM` gives the smallest
  magnitudes), D†D (`isDdagD=true`), or the Hermitian γ₅D, which the
  function does not provide.
- How many: `nev`. `solver="exact"` builds a dense matrix of (12V)²
  complex numbers, 39 GB for 8⁴; use it only on tiny lattices.
- Boundary phases: the operator is built with the same path whose
  boundary-condition keyword was found to be ignored for meson correlators
  (`references/mesons.md`); check the phases before relying on a
  non-default choice.
- Check on a small lattice: compare with the dense eigenvalues of
  `scripts/FermionReference.jl` (`dense_matrix` of `apply_dirac`) on a 2⁴
  configuration, and on a cold field with the free spectrum
  (`free_spectrum`).
- What to histogram: Re λ, |λ|, or the complex plane for D; λ for D†D.
  Ask. With `nev` modes from each configuration the histogram covers only
  the low end of the spectrum, up to a cutoff that changes from
  configuration to configuration; show only the range below the smallest
  cutoff, or say where it is truncated.
- Cost: `which=:SM` on a sparse matrix of dimension 12V (49152 for 8⁴) may
  use a factorization; time one configuration first, on a workstation.
- A 2⁴ test field: build it as `check_fermion.jl` does (its rough field and
  the link transfer of `fermion_common.jl`); LatticeDiracOperators works on
  extent 2, as the free-spectrum check of `check_fermion.jl` shows.
- `eigensystem` (LatticeDiracOperators, Sakurai–Sugiura) is meant for
  any operator, including γ₅D and staggered, but it is untested here. In
  1.1.4 (not checked again on 1.1.6) its fixed acceptance threshold can discard correct eigenvalues,
  and it stops for `GeneralFermion` operators. Compare its result with a
  dense diagonalization of a 2⁴ operator before using it.
- A histogram or spectral density with errors is glue code: per-
  configuration counts after the thermalization cut of `monitor.jl`, and
  a binned jackknife over configurations, with the bin from `choose_bin`
  on the series with the longest τ_int (the counts in the lowest bins, or
  the plaquette). Write the data to `runs/NAME/measure/eigen_<label>/`.

## Definitions and conventions

| Quantity | Definition used here |
|---|---|
| plaquette | `plaquette` in `history.csv`: Re tr P / N averaged over all sites and all d(d−1)/2 planes, 1 on a cold field; the same normalization as the PLAQUETTE of a NERSC header. At t = 0, `flow.csv` gives it as 1 − E_plaq/(2N × number of planes) |
| W(R,T) | R steps in each direction μ < d, T steps in the last direction d, averaged over sites and μ; Re tr / N, so 1 on a cold field. W(1,1) averages only the planes that contain the last direction, so it is not the plaquette above |
| a V(R) at T | log W(R,T)/W(R,T+1); the static potential is its limit at large T |
| Creutz ratio χ(R,T) | −log [W(R,T) W(R−1,T−1) / (W(R,T−1) W(R−1,T))]; approaches σa² at large R = T |
| flow | Lüscher's Wilson flow with his third-order Runge–Kutta integrator (arXiv:1006.4518); t is in units of a² |
| E, plaquette form | 2N × (number of planes) × (1 − plaquette) |
| E, clover form | −Σ_{μ<ν} tr F_μν², F = traceless anti-Hermitian part of the clover / 4 |
| t0 | t² ⟨E(t)⟩ = 0.3 (Lüscher); clover E is the main definition |
| w0 | t d/dt (t² ⟨E⟩) = 0.3 at t = w0² (BMW, arXiv:1203.4469) |
| Q | −(1/32π²) Σ_x ε_μνρσ tr F_μν F_ρσ with the clover F; `Q_improved` is the improved density of Alexandrou, Athenodorou, and Jansen, Phys. Rev. D 92 (2015) 125014 |

Conventions that change numbers without an error message:

- t0 and w0 come from the mean of E(t) over configurations, solved once
  (as in `QCDMeasurements.estimate_flow_scales`). Solving on each
  configuration and averaging the solutions gives a different number.
- The clover and plaquette forms of E give different t0 at finite lattice
  spacing. Quote which one, and compare like with like.
- t0 and w0 are four-dimensional definitions. In two and three dimensions
  `analyze_ensemble.jl` prints t²E only.
- The time direction of W(R,T) is the last lattice direction.
- `QCDMeasurements.WilsonLoopMeasurement` works in four dimensions only:
  in two and three dimensions its constructor throws, and its normalization
  assumes three spatial directions. This skill builds the loops from
  `Wilsonline` and `evaluate_gaugelinks!` instead, in any dimension.
- Errors of t0, w0, W, V, and the Creutz ratios are jackknife errors over
  bins of 4 τ_int consecutive configurations, with τ_int from the Γ method
  on t²E near t0 (or on W(1,1)). ⟨Q⟩ and ⟨Q²⟩ use the Γ method directly. The error of `estimate_flow_scales` is leave-one-out without
  bins and is too small for autocorrelated data: by a factor 0.34 in the
  self-test below, where τ_int ≈ 4.5.
- Q at the largest flow time is listed; it is close to integers only once
  √(8t) is several lattice spacings.

## What the checks test

`check_measure.jl` compares every JuliaQCD number with
`scripts/LatticeReference.jl`, an independent implementation on plain
arrays (Julia standard library only), on the same links:

| Check | What a failure means |
|---|---|
| links written to JuliaQCD come back unchanged | the file round trip used by the checks is broken; nothing else can be trusted |
| cold field: W = 1, P = 1, E = 0, Q = 0 | normalization |
| t = 0 equals the reference (plaquette, W(R,T), both E, Q) | normalization, loop shape, or sign |
| gauge invariance at t = 0 under a random gauge transformation | a loop that is not closed, or a wrong link in a path |
| flowed links equal the reference RK3 flow | flow normalization, step size, or integrator |
| E(t), Q(t) along the flow equal the reference | the same, in the measurement wrapper |
| gauge invariance along the flow | flow or measurement not gauge covariant |
| differences of E(t) shrink as ε³ | integrator order |
| the flow lowers the Wilson action monotonically | sign of the flow force |
| links stay in SU(N) after the flow | exponential map |
| t0 and w0 on a synthetic E(t): two implementations and the exact values agree | the analysis code |

`selftest_measure.jl` runs the checks on three broken variants and
confirms each is caught: a Wilson loop with its last side missing (equals
1 on a cold field, so only the reference and gauge invariance see it), a
flow with step 2ε reported as ε (still a monotone third-order flow, so the
reference must see it), and a first-order integrator.
`selftest_analysis.jl` tests the jackknife, the potential, and the Creutz
ratios on synthetic data with known answers, including the bin choice on
autocorrelated data (binned error / true spread = 0.90, unbinned 0.34).

`check_area_law.jl` is an end-to-end check of generation and measurement
together. In two dimensions the Wilson action gives W(R,T) = u(β)^(RT)
exactly, with u the one-link expectation value, computed both from the
Bessel-determinant formula and by Haar Monte Carlo. Measured on 16×16 with
20000 trajectories: SU(2) at β = 4, all nine W(R,T) for R, T ≤ 3 within
1.4σ; SU(3) at β = 6, within 1.7σ. About 30 seconds each.
