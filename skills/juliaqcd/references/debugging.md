# Debugging

Read this when something fails or gives a value the user doubts: an error,
a NaN, a check that fails, a result that changed, a run that does not end,
or code that runs but disagrees with a reference. None of it is a tested
script here; it collects faults that cost time in work on JuliaQCD v1 and
how they were found. Ask for the code, the command, and the full output
before naming a cause, and report which test located the fault.

## Where the specific tables are

- A check of this plugin fails: the table "What the checks test" in
  `juliaqcd-generate` (HMC) and `juliaqcd-measure` (measurements, Wilson
  and clover operators) gives the likely cause of each failing check.
- Low acceptance: `juliaqcd-generate`, "Low acceptance".
- The user's own HMC, force, or operator: `juliaqcd-extend`, "Checking the
  user's own code".
- `UndefVarError` for an old name, `MethodError` from inside a package, or
  a result that changed after an update: `juliaqcd-setup`. A run that does
  not start, a GPU that is not found, or warnings at load time:
  `juliaqcd-setup/references/running.md`.
- Disagreement after a speed-up: `references/performance.md`.
- Disagreement with another code: `juliaqcd-extend/references/development.md`,
  "Comparing with another code".

## First: is the check right, and are the inputs the same?

- When a check fails, first check the checker: the tool, the expected
  value, the input. A suspiciously round number (2,147,483,647 is 2³¹ − 1,
  an integer overflow in the tool) points at the tool. A result of the
  wrong format (a different number of header lines) is not a wrong
  result: check the content as well as the line count. Never make a check
  pass by changing its expected value or tolerance; change them only after
  the cause is explained.
- When two runs from the same configuration and seed disagree, compare the
  full settings of both, line by line, before suspecting the code:
  couplings (β, κ or mass, c_SW, other terms), sources, boundary
  conditions, trajectory length, integrator, number of steps and their
  split, tolerances, smearing, precision, and sign conventions. Read them
  from the record each run saved, not from memory or from another segment
  of the same run; settings may change between segments.
- A difference of about √2 in norm between two solutions means that two
  independent random vectors were compared: a source without a seed.
- Check which versions, node, and backend each run used, from the head of
  its log and the checksums of `Project.toml`, `Manifest.toml`, and
  `LocalPreferences.toml` (the backend lives there), and what is actually
  loaded (`pathof`, `pkgversion`): a dependency can be a local fork, and
  two machines can resolve the same `Project.toml` to different versions.
- Choose a comparison point where the reference itself behaves normally
  (acceptance as in production). A point where the reference's ΔH explodes
  compares nothing. Agreement at an easy point (a term switched off, a heavy
  mass) does not cover the production point.
- A self-consistency check passes when both sides come from the same
  broken code (a density and its sum, both wrong). Keep at least one
  comparison with an input whose answer is known (a cold configuration, a
  charge-one instanton, a free field) or with an independent
  implementation.

## Make the smallest reproduction

- Fix everything that can vary: the seed, one stored configuration, the
  package versions (the `Manifest.toml`), the Julia version, the backend,
  one process. Make random choices independent of the Julia version
  (fixed values or StableRNGs).
- Use three kinds of configuration: cold (unit links) against free-field
  results, a hot configuration with a fixed seed, saved in Float64 and read
  by every precision and machine, and one production configuration. A cold
  configuration alone hides errors in color indices.
- Use a lattice with all extents different (4×6×8×10; 4⁴ and 4³×8 still
  have equal extents), so a mixed-up direction shows. For plumbing alone (reading, types, devices),
  a cold 4⁴ configuration has plaquette exactly 1 on every backend.
- Run SU(2), SU(3), and SU(4), also when the user works in SU(3) only.
  Errors with traces or the ε tensor vanish
  in SU(2) (Q − Q† is already traceless there); SU(3) often has its own
  specialized methods, so a fault can appear in SU(3) only or in the
  general-N path only.
- Remove parts while the disagreement stays, physics parts first: no
  smearing, plain Wilson instead of clover, periodic boundaries, one
  source. The part whose removal makes the disagreement vanish is the
  suspect. Then shrink: one trajectory, one solve, one configuration.
- Keep the reproduction as a script that prints both values, the maximum
  difference, and the relative difference, and stops on failure; it
  becomes a test once the fault is fixed.
- A reproduction for upstream must run in an environment of registered
  versions only, without local changes.

## Find the stage where the values part

Compare stage by stage with an independent implementation on the same
input, and stop at the first stage that disagrees:

1. the input itself: the configuration read back (plaquette, unitarity of
   every link), the parameters actually used (print them from inside the
   run, not from the command line);
2. links and paths: a single Wilson loop or staple at one site; a smeared
   or gauge-fixed link;
3. the action, its density, the field strength, the clover term;
4. the force on a few links against a central finite difference of the
   action, for every generator. The ratio need not be 1: a package's
   convention can make it a constant (−2, for example). Check that it is
   the same constant for every component and direction;
5. one application of the operator (D·ψ) against a dense matrix on a
   small lattice. If it agrees, the remaining difference is in the solver
   or the contractions;
6. the solver: the true residual |b − D x|/|b|, recomputed from the
   solution;
7. contractions and the observable, against a slow, plain reference (Wick
   contractions as determinants or sums over permutations);
8. the analysis (normalization, binning, fits).

Compare gauge-invariant quantities (plaquette, C(t)) before components:
components agree only when every gauge and basis convention matches, so
comparing them first does not narrow down a cause. Tolerances: about
1e-14 for stages without a solver; after a solver, set by the residual;
where C(t) is smallest, cancellation widens the difference (to 1e-9 with
residuals of 1e-12), so report it per time slice. Compare each quantity by
its own measure, written before the comparison
(`references/performance.md`): the plaquette can agree to 1e-13 while ΔH
differs by 1e-8.

For HMC, put one trajectory of both versions side by side from the same
configuration and momenta: ΔH, acceptance, final plaquette, and solver
iteration counts. Iteration counts fingerprint the operator and solver:
equal ΔH with different counts points to a different stopping rule or
preconditioner. Right after a heat-bath draw of pseudofermions, the
fermion action must equal |ξ|² of the Gaussian vector (plus the separate
determinant term with even-odd preconditioning). For smearing, compare one
link, and write down the order of the products and whether Ω or Ω† is
used.

Compare per column, not as one number. When a GPU measurement disagreed
with the CPU only in the topological charge for one flow, and in every
column for a flow whose action has rectangles, the pattern located the
fault: a halo one site wide, too narrow for the rectangle loops. Loops
longer than one link (rectangles, twisted loops) need a halo of width 2.
A short run (a few flow steps or trajectories) on two backends, compared
column by column, is cheap; repeat it after every change of code or
version.

Trace the path production takes. A stage rebuilt by hand from public
functions can take another path than production: one function name can
dispatch to different methods for different field types (an exponential
by eigenvalues for one type and by a Padé approximant for another). Call
the production function and follow what it calls (`@which`, `@edit`, the
stack). If a hand-built path does not reproduce the fault, write "not
reproduced on this path" and leave the cause open.

The plain-array references of this plugin
(`juliaqcd-measure/scripts/LatticeReference.jl`,
`juliaqcd-measure/scripts/FermionReference.jl`,
`juliaqcd-extend/scripts/GaugeGroups.jl`) serve for stages 2 to 5.

## Values that run but look wrong

Suspect conventions before algorithms. A difference far above rounding but
small (a percent or less) is almost always a convention:

- normalization (sum or average, per plaquette or per site, 1/Nc, κ or
  mass);
- boundary conditions (periodic, antiperiodic, twisted, Dirichlet) and
  where the phase is stored;
- the γ-matrix basis and the sign of a term. With a sign in question
  (clover), first check that one of the two signs gives agreement, then
  decide which is standard from the literature and a third code;
- the definition of a quantity (clover or plaquette field strength, with
  or without the trace subtracted), and the coefficients of a flow or
  improved action (c0, c1): write them in output headers and check all
  files;
- index origin (0 or 1), the order of directions (which one is time), and
  configuration numbers against row numbers against array indices;
- the random stream (a different seed or element type gives a different
  sequence; a chain then differs and its averages agree only within
  errors);
- for a group other than SU(N), the projection onto its algebra. For a
  group embedded in a larger matrix group (G₂ in SO(7), for example), the
  antihermitian traceless part of a matrix is not in the group's algebra;
  project onto the algebra itself (`juliaqcd-extend/references/groups.md`).
  Code copied from SU(N) gets this wrong.

Write both conventions side by side before changing any code.

Code errors that gave plausible but wrong values:

- An output array that also appeared among the work arrays passed to the
  same function (a loop-product routine given the output and a list of
  temporaries that contained it): intermediate products overwrote the
  output. Pass work arrays that exclude the output.
- A local variable named like a Base function (`count`) hid that function
  for the rest of the scope.

Physics that looks like a bug:

- Parameters tuned on a small volume (finite-volume effects make masses
  heavier) are off on the production volume: tune there.
- Wrap-around contributions on a short periodic time extent, and excited
  states from point sources, make two analysis methods disagree. Build
  synthetic data from the fitted result plus these contributions and pass
  it through the same analysis; if it reproduces the disagreement, the
  cause is explained.
- A chain started from a configuration made at other couplings inherits
  its topology and can stay frozen there. Look at the history of Q and at
  the difference between the first and second halves; when the halves
  disagree, check the error estimate on two independent subsets (even and
  odd configurations), and decide between relaxation and fluctuation from
  an extension of the run.

Analysis errors:

- Autocorrelation times computed across gaps in the configuration numbers
  (unmeasured configurations) treat each row as one step and come out too
  small: split the series at gaps.
- Count measurements by configuration number, and count sets by their
  union: a configuration measured twice counts once.
- Ratios and logarithms (effective masses) give NaN or Inf where the
  denominator is small (near a wall, at the ends of the time range, where
  the signal is lost in noise). Mask small and non-finite values and print
  how many were masked; dropping them silently changes the fit window.

## NaN and Inf

- Check the input first: links not in the group, a configuration read with
  the wrong precision or byte order, a parameter that is zero or infinite.
- Stop at the first NaN: check after each stage above (an `isfinite` test
  on a scalar such as a norm or a dot product is enough, since a NaN
  reaches every sum).
- A NaN only in Float32 may be an overflow in the algorithm: a Padé
  exponential that forms a determinant explicitly overflowed for SU(3) in
  Float32 (coefficients of order 1e16, a determinant of order 1e50). Run
  the same thing on the CPU in Float32 before blaming the GPU.
- With a boundary built by zeroing links (Dirichlet), list in advance
  where a division by a quantity that vanishes there can occur. An
  inverse of a boundary phase is infinite when the phase is 0: use a
  function that returns 0 for 0.
- Do not hide a NaN by skipping it; find where it comes from.

## A run that does not end or is slow

- See where a running Julia process is without stopping it: send SIGINFO
  (macOS) or SIGUSR1 (Linux), and it prints a profile report.
- Log progress inside each stage from the start: time per stage, the
  convergence measure every few hundred iterations, time and true residual
  per solve. One configuration whose gauge fixing stalled (its functional
  stopped changing at 7e-5 while others reached 1e-14 in about 1400
  iterations, at the same time per iteration) ran for hours behind a log
  with one line per configuration. Skip such a configuration with the
  reason and measure it again later with other settings.
- Measure the time of each stage before naming the slow one: a source that
  took 100 minutes spent 12 in the solver and the rest in smearing, which
  allocated tens of GB per call (`references/performance.md`, "Common
  causes on the CPU").
- A process killed by SIGKILL on a small machine is usually out of memory
  (and out of disk for swap): run fewer at a time.

## Find the change that caused it

- Code: `git bisect` between a commit that works and one that does not,
  with the reproduction script as the test (`git bisect run`). Then list
  which outputs were made with the affected versions and functions.
- Packages: compare the two `Manifest.toml`, then update one package at a
  time in a copy of the environment until the result changes.
- Julia: run the reproduction on both versions, each with an environment
  made by that version.
- After an upstream update, run your comparison script before and after on
  the same input, and run once with the values of any new upstream feature
  (a boundary phase of 0, a new option): bit-for-bit agreement on old
  inputs does not test the new values.

## Reading errors

- Read the first frame inside the user's code and the first frame inside
  a package; the long type parameters of JuliaQCD fields in between can be
  skipped at first.
- A `MethodError` lists the argument types it received: compare them with
  the method's signature (`methods(f)`). Common causes are a field of a
  different type than expected (a plain array where a JuliaQCD field is
  needed, Float64 where the field is Float32, a Float64 array placed on a
  Float32 GPU field; convert on the host first), a missing keyword, and an
  old function name.
- If the top of the stack is building an error message (`error(...)`
  with string interpolation) and fails there (a `FieldError`), the error
  handling itself is broken and hides the real error. The cause is the
  condition that led into that branch, often a non-default option: check
  whether the fault appears with the default settings before reporting a
  whole function as broken.
- A world-age error in Julia 1.12 comes from loading a package inside a
  function (`@eval using ...`) and calling it from the same function: load
  at top level, or call through `Base.invokelatest`.
- A crash at process exit (`double free or corruption`, signal 6) after
  all output was written does not by itself make the output wrong, and an
  exit code of 0 does not make it right: judge by checking the output.

## GPU and MPI

- A Float64 literal or a Float64 coefficient in a kernel (`0.5`, `1/N`,
  `ldexp(1.0, k)`, κ held as Float64) stops compilation on a GPU without
  Float64 ("unsupported use of double value", with the kernel and line)
  and silently promotes the computation on the CPU, so the CPU alone does
  not find it. Write constants in the element type; afterwards CPU Float64
  must be unchanged bit for bit, and CPU Float32 changes in the last digits
  only.
- Scalar indexing of a GPU array is an error or very slow: the code reads
  elements one by one on the host. Use the package's kernels or copy to
  the host on purpose.
- Results read on the host without synchronization can be stale.
- A fast path added in front of upstream's input checks (for example that
  the boundary conditions of the operator and the field agree) skips them:
  put it after the checks.
- An MPI run that hangs is usually a collective called by some ranks only
  (a branch on the rank around a reduction or a halo exchange). A wrong
  result only with several ranks points to a halo that was not exchanged
  after a write, too narrow for the loops used, or handled twice. Compare
  one rank with two ranks on the same configuration. (This part is
  general advice, not collected from a fault.)

## What not to do

- Do not name a cause before a test shows it; report "unknown" with the
  tests that passed. Do not call a 0.1 % difference rounding, or a
  conditional agreement a reproduction.
- Never change an expected value, a tolerance, or a checksum to make a
  failing check pass. Do not replace the code of a running production
  chain.
- Do not change several things at once; one change, one rerun.
- Do not skip, catch, or silence an error to make the run finish.
- Do not declare a fix before the reproduction passes and the existing
  checks still pass, on more than one Julia and dependency version.
- Fix the criteria (residual, difference, speed) before the test, and do
  not move them after seeing the result.
- An optional check ("load the file if it exists") must print whether it
  ran. Judge a run by the presence of its pass line and its completion
  mark, so a check or a script that stopped silently counts as not passed.
  Before reading a comparison as "agree", check that it compared the
  expected number of items; a stage that crashed leaves empty output.
- Report the state of runs from logs and tool output (`nvidia-smi`, file
  sizes, checksums, exit codes), not from memory or from an earlier
  report; do not trust a self-report ("saved", "done", "not done yet")
  without checking the primary record, and match the time of a report
  with the time of the request it answers.
- Tell "could not read" from "is not there": a dropped connection is not a
  finished job.
- Tell results apart by their origin (program and its checksum, backend),
  not by configuration number alone: the same number measured on the CPU
  and on the GPU are different files.
- Report the conditions of a timing (other processes on the GPU, the
  node).
- Mark configurations made only to recover from a failure as not for
  analysis, or a later agent will use them.
