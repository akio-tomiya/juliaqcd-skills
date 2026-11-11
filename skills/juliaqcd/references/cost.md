# Measured cost of the scripts

Read this to answer "how long" or "how much memory" before a trial has
run. The numbers below were measured by this skill set; anything else is
general knowledge and is not quoted.

How to use them: take the closest row, scale the seconds per trajectory by
the ratio of volumes and of `steps`, multiply by the number of
trajectories, and write the arithmetic in one line, for example "0.14 s ×
(16⁴/8⁴ = 16) × 1000 = about 40 minutes". For `steps`, use the user's
value; otherwise scale the row's `steps` by the fourth root of the volume
ratio (`juliaqcd-generate`, step 4: 10 steps on 16⁴ become about 20 on
32⁴) and write that factor in the same line. Take no number of steps from
memory; tuning sets the final value. Say that it is an estimate from
one core of an Apple M4 and that the trial on the user's machine replaces
it. After the trial, report the measured value next to the estimate.

Measured on one core of an Apple M4 (`threads = 1`), Julia 1.11.9,
Gaugefields 1.1.13, LatticeDiracOperators 1.1.6, QCDMeasurements 1.0.2,
2026-11-11. Seconds per trajectory from `history.csv` (column `seconds`),
leaving out the first trajectory, which includes compilation (8 to 30
seconds). Memory is the peak resident size of the whole process,
compilation included. Trajectory length 1, cold start, `q_every=0`.

| Script | Group, lattice | Parameters | steps | s per trajectory | Peak memory |
|---|---|---|---|---|---|
| `hmc_puregauge.jl` | SU(3), 4³×8 | β = 5.7 | 10 | 0.028 | |
| `hmc_puregauge.jl` | SU(3), 8⁴ | β = 6.0 | 10 | 0.14 | 1.6 GB |
| `hmc_puregauge.jl` | SU(3), 16⁴ | β = 6.0 | 10 | 2.0 | 2.6 GB |
| `hmc_wilson.jl` | SU(3), 4³×8 | β = 5.7, κ = 0.12, c_SW = 1.5, stout ρ = 0.1 × 2 | 10 | 1.65 | |
| `hmc_wilson.jl` | SU(3), 8⁴ | β = 5.6, κ = 0.12, Wilson | 10 | 3.5 | 2.0 GB |
| `hmc_wilson.jl` | SU(3), 8⁴ | β = 5.6, κ = 0.15, Wilson | 10 | 4.8 | 2.0 GB |
| `hmc_wilson.jl` | SU(3), 8⁴ | β = 5.6, κ = 0.12, c_SW = 1.5, stout ρ = 0.1 × 2 | 10 | 8.0 | 2.7 GB |

The Nf = 2 rows on 8⁴ were timing runs: `steps = 10` was not tuned, and
most trajectories were rejected, which does not change the time.

How the time scales:

- Pure gauge: in proportion to the volume and to `steps`, once the lattice
  is 8⁴ or larger (from 8⁴ to 16⁴ the time grew 14 times for 16 times the
  volume; below 8⁴ fixed costs dominate). The time hardly depends on β.
  Other groups were not timed here; the link products grow roughly as N³.
- Nf = 2: in proportion to the volume, to `steps`, and to the number of
  solver iterations, which grows as κ approaches its critical value and
  as the volume grows; from κ = 0.12 to 0.15 at β = 5.6 on 8⁴ the time grew 1.4 times. Clover and stout smearing add a fixed
  factor (clover with two stout steps took 2.3 times plain Wilson on 8⁴). An estimate for a lighter quark or a larger lattice
  than the table is a lower bound: say so, and let the trial decide.
- Memory: one SU(N) link field in d dimensions is d × V × N² × 16 bytes,
  and a pure-gauge run keeps about ten (SU(3) in 4D: 38 MB on 16⁴, 0.6 GB
  on 32⁴), plus about 1.5 GB for Julia and compilation. Fermion runs keep
  more fields; scale the measured peak above the 1.5 GB base by the volume.
- Disk: one checkpoint is one link field, written every `save_every`
  trajectories (default 50).
- The `steps` of a production run come from tuning (about 100
  trajectories after thermalization); count them in the budget.
