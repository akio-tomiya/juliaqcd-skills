# Making a run faster without changing its results

Read this when the user asks to speed up a run, a measurement, or their own
code, to find the best number of threads, ranks, or GPUs, or to profile.
Nothing here is a tested script; the procedure is what makes a speed-up
safe to accept.

## Check the algorithm before the kernels

Before tuning any loop, check that the computation is not already losing at
the level of the algorithm: is every solve preconditioned (even-odd where
the operator has it), is the solver the right one for the operator (CG on
D†D, BiCGStab on D, multishift CG for rational functions), and is any path
solving without the preconditioning the others use? One unpreconditioned
path can cost more than any kernel optimization gains. Changing the
algorithm is a kind-4 change below, unless it gives the same solution to
the same tolerance.

## Measure first, on the machine that will run it

- Time on the workstation, cluster node, or GPU that will run production,
  not on a laptop (`juliaqcd` SKILL.md, "Which machine"), with no other job
  on the same GPU or cores.
- Exclude compilation: drop the first call and report the median of later
  ones (`@elapsed` in a loop, or `BenchmarkTools.@btime` in a scratch
  environment). GPU kernels compile once per element type, so warm up each
  combination of type and precision separately. For a solver, solve the
  same problem twice and report the second.
- On a GPU, launches are asynchronous: synchronize before stopping the
  clock (`JACC.synchronize()`, or the backend's own). For a small
  operation, run it once, synchronize, run it N times, synchronize, and
  divide by N.
- Find where the time goes before changing anything: `Profile` (`@profile`
  on a few trajectories, read with `Profile.print(format=:flat,
  sortedby=:count)`), and allocations (`@allocated`; `@time` shows them).
  For HMC, split the time per trajectory into force, link update, action,
  and solver; for a measurement, into solver, contractions, and I/O.
- Tell fixed costs from bandwidth by changing the volume: if 16 times the
  volume takes only twice the time, kernel launches and synchronizations
  dominate. Where bandwidth dominates, divide the bytes moved by the time
  and compare with the device's bandwidth, to see how far the ceiling is.
  Synchronizations are expensive; a backend that synchronizes after every
  launch can spend most of an iteration on a small lattice waiting. For
  correctness, synchronizing just before the CPU reads a value (a dot
  product, a copy to the host) is enough.
- Record at run time, from inside the program: the backend and device name,
  the Julia version, `Threads.nthreads()`, the process grid, the path of the
  active environment, and its `Manifest.toml`, with the lattice size. This
  shows afterwards that a "GPU" run was not on the CPU and did not load
  another environment. A timing without these cannot be compared.

## Keep a reference before the first change

With a fixed seed and stored configurations, save the outputs of the parts
the change touches: the action and plaquette, the force on every link,
D·ψ for a fixed ψ, the solver's solution, its true residual, and its
iteration count, ΔH of one trajectory from a fixed momentum, and the
measured observable. Give every random source a seed, or the two versions
solve different problems (a difference of about √2 in norm means two
independent vectors were compared).

Use a small lattice (4⁴) and also configurations at the production
parameters. An easy point can agree while production does not, when a term
that vanishes at the easy point (a source, a chemical potential, a small
mass) takes another code path. A point where the old code itself is
unstable (ΔH blowing up) cannot serve as a reference. Check that the test
calls the functions production calls: one name can dispatch to different
methods for different field types.

Take the settings of the comparison from what the run saved (its settings
file or log), never from memory or from another segment of the run: MD
steps, step size, and tolerances may change between segments. When a
comparison from the same seed and configuration disagrees, compare the two
settings tables before suspecting the code.

Keep the reference script, so every later version is compared against the
same numbers. Create all its output folders at the start; a long
comparison should not fail at the end for want of a folder.

## Four kinds of "the same result"

Classify every change before making it, and tell the user which kind it is.
Write the tolerance of each quantity before running the comparison, from
the precision and the solver tolerance, not after seeing the difference.

1. Same operations in the same order: removing allocations, reusing work
   fields, avoiding copies, type stability, hoisting a constant, overlapping
   communication with computation, a GPU kernel that keeps the CPU's order
   of operations. The results must agree bit for bit (`==`). Any difference
   is a bug; for an overlap, a missing synchronization. Where bit-for-bit
   agreement is possible, use it as the test: it finds bugs sooner than a
   tolerance does.
2. Same mathematics, different order of floating-point operations: threads,
   GPU, a different process grid, a different reduction, fused loops. The
   results agree to rounding only. Compare on the same configuration, each
   quantity by its own measure:
   - one application of an operator, the plaquette, the force, a smeared
     link: the relative difference of the 2-norm over the whole lattice,
     |a − b|/|a|, about 1e-12 to 1e-14 in Float64 and 1e-7 in Float32;
   - ΔH: absolute difference. It is a difference of two numbers of order the
     volume, so a relative tolerance means nothing. With a solver inside the
     molecular dynamics, correct codes differ by about the solver tolerance
     times the action (often 1e-8 or more);
   - a solver solution: recompute the true residual |b − D x|/|b| after each
     solve and require it below the tolerance for both versions. The two
     solutions then differ by up to about the tolerance times the condition
     number (with a tolerance of 1e-10 in Float64, differences of 1e-11 to
     1e-9 between correct codes are normal; larger for clover than for
     Wilson). Solvers stop on the iterated residual, which can drift from
     the true one; tighten the stopping tolerance slightly if the true
     residual sits at the limit;
   - measurements with noise sources: the same noise vectors on the same
     configuration; the difference of the averages well below the
     statistical error (for example 0.1 σ).

   Over a whole HMC trajectory rounding differences grow (molecular dynamics
   is chaotic), so compare ΔH and one trajectory, not a chain after many
   trajectories. Check whether a random stream depends on the number of
   threads or ranks, and say so.
3. Lower precision inside, decisions in Float64: mixed-precision solvers
   whose iterations run in Float32 (or store in Float16) while the true
   residual and the stopping test are computed in Float64. The answer's
   accuracy is still set by the tolerance, so this is not a physics choice.
   Compare with a Float64 reference solve: the true residual in Float64, the
   difference of the solutions as in kind 2, and the iteration count (for
   very coarse storage, the iteration count is the measure). Report the
   number and the time of the Float64 updates as well.
4. A change of the algorithm or its parameters: Float32 throughout, a
   looser solver tolerance, a larger MD step or fewer steps, a different
   integrator or preconditioner, a different random stream, shorter
   thermalization, fewer measurements, a different smearing. These are
   physics choices, not speed-ups of the same computation. Do not make one
   without the user's approval. After it, a chain is different: compare
   averages within errors on independent runs, and for HMC check
   reversibility (forward then backward: links back to about 1e-12,
   ΔH_forward + ΔH_backward ≈ 0) and ⟨exp(−ΔH)⟩ = 1 on a long chain
   (`check_hmc.jl`). HMC stays exact only if the accept step uses an action
   computed accurately enough.

A convention error found in the old code (a wrong normalization, a wrong
projection) is not kept to preserve bit-for-bit agreement. Fix it, treat
the fix as kind 4, and tell the user; agreement with past results is not a
reason to keep it.

## Float32, and GPUs without Float64

Compare three results on the same input: the GPU in Float32, the CPU in
Float32, and the CPU in Float64. The GPU passes when its difference from
CPU Float32 is about the size of the difference between CPU Float32 and CPU
Float64, which measures Float32 rounding. A Float32 solve differs from the
Float64 solution by about 1e-5; that is the Float32 limit, not a bug. Judge
Float32 solutions by their agreement with each other (GPU against CPU
Float32) and by their true residuals computed in Float64.

- First check that CPU Float32 really computes in Float32. A Float64
  literal in a kernel (`0.5`, `1/N`, `1e-100`, `ldexp(1.0, k)`) or a
  coefficient held as Float64 (κ in a `Ref{Float64}`) silently promotes the
  CPU computation to Float64; a GPU without Float64 stops with an error
  about double values. Write constants in the element type (`T(0.5)`,
  `zero(T)`, `one(T)/N`) and take the CPU Float32 reference again after the
  fix, since its last digits change.
- Random numbers of different types are different sequences even with the
  same seed. Generate momenta and sources in Float64 and convert, read them
  from a file, or start from zero momentum.
- A NaN that first appears in Float32 may come from the algorithm (for
  example an explicit inverse through a determinant that overflows). Run
  the same thing on the CPU in Float32 to tell it from a GPU bug.
- Convert a configuration saved in Float64 to the element type on the host
  before moving it to the GPU.
- Checking `any(isnan, x)` every iteration reads the whole field. In CG,
  checking the dot product p·Ap is enough, since a NaN reaches every sum.
- A JACC backend is fixed when the program starts and cannot be switched
  inside one process; a Float64 part on the CPU next to a GPU part needs
  fields built on host arrays and an explicit CPU path.

## Common causes on the CPU

- A closure in `Threads.@threads` that captures a variable reassigned
  outside the loop (`a, b = b, a`) boxes it (`Core.Box`), and the loop
  loses its types: one smearing step allocated tens of GB. Move the loop
  body into a function; the results stay bit for bit the same. Find it
  with `@code_warntype` and `@allocated`.
- Several processes using BLAS each start BLAS threads: set
  `OPENBLAS_NUM_THREADS=1`, or each process runs at half speed.
- Bit-for-bit agreement can break where the compiler chooses fused
  multiply-add differently depending on the surrounding code (small
  static matrix products, for example). Call the original kernel there.
- Halo exchange after every vector update is wasted work: exchange only
  when a stencil reads the halo. In a JACC kernel, decide first whether it
  reads halos assumed current or handles the boundary itself.

## One change at a time

Make one change, compare it with the reference, time it, and keep it only
if both pass. For a measurement already in production, run the new version
for a short stretch (for example the first 100 flow steps) on the same
input and compare with the first lines of the old production output.
Replace the production runner only after that passes, and keep the old one
under another name. Report each change with its kind, its comparison, its time,
its iteration count, and its time per iteration: together they tell a
faster kernel from fewer iterations. Do not combine a kind-4 change with
others in one step; if the result moves, the cause must be clear.

Also check a checkpoint written by the new code: write, read back, and
compare, and check whether reading it verifies the couplings it was made
with. If it does not, compare them with the run's settings before starting.

## Finding the sweet spot

Scan one parameter at a time, the others fixed, on the production lattice
or the largest that fits, with a short run of fixed length:

- threads (1, 2, 4, … up to the physical cores of one socket);
- process grid for MPI (which directions to split), and ranks per node;
- GPU count, and for one GPU the lattice size per GPU (on a small lattice a
  large GPU has too little work, and launches and synchronizations set the
  time);
- the JACC backend.

Report time per trajectory (or per measurement) and per site, and the
efficiency against the smallest run. Stop where adding resources gains less
than the user's threshold. Each new setting is a kind-2 change: check the
reference once for it. The sweet spot depends on the machine: the ratio
between two GPUs can follow their bandwidth on a large lattice and fall
well short of it on a small one. Measure again on each machine.

Before expecting a multi-GPU speed-up, check whether the GPUs can reach
each other directly (peer-to-peer). Many consumer GPUs cannot, and then
halo exchange goes through the host even with a GPU-aware MPI. Two ranks on
one GPU test correctness, not the speed of two GPUs.

## Putting it into production

Use the new code only for chains started with it; do not switch a running
chain in the middle, and do not mix code versions within one chain. Record
the code version (a commit hash) with each segment of a run. On each
machine, run a short trial and check the recorded backend, device, and
versions before production.

## Where the speed-up belongs

A slow part inside a JuliaQCD package is reported to the user for the
package's issue tracker, with the profile and the lattice size; the
plugin's scripts and the user's code use JuliaQCD as is. A fast path in the
user's own code follows the steps above. Put it after the checks the
package does on its inputs (boundary conditions of the operator and the
field, for example), not in front of them. After a package update, check
bit-for-bit agreement of the user's code before and after their own
changes, and run the package's tests that touch it: a new feature upstream
can break a fast path (a boundary phase of 0 that a fast path inverts).
Report the speed-up as measured on that machine, and the results as
unverified by this skill set unless a check here covers them.
