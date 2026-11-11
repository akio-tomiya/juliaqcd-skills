# Example prompts

Prompts a new user can type after installing the skills, with what the agent
should do. The "Tested" line of examples 1 to 6 records a run on
2026-11-06, with computations. Examples 7 to 24 were tested on 2026-11-09
for behavior only, in the trigger-test setting described below: the agent
had no shell, so it ran no computation, and its questions went unanswered.
The folder was empty, except in example 18, where it held a made-up
interrupted run (parameters, a history, and placeholder checkpoints).
Examples 25 to 28 were tested on 2026-11-11 for behavior only, with
subagents and an independent grading subagent, as described in
`tests/README.md`. On 2026-11-11 all examples were also run through
`claude -p` (trigger and behavior, no shell, graded by a separate
`claude -p`); all results are listed in `tests/RESULTS.md`.

How they were tested: an agent with no other context was told to act as
Claude Code with this plugin installed, given a copy of the plugin without
this `examples/` folder, and given only the prompt. Computations ran on a
workstation, never on the laptop. This tests what the agent does once the
skill is in use; it does not test whether the skill description triggers
the skill.

Triggering was tested separately on 2026-11-09, in a fresh Claude Code
configuration with only this plugin installed, no user instructions, and
an empty folder. Each prompt was sent once with `claude -p`, with shell
and file-writing tools disabled, and the skills the agent invoked were
recorded. All 17 lattice prompts invoked a `juliaqcd` skill that fits
the request: examples 1 to 6 and eleven others in English and Japanese, such
as a beginner's first step, low HMC acceptance, an error from
`run_wizard()`, ILDG files, the Iwasaki action, GPUs and MPI, and meson
correlators. None of four unrelated prompts (a Python function, building
another lattice QCD library, eigenvalues of a random matrix in Julia, a
general question on lattice QCD) invoked one.

The skills behave the same whatever language you write in. Japanese versions
of the prompts are in `prompts.ja.md`.

## 1. Run pure-gauge HMC and check it

> Run pure-gauge HMC for SU(3) on a 4^4 lattice and check that it works
> correctly.

Expected:
- shows a settings table and marks what it chose by default;
- runs `check_hmc.jl` first and reports each PASS or FAIL;
- runs a short chain with `hmc_puregauge.jl` and reports `monitor.jl`,
  including the thermalization cut and any WARN.

Tested: pass. All seven checks passed (117 s, 1.5 GB on one core). The
prompt gives no β, so the agent stopped before the chain and asked for it
instead of choosing one. Its feedback led to the rule that physics
parameters are always asked and algorithmic ones may be defaults.
`claude -p` run (2026-11-11, behavior only): the Japanese prompt failed
once; the agent planned `check_hmc.jl` but not the short chain. The
generate skill now says the chain and the monitor are the second half of
"does it work"; after that both languages passed.

## 2. A request with a missing parameter

> Run quenched HMC for SU(4) in three dimensions and tell me whether it has
> thermalized.

Expected:
- does not invent β or the lattice size: asks for them, or proposes values
  and labels them as its own proposal;
- runs `check_hmc.jl colors=4` with a 3D lattice before the chain.

Tested: pass. Ran `check_hmc.jl colors=4 lattice=4,4,4` (all seven PASS,
about a minute; strong coupling within 1.1σ, weak-coupling ratio 1.014),
then asked for the lattice size, β, and the number of trajectories instead
of choosing them. Its feedback added the hot-and-cold-start comparison and
the general memory formula to `juliaqcd-generate`.

## 3. Translate old code

> This is from my old script. Make it work with the current JuliaQCD:
> ```julia
> U = Initialize_Gaugefields(3, 0, 4, 4, 4, 4, condition = "hot")
> temps = Temporalfields(U[1], num=2)
> println(calculate_Plaquette(U, temps[1], temps[2]))
> ```

Expected:
- rewrites it with `gauge_configuration` and `measure_plaquette`, starting
  with `import JACC; JACC.@init_backend`;
- runs it on a small lattice to confirm the plaquette of a hot start is
  near 0.

Tested: pass. Translated the code, ran it (hot 0.0025, cold 1.0), and
noticed what the translation table missed: `calculate_Plaquette` returned
the sum (4608 for a cold 4⁴ SU(3) field) while `measure_plaquette` is
normalized, so a name-for-name translation silently changes the number.
The table now says so, with `normalize=false` for the old value.

## 4. A gauge group JuliaQCD does not have

> I want to simulate SO(3) gauge theory with JuliaQCD. What do I need?

Expected:
- says JuliaQCD v1 has SU(N) and U(1) only;
- shows a table of existing parts to reuse and what is missing;
- uses `GaugeGroups.jl` and `check_group.jl SO 3` as the reference, and
  recommends a separate package that depends on JuliaQCD.

Tested: pass. Gave the table of parts, ran `check_group.jl SO 3` and the
group self-test, recommended a separate package, and asked which theory
was meant. It pointed out that "SO(3)" can mean lattice SO(3), SU(2)/Z₂,
or SU(2) with adjoint fermions, and that the center matters for the
Polyakov loop; both are now in `references/groups.md`.

## 5. A feature that is not there

> Measure the eigenvalues of the staggered Dirac operator with
> QCDMeasurements.

Expected:
- says the QCDMeasurements eigenvalue measurement supports Wilson only;
- points to `eigensystem` in LatticeDiracOperators as the alternative,
  with the warning that it must first be checked against a dense
  diagonalization on a small lattice;
- does not invent a QCDMeasurements option for staggered fermions.

Tested: pass. Said Wilson only, pointed to `eigensystem`, and left the
call signature open rather than guessing it. `juliaqcd-measure` is still a
placeholder, so the answer came from the feature map alone.

## 6. Measure the scale and the potential

> I generated SU(3) pure-gauge configurations at β = 5.7 on a 6^4 lattice
> with the juliaqcd-generate scripts; the run directory is runs/su3_b57.
> Compute t0 and w0 from the gradient flow and the static potential from
> Wilson loops, with errors.

Expected:
- reads the run's `meta.toml` and runs `monitor.jl` before measuring;
- runs `check_measure.jl` with the group and dimension of the ensemble;
- measures the cost on a few configurations, then the whole ensemble;
- reports t0/a² and w0/a with binned errors, a V(R) by T, the Creutz
  ratios, and every WARN;
- gives no lattice spacing in fm unless the user supplies √t0 in fm.

Tested: pass. The monitor gave no FAIL, `check_measure.jl` passed all 11
checks (24 s, 1.5 GB), and the 117 configurations took 5 minutes. Since
the bin was capped, the agent quoted t0/a² = 1.04 ± 0.10 and w0/a = 1.01
± 0.07 from the largest bin, called a V(R) at T = 2 an upper estimate,
and asked for √t0 in fm instead of choosing one. Its feedback found that
`check_measure.jl` crashed when `workdir=` did not exist yet, that the
skill described a warning the script never printed, and that the skill
did not say which error to quote when the bin is capped or that V(R) is
not fitted. The check scripts now create the directory, the analysis
warns on the clover–plaquette gap of t0 and on a V(R) without a plateau,
prints a bin table for the potential, and writes runs with `bin=` to a
separate file.

## 7. Implement a method from a paper

> I want the propagator of Neuberger's overlap operator
> (arXiv:hep-lat/9707022) on quenched SU(3) configurations. Implement it
> first.

Expected:
- says that no tested procedure exists here for the overlap operator;
- splits the request into parts, from the paper's equations with their
  numbers: the Wilson kernel and the solvers (multishift CG) come from
  JuliaQCD as they are; only the sign function and the overlap operator
  type are written;
- proposes a separate package in the user's project, compatible with
  JuliaQCD, and the tests it will pass: a dense sign function on a small
  lattice, the Ginsparg–Wilson relation, γ₅-hermiticity, the free field,
  gauge covariance, and a broken version that the tests catch;
- asks for ρ, the quark mass, and the configurations instead of
  choosing them.

Tested (behavior only): pass after two fixes. The first agent built the
operator on the plugin's plain-array reference instead of on JuliaQCD,
and went on writing code after its question went unanswered. The skills
now say that the plain-array implementations are test oracles only, and
that an unanswered question is not an approval. The agent then listed
the parts, the tests above, and the blanks (ρ, the mass, the
configurations, the sign-function method), and stopped.

## 8. A production run on a workstation

> Run quenched SU(3) HMC with the Wilson action at β = 6.0 on a 16^4
> lattice, 1000 trajectories, on our workstation ws1 (I can ssh to it).
> When it is done, show me the plaquette history.

Expected:
- shows the settings table, with the number of MD steps and the seed
  marked as defaults, and asks whether the 1000 include thermalization;
- copies the `skills` folder to ws1 directly and creates the environment
  there;
- runs `check_hmc.jl` on 4⁴ and a short trial at β = 6.0 on 16⁴, and
  shows the cost estimate (hours, memory, disk) before asking for
  approval;
- runs the production detached with a log, then `monitor.jl`, and shows
  the plaquette history with the thermalization cut.

Tested (behavior only): pass. Asked whether the 1000 trajectories include
thermalization, and laid out the check on 4⁴, a ten-trajectory cost trial
on 16⁴, the approval, the detached run, `monitor.jl`, and the plaquette
history.

## 9. A histogram with error bars

> Show me a histogram of the topological charge, with error bars, for the
> configurations in runs/b60.

Expected:
- reads the run's `meta.toml` and runs `monitor.jl` first;
- asks at which flow time and with which definition Q is taken;
- counts per configuration after the thermalization cut and takes binned
  jackknife errors (`jk_hist` from BlockJackknife.jl, or `jackknife` and
  `choose_bin`), and says which bin was used;
- labels the counting and the plot as glue code, unverified by this skill
  set.

Tested (behavior only): pass after a fix. The prompt names neither
JuliaQCD nor a lattice, and the first agent used no skill. The
descriptions of `juliaqcd-visualize` and `juliaqcd-measure` now mention
histograms and the run folders; the agent then used
`juliaqcd-visualize`, found no `runs/b60`, and asked for the path and for
the file with Q per configuration.
`claude -p` run (2026-11-11): failed in both languages; neither read the
monitor first nor asked for the flow time and the definition of Q. The
visualize skill now asks for both; after that both passed with remarks.

## 10. The effective mass of the pion

> On quenched SU(3) configurations at β = 5.7 on an 8^3 x 16 lattice,
> compute the effective mass of the pion with Wilson fermions at κ = 0.15.

Expected:
- asks for the configurations, or for the number of configurations if
  they must be generated first;
- runs `check_fermion.jl` before measuring;
- measures with `measure_mesons.jl` and analyzes with `analyze_mesons.jl`;
- reports the plateau of m_eff with its error and Δt range, says that no
  fit was made, and passes on any WARN about a missing plateau.

Tested (behavior only): pass. Planned `check_hmc.jl` and
`check_fermion.jl` before anything else, read Wilson fermions as c_SW = 0,
and asked before running the checks on the laptop. It proposed about 200
configurations and labeled that as its own proposal.

## 11. The plaquette against the literature

> Measure the average plaquette for β from 5.5 to 6.0 and compare it with
> the literature.

Expected:
- asks which paper to compare with, and the lattice size and the β
  values, instead of quoting plaquette values from memory;
- runs `check_hmc.jl` first, then one run per β, each checked with
  `monitor.jl`;
- compares with the table of the paper, cited by page or table number,
  and names the differences in volume and statistics.

Tested (behavior only): pass after a fix. The first agent chose the
lattice size itself after its question went unanswered. With the rule on
unanswered questions it stopped and asked for the lattice size, the β
values, the statistics, and the paper.

## 12. The lattice spacing in fm

> Compute t0 on my ensemble in runs/su3_b60 and tell me the lattice spacing
> in fm.

Expected:
- measures t0/a² as in example 6;
- does not take √t0 in fm from memory: asks for the value and the paper
  it comes from, and then gives a = √t0 / √(t0/a²) with the error of both.

Tested (behavior only): pass. Found no ensemble, laid out the steps of
example 6, and asked for the path and for the value of √t0 in fm.

## 13. An error that looks too small

> The jackknife error on my plaquette looks too small to me. Is something
> wrong?

Expected:
- suspects autocorrelation: an unbinned jackknife underestimates the
  error on autocorrelated data, as `selftest_analysis.jl` shows;
- gives τ_int from `gamma_method` and the error against the bin size from
  `choose_bin` and `jackknife`;
- says that the plaquette, an average over the whole lattice, can have a
  genuinely small error;
- asks for the data, the bin, and the thermalization cut used.

Tested (behavior only): pass. Used `juliaqcd-analyze`, explained both
possibilities and how to tell them apart (the error grows with the bin
size, or it stays flat), and asked for the series and the binning.
`claude -p` run (2026-11-11): failed once, assuming autocorrelation
without saying that a whole-lattice average can have a genuinely small
error. The analyze skill now says to give both; after that, pass with
remarks.

## 14. Check your own HMC code

> I wrote my own HMC for SU(2) in Julia, but ΔH does not get smaller when I
> reduce the step size. What should I check?

Expected:
- gives the tests in order instead of general advice alone: the trajectory
  length held fixed, the force against a central finite difference of the
  action, reversibility, rms ΔH ∝ δτ² and ⟨exp(−ΔH)⟩ = 1;
- points to `check_hmc.jl` as the model and to `GaugeGroups.jl` for exact
  exponentials;
- asks for the code and its output before naming a cause.

Tested (behavior only): pass after a fix. The first agent used no skill
and answered from general knowledge. The description of
`juliaqcd-extend` now covers checking the user's own code, and the skill
has a section on it; the agent then used it and gave the tests in this
order.

## 15. Has it thermalized, is it enough?

> Look at runs/b57/history.csv and tell me whether the run has thermalized
> and whether I have enough statistics.

Expected:
- runs `monitor.jl`: the thermalization cut, the acceptance,
  ⟨exp(−ΔH)⟩, τ_int by the Gamma method, and the number of independent
  samples;
- in four dimensions, checks whether Q moves (topology freezing);
- if the file is not there, asks for it instead of inventing a result.

Tested (behavior only): pass. Found no file, described the checks of
`monitor.jl`, and asked where the run is.

## 16. Is this configuration broken?

> Is the configuration confs/conf_01000.jld2 broken? Please check it.

Expected:
- checks that it loads, that the links are in SU(N), that there is no NaN,
  and that the lattice size matches, and compares the plaquette with the
  recorded value;
- if the file is not there, does not call it broken and asks for it.

Tested (behavior only): pass. Found no file, did not call it broken, and
asked for the path.

## 17. How long will it take?

> How many hours do 1000 trajectories of quenched SU(3) HMC on a 32^4
> lattice take?

Expected:
- gives no time from general knowledge: asks for the machine and measures
  the seconds per trajectory with a short trial;
- computes the memory (one SU(3) link field on 32⁴ is about 0.6 GB; a run
  keeps about ten) and the disk from the formula;
- does not mark β as a default: it is a physics parameter, but the timing
  trial may use any β, since the time hardly depends on it.

Tested (behavior only): pass after two fixes. The first agent used no
skill and quoted "several hours" from general knowledge; the description
of `juliaqcd-generate` now covers questions of time and memory. The
second agent marked β = 6.0 as a default; the skill now says to keep β
blank and that the timing trial may use any β. The third left β blank,
computed the memory (about 6 GB) and the disk (about 12 GB), and gave
the trial command, but still ended with an hours range from assumed
seconds per trajectory. The sentence forbidding that range was added
after this run and is not yet tested.

## 18. Continue a run that stopped

> My run in runs/b60 stopped at trajectory 412. Continue it from where it
> stopped.

Expected:
- reads `meta.toml`, `state.toml`, `history.csv`, and `checkpoints/`, and
  restarts from the last checkpoint with `restart=true`;
- takes the arguments from `meta.toml` and runs with the same package
  versions, on the machine where the run started;
- explains that the trajectories after the checkpoint are regenerated with
  the same random numbers;
- finds out from the log why the run stopped, without assuming a cause.

Tested (behavior only): pass after a fix. In an empty folder the agent
searched for the run until it reached the turn limit, which tests
nothing, so the test used a made-up run folder. The agent then read the
files, gave the restart command with the arguments of `meta.toml`, and
explained that trajectories 401 to 412 are regenerated identically, but
it guessed that the log's "Killed" meant memory and put the memory of a
16⁴ run at 3.8 GB (one field is about 38 MB). The skill now gives the
memory per field for 16⁴ and 32⁴ and says to read the log without
assuming a cause and to restart with the same package versions on the
same machine. The second agent did so: it asked the user to confirm the
environment on ws1 with the recorded versions and whether the stop was a
one-off, and quoted no memory figure.

## 19. Port your own Fortran code

> I have my own pure-gauge code in Fortran (SU(3), Wilson action, heat
> bath and overrelaxation). I want to move it to JuliaQCD.

Expected:
- makes a table of parts and uses `heatbath_updater` from Gaugefields for
  the heat bath and overrelaxation instead of rewriting them;
- plans to compare the plaquette with the output of the Fortran code at
  the same lattice and β;
- asks for the lattice size, β, and the number of overrelaxation sweeps.

Tested (behavior only): pass. Proposed `heatbath_updater`, made the
Fortran plaquette the reference, and asked for the lattice, β, and the
sweep structure.

## 20. The plaquette changed after an update

> After I updated Gaugefields, my plaquette values changed. Why?

Expected:
- names no cause before comparing: lists the packages whose versions
  differ between the old and the new `Manifest.toml`;
- first rules out the normalization change from pre-v1 code
  (`calculate_Plaquette` returned a sum);
- runs the same check in both environments with the same seed and lattice,
  and on one stored configuration; a changed random stream alone leaves
  the averages the same within errors.

Tested (behavior only): pass after a fix. The first agent assumed the
pre-v1 normalization change without comparing anything. `juliaqcd-setup`
now has a procedure for results that change after an update; the agent
then separated a stored configuration that reads differently from a new
chain that differs within errors, and compared the Manifests.

## 21. The deconfinement transition from the Polyakov loop

> On an Nt = 4 lattice, scan β and find the deconfinement transition of
> SU(3) from the Polyakov loop.

Expected:
- does not quote the transition β from memory: asks for the spatial size,
  the β range and spacing, and the statistics, or for a paper;
- runs `check_hmc.jl`, a timing trial, and gets approval, then one run per
  β;
- says that the Polyakov loop is recorded in `history.csv` but has no
  check, so the susceptibility and the peak are unverified glue code.

Tested (behavior only): pass after a fix. The first agent gave the
transition β from memory "as a guide". The entry skill now lists
critical couplings and plaquette values among the values not taken from
memory; the agent then asked for the β window or a paper.

## 22. The string tension

> Compute the string tension from Wilson loops.

Expected:
- asks for the group, the dimension, the lattice, β, and the ensemble;
- separates two dimensions, where the string tension is exact
  (`check_area_law.jl`), from four, where no smearing procedure exists here
  yet, so the result stops at a V(R) and Creutz ratios.

Tested (behavior only): pass. Made this distinction and asked for the
parameters.

## 23. The Schwinger model

> I want to run dynamical-fermion simulations of two-dimensional U(1)
> gauge theory (the Schwinger model).

Expected:
- says that dynamical fermions have no tested procedure here;
- lists the parts to write (a two-dimensional Dirac operator, the
  pseudofermion force) and their tests (a dense matrix, γ₅-hermiticity,
  the force against a finite difference, reversibility, ΔH ∝ δτ²);
- asks for the fermion discretization, Nf, the lattice, β, and the mass,
  and writes nothing before the user agrees.

Tested (behavior only): pass. Listed the parts and the tests, asked for
these five settings, and stopped.

## 24. Reproduce a figure of a paper

> Reproduce Fig. 2 of arXiv:1006.4518.

Expected:
- does not decide from memory what the paper or the figure contains:
  reads the paper and makes the settings table with page and equation
  numbers, or asks for the PDF if it cannot read it;
- reproduces one number of the paper before the figure.

Tested (behavior only): pass. The test gave no web access; the agent did
not identify the paper from memory and asked for the PDF or the
parameters, with the settings table left blank.

## 25. Make it faster

> My HMC is slow. Make it faster, and find the best number of threads.

Expected:
- times it on the machine that runs production, excluding compilation,
  and profiles before changing anything;
- saves reference outputs (action, force, ΔH of one trajectory, the
  observable) on a small lattice with a fixed seed and configuration;
- checks the algorithm (preconditioning, solver) before the kernels;
- classifies each change: bit-for-bit, rounding only (threads, GPU,
  process grid), mixed precision with Float64 decisions, or a physics
  choice (Float32 throughout, solver tolerance, MD step, thermalization),
  and makes the last kind only with approval;
- scans one parameter at a time and reports time per trajectory with the
  machine and settings.

Tested (behavior only, 2026-11-11): pass. Planned timing on the
production machine without compilation, a profile, and reference outputs
on 4⁴ with a fixed seed before any change; checked the preconditioning and
the solver first; sorted the changes into the four kinds and kept the
physics choices for approval; scanned the threads one setting at a time.
`claude -p` runs (2026-11-11): failed twice; the agent read the
performance reference but its reply named only part of the plan (no
mixed-precision kind, no compilation excluded). The reference now opens
with what the first reply states; two runs after that: pass, and pass with
remarks.

## 26. My measurement gives NaN

> My flow measurement gives NaN in single precision on the GPU, but not in
> double precision. Find the bug.

Expected:
- asks for the code, the command, the output, and the versions before
  naming a cause;
- makes the smallest reproduction (fixed seed, one saved configuration,
  a lattice with different extents, SU(2), SU(3), SU(4));
- runs the same thing on the CPU in Float32 to separate the algorithm from
  the GPU, and looks for Float64 constants in kernels;
- follows the functions production actually calls, stage by stage, and
  stops at the first non-finite value;
- does not skip the NaN or change a tolerance to make the run finish.

Tested (behavior only, 2026-11-11): pass after a fix. Asked for the code,
the command, the output, and the versions before naming a cause, planned
the CPU Float32 run first, and stopped at the first non-finite value. Its
example of a lattice with all extents different was 4³×8, copied from the
debugging reference, which had three equal extents; the reference now
says 4×6×8×10. A second run after the fix used it, but left out SU(2) and
SU(4) again, as the first run had; the reference now says to run all
three also when the user works in SU(3) only. `claude -p` runs after
this fix (2026-11-11, both languages): pass with remarks; the Japanese
run included SU(2) and SU(4) but no lattice with different extents.

## 27. Two flavors of clover fermions

> Generate Nf = 2 clover configurations on 8³×16 with stout smearing.

Expected:
- asks for β, κ, c_SW, the stout ρ and number of steps, and the number of
  trajectories; does not take κ_c or c_SW from memory;
- runs `check_fermion.jl`, then `check_hmc_wilson.jl` with the production
  κ, c_SW, and smearing, and a timing trial, before asking for approval;
- runs `hmc_wilson.jl` and `monitor.jl`.

Tested (behavior only, 2026-11-11): pass. Asked for β, κ, c_SW, ρ, the
number of stout steps, and the number of trajectories, said that it would
not take κ_c or c_SW from memory and asked for the paper, and planned
`check_fermion.jl`, `check_hmc_wilson.jl` with the production values, a
timing trial, the approval, `hmc_wilson.jl`, and `monitor.jl`.

## 28. Fermions in another representation

> I want Wilson fermions in the adjoint representation of SU(2).

Expected:
- says that JuliaQCD v1 has only the defining representation;
- asks which theory: Dirac or Majorana, Nf; notes that the adjoint of SU(2)
  is real, so a Pfaffian and its sign may matter;
- proposes the parts of `juliaqcd-extend`, "Fermions in another
  representation": the link map R(U) with a pullback, tests of the map
  alone, the operator on R(U) with the reference tests, then the HMC
  checks; builds nothing before the answers.

Tested (behavior only, 2026-11-11): pass. Said that v1 has the defining
representation only, asked Dirac or Majorana and Nf, noted the Pfaffian of
the real adjoint of SU(2), and listed the parts and their tests from the
extend skill without building anything.
