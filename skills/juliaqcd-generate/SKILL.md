---
name: juliaqcd-generate
description: "Generate gauge configurations with JuliaQCD (pure-gauge HMC with the Wilson action for SU(N) in 2, 3, or 4 dimensions) and monitor their quality: thermalization, acceptance, <exp(-dH)>, autocorrelation time by the Gamma method, topology freezing. Use when the user wants an ensemble, asks whether a run is healthy, or wants checkpoints and restarts."
---

# juliaqcd-generate

Status: pure-gauge HMC (Wilson action, SU(N), 2 to 4 dimensions) is written
and tested. Dynamical fermions, heat bath runs, and improved actions are not
written yet: `hmc_puregauge.jl` has no `action=` argument, and a β meant for
the Iwasaki or Symanzik action would silently give a Wilson ensemble at a
different coupling. For another action see `juliaqcd-extend`; for dynamical
fermions, LatticeQCD.jl (see the entry skill, "Requests outside what is
tested here").

Paths: `env` and `runs/` are in the user's project folder and `$SKILLS` is
the plugin's `skills` folder (entry skill, "Where files go").

## Workflow

1. Fill in the settings table. Group, dimension, lattice, β, and the
   number of trajectories come from the user; ask for any that is missing,
   and do not guess them (`hmc_puregauge.jl` stops if one is absent). Ask
   whether the number includes thermalization. The action is the Wilson
   plaquette action, the only one here: say so in the table. Trajectory
   length (default 1), steps, seed, start (default cold), and the length of
   a short cost-measurement trial (about 100 trajectories) may be defaults,
   marked as such; the production length is the user's. Boundary
   conditions are periodic: `hmc_puregauge.jl` has no other option, so
   say so in the table. The checks in step 3 do not need the production β
   and can run while waiting for the answer.
2. Set up an environment once, in the project folder, and keep its
   Manifest.toml with the results:
   ```
   julia --project=env -e 'using Pkg; Pkg.add(["Gaugefields", "JACC", "QCDMeasurements", "LatticeDiracOperators", "StableRNGs", "JLD2", "Wilsonloop"])'
   ```
   Then check the versions against `juliaqcd/references/feature-map.md`
   (`julia --project=env -e 'using Pkg; Pkg.status()'`).
3. Run the checks on a small lattice with the same group and dimension:
   ```
   julia --project=env $SKILLS/juliaqcd-generate/scripts/check_hmc.jl colors=3 lattice=4,4,4,4
   ```
   For other cases give the group and a small lattice of the same
   dimension, for example `colors=2 lattice=4,4,4` or `colors=2
   lattice=8,8`. Every line must say PASS. See "What the checks test"
   below. It writes a few small JLD2 files to `workdir=` (default: a new
   temporary directory). About 2 minutes and 1.5 GB for 4⁴ SU(3); on a
   laptop, ask first (entry skill, "Which machine").
4. Measure the cost with `hmc_puregauge.jl` at the production β: about 10
   trajectories on the production lattice give the seconds per trajectory
   (recorded in `history.csv`) and the memory directly; extrapolate from a
   smaller lattice only when even that is too long (the time hardly
   depends on β, the acceptance does). Tuning `steps` takes about 100
   trajectories after thermalization; count them in the budget. The cost per trajectory grows roughly in
   proportion to the volume and to the number of steps; memory grows with
   the volume (one SU(N) link field in d dimensions is d × V × N² × 16
   bytes, and the run keeps about ten such fields). Show the user hours,
   memory, disk (one checkpoint is one link field, written every
   `save_every` trajectories, default 50), and the number of
   configurations, and get approval before the production run. For a
   production ensemble, propose the cold and hot pair of step 6 and let the
   user decide; the estimate then covers both.
5. Production run, on a workstation or cluster node:
   ```
   julia --project=env $SKILLS/juliaqcd-generate/scripts/hmc_puregauge.jl \
       out=runs/NAME colors=3 lattice=16,16,16,32 beta=BETA ntraj=NTRAJ \
       steps=STEPS seed=1234
   ```
   BETA and NTRAJ come from the user. Run it detached with a log (for
   example `nohup ... > runs/NAME.log 2>&1 &`) on a machine that will not
   sleep; if it stops, `restart=true` continues it. The script refuses to write into an
   existing directory. To continue a run, repeat the same arguments with
   `restart=true` and a larger `ntraj`; the restarted chain is identical to
   an uninterrupted one (checked on 300 trajectories).

   Choosing `steps`: rms ΔH grows like √V δτ², so when the volume grows by
   a factor f, multiply the number of steps by about f^(1/4) to keep the
   acceptance. Measured with τ = 1 and 20 steps: acceptance 0.96 on 4⁴
   SU(3) at β = 5.67, and 0.98 on 4³ SU(4) at β = 10.08, more than needed
   on such small lattices. For 16³×32 (f = 512) the rule gives about
   20 × 512^(1/4) ≈ 95 steps as a starting point. Aim for 0.7 to 0.9 and
   adjust after a short run.

   Far from equilibrium the force is large, so a hot start can need more
   steps than the equilibrium run. Measured on 6⁴ SU(3) at β = 5.7: a hot
   start with 20 steps accepted none of 400 trajectories (ΔH ≈ 7.5) and
   never left its start; a cold start with 30 steps had acceptance 0.94.
   The monitor reports a stuck chain as FAIL ("chain moves"). The default
   start is cold for this reason; a hot start needs more steps while it
   thermalizes.

   `q_every` (default 10 in 4D) flows a copy of the configuration to
   measure Q. It costs time; set `q_every=0` when Q is not wanted, for
   example in a β scan at small N_t.
6. Check the run before measuring anything:
   ```
   julia $SKILLS/juliaqcd-generate/scripts/monitor.jl runs/NAME
   ```
   Report every WARN to the user with its suggested action. A FAIL means the
   ensemble is wrong; do not measure on it.

   The halves test in the monitor can pass while a slow mode is still
   drifting (for example near a phase transition, or at large N). For a
   production ensemble, also run one chain from a cold start and one from a
   hot start with different seeds, and check that the plaquette (and Q in
   4D) agree after the cut.

## What a run writes

`runs/NAME/` holds `meta.toml` (parameters, versions, host), a copy of the
`Manifest.toml`, `checkpoints/conf_NNNNNN.jld2`, `state.toml` for restart,
and `history.csv` with one line per trajectory:

| Column | Meaning |
|---|---|
| `traj`, `dH`, `exp_minus_dH`, `accepted` | HMC bookkeeping |
| `plaquette` | `measure_plaquette`, normalized: 1 on a cold field, average over all d(d−1)/2 planes |
| `polyakov_re`, `polyakov_im` | `measure_polyakov_loop`: the loop along the last direction, trace divided by N |
| `Q` | clover Q after a flow of `flow_time`, every `q_every` trajectories (4D); NaN otherwise |
| `seconds` | wall time of the trajectory |

The Polyakov loop is recorded but no check here tests it. For a
deconfinement study take |P| (its average over Z(N) sectors is zero on a
finite lattice), one run per β with `q_every=0`, check each run with the
monitor, and treat the susceptibility and the peak position as glue code
(entry skill, "Requests outside what is tested here").

## Low acceptance

Check, in this order:

1. Is the acceptance counted after thermalization? A hot start accepts
   little until it thermalizes.
2. Is `steps` scaled with the volume (the f^(1/4) rule above)? This is the
   usual cause.
3. In the user's own HMC code: the action coefficient (β/2 with plaquettes
   and their adjoints), the momentum width and `momentum_denominator`
   changed together, a symmetric integrator (QPQ), Metropolis with
   exp(−ΔH). See "Conventions that cause silent errors".
4. ⟨exp(−ΔH)⟩ = 1 and rms ΔH ∝ δτ²: if either fails, there is a bug, and
   more steps only hide it.

`check_hmc.jl` tests the HMC of this skill, not the user's code. To check a
user's own script, run it at the β values of the checks (β = 0, strong
coupling, weak coupling) and compare its plaquette with `check_hmc.jl`'s
numbers, or move the user to `hmc_puregauge.jl`. `monitor.jl` reads the
`history.csv` columns above; a log from another script can be converted
to that header (glue code), leaving `Q` as NaN if it is absent.

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
