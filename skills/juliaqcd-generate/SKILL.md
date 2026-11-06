---
name: juliaqcd-generate
description: "Generate gauge configurations with JuliaQCD (pure-gauge HMC with the Wilson action for SU(N) in 2, 3, or 4 dimensions) and monitor their quality: thermalization, acceptance, <exp(-dH)>, autocorrelation time by the Gamma method, topology freezing. Use when the user wants an ensemble, asks whether a run is healthy, or wants checkpoints and restarts."
---

# juliaqcd-generate

Status: pure-gauge HMC (Wilson action, SU(N), 2 to 4 dimensions) is written
and tested. Dynamical fermions, heat bath runs, and improved actions are not
written yet.

## Workflow

1. Fill in the settings table. Group, dimension, lattice, β, and the
   number of trajectories come from the user; ask for any that is missing,
   and do not guess them (`hmc_puregauge.jl` stops if one is absent).
   Trajectory length (default 1), steps, seed, start (default hot), and the
   length of a short cost-measurement trial (about 100 trajectories) may be
   defaults, marked as such; the production length is the user's. Boundary
   conditions are periodic: `hmc_puregauge.jl` has no other option, so
   say so in the table. The checks in step 3 do not need the production β
   and can run while waiting for the answer.
2. Set up an environment once and keep its Manifest.toml with the results:
   ```
   julia --project=env -e 'using Pkg; Pkg.add(["Gaugefields", "JACC", "QCDMeasurements", "StableRNGs", "JLD2", "Wilsonloop"])'
   ```
3. Run the checks on a small lattice with the same group and dimension:
   ```
   julia --project=env scripts/check_hmc.jl colors=3 lattice=4,4,4,4
   ```
   Every line must say PASS. See "What the checks test" below. Copy the
   whole `skills` folder when moving the scripts: `check_hmc.jl` loads
   `juliaqcd-extend/scripts/GaugeGroups.jl`. It writes a few small JLD2
   files to `workdir=` (default: a new temporary directory).
4. Measure the cost on a small lattice with `hmc_puregauge.jl` at the
   production β (it records seconds per trajectory; the time hardly depends
   on β, the acceptance does). The cost per trajectory grows roughly in
   proportion to the volume and to the number of steps; memory grows with
   the volume (one SU(N) link field in d dimensions is d × V × N² × 16
   bytes, and the run keeps about ten such fields). Show the user hours, memory, disk (one checkpoint
   is one link field), and the number of configurations, and get approval
   before the production run.
5. Production run, on a workstation or cluster node, not on a laptop:
   ```
   julia --project=env scripts/hmc_puregauge.jl out=runs/NAME colors=3 \
       lattice=16,16,16,32 beta=6.0 ntraj=2000 steps=40 seed=1234
   ```
   The script refuses to write into an existing directory. To continue a
   run, repeat the same arguments with `restart=true` and a larger `ntraj`;
   the restarted chain is identical to an uninterrupted one (checked on 300
   trajectories).

   Choosing `steps`: rms ΔH grows like √V δτ², so when the volume grows by
   a factor f, multiply the number of steps by about f^(1/4) to keep the
   acceptance. Measured with τ = 1 and 20 steps: acceptance 0.96 on 4⁴
   SU(3) at β = 5.67, and 0.98 on 4³ SU(4) at β = 10.08, more than needed
   on such small lattices. Aim for 0.7 to 0.9 and adjust after a short run.

   Far from equilibrium the force is large, so a hot start can need more
   steps than the equilibrium run. Measured on 6⁴ SU(3) at β = 5.7: a hot
   start with 20 steps accepted none of 400 trajectories (ΔH ≈ 7.5) and
   never left its start; a cold start with 30 steps had acceptance 0.94.
   The monitor reports a stuck chain as FAIL ("chain moves"). Start cold,
   or thermalize with more steps.
6. Check the run before measuring anything:
   ```
   julia scripts/monitor.jl runs/NAME
   ```
   Report every WARN to the user with its suggested action. A FAIL means the
   ensemble is wrong; do not measure on it.

   The halves test in the monitor can pass while a slow mode is still
   drifting (for example near a phase transition, or at large N). For a
   production ensemble, also run one chain from a cold start and one from a
   hot start with different seeds, and check that the plaquette (and Q in
   4D) agree after the cut.

## Conventions that cause silent errors

- Wilson action. `push!(action, β/2, plaquettes)` with the plaquettes and
  their adjoints, and the MD potential −Re(evaluate_GaugeAction)/N, give
  S = β Σ (1 − Re tr P / N). Using β instead of β/2 doubles the coupling;
  the strong- and weak-coupling checks catch this.
- Momentum normalization. The Gaugefields default is width 1 with kinetic
  term p²/2. The Grid and Bridge++ convention is width √2 with
  `momentum_denominator=2`. Change both together or neither. Changing only
  the width to √2 is, after rescaling the MD time by √2, HMC at β/2: the
  acceptance and ⟨exp(−ΔH)⟩ look healthy, and only the strong- and
  weak-coupling checks reveal it (the plaquette moves to its β/2 value).
  The trajectory lengths differ by √2 between the two conventions.
- Random streams. `hmc_puregauge.jl` uses the hot-start seed `seed`, the
  momentum seed `seed + 1` with `sweep = trajectory`, and a Metropolis
  uniform that depends only on (seed, trajectory). Record the seed with the
  results.
- Groups. JuliaQCD v1 provides SU(N) and, in two dimensions, U(1). For SO(N),
  Sp(2N), G₂, or any other group, go to `juliaqcd-extend`.

## What the checks test

`check_hmc.jl` runs on the lattice you give it:

| Check | What a failure means |
|---|---|
| Reversibility: +τ then −τ returns U and H | integrator not symmetric, or state leaks between steps |
| rms ΔH ∝ δτ² (slope 2 ± 0.2) | force is not the gradient of the action, or integrator order is wrong |
| Every link in SU(N) after the run | exponential map or reunitarization broken |
| ⟨exp(−ΔH)⟩ = 1 | energy not conserved in a way the Metropolis step cannot fix (for example a non-symmetric integrator) |
| β = 0: ⟨P⟩ = 0 | measurement normalization |
| Strong coupling: ⟨P⟩ = u(β), the one-link integral computed by Haar Monte Carlo | coupling or action normalization, inconsistent momentum normalization |
| Weak coupling: 1 − ⟨P⟩ = (N² − 1)/(dβ) within 10 % | the same, and dimension handling |

A green acceptance rate and ⟨exp(−ΔH)⟩ = 1 do not show that the chain
samples the intended β; only the known values do.

`selftest_hmc.jl` runs `check_hmc.jl` on three deliberately broken setups
(β doubled, a first-order non-symmetric integrator, momentum width changed
alone) and confirms each is caught; run it after changing the checks.
`selftest_monitor.jl` does the same for `monitor.jl` on synthetic histories.

For 4⁴ SU(3), `check_hmc.jl` takes about 2 minutes on one core and about
1.5 GB of memory, most of it compilation.

## What the monitor reports

| Item | PASS when | If not |
|---|---|---|
| chain moves | some trajectory accepted in the second half | the chain is stuck at its start: more steps, or `start=cold` |
| thermalization | after the cut, the two halves agree within 3σ | run longer |
| acceptance | between 0.6 and 0.95 | change `steps` |
| ⟨exp(−ΔH)⟩ = 1 | within 3σ (FAIL beyond 5σ) | find the bug before anything else |
| ⟨ΔH⟩ = ⟨ΔH²⟩/2 | within 3σ | step size too large for the relation, or a bug |
| plaquette | at least 50 independent samples | run longer |
| topological charge (4D) | Q changes and at least 20 independent measurements | frozen: results that depend on topology are unreliable; tell the user before measuring |

Errors and autocorrelation times use the Γ method with automatic windowing
(Wolff, hep-lat/0306017), implemented in `scripts/stats.jl`.
