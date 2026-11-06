---
name: juliaqcd-measure
description: "Measure observables on JuliaQCD gauge configurations and get numbers with errors: Wilson loops, the static potential and Creutz ratios, the gradient flow with t0, w0, and the topological charge (SU(N) in 2, 3, or 4 dimensions), and quenched Wilson or Wilson-clover meson correlators with effective masses (four dimensions). Every measurement is checked against an independent reference implementation. Use when the user has configurations (for example from juliaqcd-generate) and wants t0, w0, a lattice spacing, the potential, Q, a pion or other meson correlator, or an effective mass. Dirac eigenvalues are planned."
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

Quenched means the configurations come from the pure-gauge action: the
valence quarks see no sea quarks. Say so when reporting meson masses.

## Workflow

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
   julia --project=env scripts/check_measure.jl colors=3 lattice=4,4,4,4
   ```
   Every line must say PASS. About 25 seconds and 1.7 GB for 4⁴ SU(3) on
   one core, most of it compilation. The environment is the one of
   `juliaqcd-generate` (it includes `Wilsonloop`). Copy the whole `skills` folder when moving the scripts; they load files
   from `juliaqcd-generate` and `juliaqcd-extend`.
3. Measure the cost on a few configurations with `stride=` (every n-th
   configuration), for example `stride=40`. `measure_ensemble.jl` prints
   the seconds per configuration; the first one includes compilation. The
   flow dominates. Its cost grows with the volume times the number of flow
   steps, and the default flow range grows like L², so the cost per
   configuration grows roughly like L^(d+2). Measured on one Apple M4
   core for 6⁴ SU(3): 2.7 s per configuration with the default flow range
   (t ≤ 1.16), 5.6 s with the flow to t = 2.5. Measuring a whole ensemble
   is a production run in the sense of the entry skill: show the user the
   total time and ask before starting, unless it is a few minutes.
4. Measure, on a workstation or cluster node:
   ```
   julia --project=env scripts/measure_ensemble.jl run=runs/NAME
   ```
   Options are listed at the top of the script. It writes only to
   `runs/NAME/measure/` and does not touch the configurations. It skips
   configurations already measured, so it can be run again while the chain
   continues, or after the trial with `stride=`; the rows then come out of
   trajectory order, which the analysis handles. A second call with
   different measurement parameters stops instead of mixing them.
5. Analyze (standard library only, runs anywhere the files are):
   ```
   julia scripts/analyze_ensemble.jl runs/NAME
   julia scripts/analyze_ensemble.jl runs/NAME sqrt_t0_fm=VALUE
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
   stops without them). Fermion boundary phases are periodic in space and
   antiperiodic in time; QCDMeasurements 1.0.1 accepts nothing else.
   Quenched Wilson quarks have exceptional configurations near κ_c (for
   example κ_c ≈ 0.169 at β = 5.7 and 0.157 at β = 6.0 in the
   literature); stay well below κ_c unless the user knows the ensemble.
2. Checks, with the same number of colors:
   ```
   julia --project=env scripts/check_fermion.jl colors=3 lattice=4,4,4,6
   ```
   Every line must say PASS. About 35 seconds and 1.8 GB for SU(3) on one
   core. The environment needs `LatticeDiracOperators` as a direct
   dependency; the environment command of `juliaqcd-generate` includes it,
   and an older environment needs `Pkg.add("LatticeDiracOperators")`.
3. Cost trial with `stride=`. Measured on one Apple M4 core: 2.7 s per
   configuration for 6⁴ SU(3), Wilson, κ = 0.15, five channels (12
   solves). The cost grows with the volume and with 1/(κ_c − κ).
4. Measure:
   ```
   julia --project=env scripts/measure_mesons.jl run=runs/NAME kappa=0.150 csw=0
   ```
   Output goes to `runs/NAME/measure/mesons_kappa0.15_csw0.0/` (the folder
   name can be set with `name=`; `mesons.csv`, and
   `solver.csv` with the source and the true solver residual of each
   configuration). The source moves from configuration to configuration by
   a fixed rule, which lowers the autocorrelation.
5. Analyze:
   ```
   julia scripts/analyze_mesons.jl runs/NAME
   ```
   It folds C(Δt) with C(L₄ − Δt), averages the spatial directions of the
   vector and axial channels, and prints the cosh effective mass with a
   binned jackknife, a bin-size table, and WARN lines (no plateau, capped
   bin, exceptional configurations, large residuals, m_π L < 4). There is
   no fit. When m_eff has no plateau, the last value is an upper estimate
   of the mass; say so, and do not quote it as the mass.

   Example (6⁴ SU(3), β = 5.7, the ensemble above, Wilson κ = 0.150, 90
   configurations): m_eff of the pion falls 2.28, 1.53, 1.33 over Δt = 0,
   1, 2, with a WARN that there is no plateau. With L₄ = 6 the excited
   states have not died out; this lattice is far too short in time for a
   meson mass.

Run `monitor.jl` from `juliaqcd-generate` first. Do not measure on a run
whose monitor says FAIL. Its WARN on the topological charge concerns the
flow time used during generation and does not affect t0, w0, or the
potential. Its count of independent plaquette values does not measure the
statistics of t0 either: in the example above τ_int of t²E was about 38
trajectories, more than twice that of the plaquette.

## Definitions and conventions

| Quantity | Definition used here |
|---|---|
| W(R,T) | R steps in each direction μ < d, T steps in the last direction d, averaged over sites and μ; Re tr / N, so 1 on a cold field |
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
- Errors are jackknife errors over bins of 4 τ_int consecutive
  configurations, with τ_int from the Γ method on t²E near t0 (or on
  W(1,1)). The error of `estimate_flow_scales` is leave-one-out without
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
