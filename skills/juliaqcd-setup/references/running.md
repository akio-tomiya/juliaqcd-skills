# Environments, runs, and jobs on other machines

Read this before setting up JuliaQCD on a workstation, a cluster, or a GPU
machine, before starting a long run there, and before moving data between
machines. None of it is a tested script here; it is a procedure collected
from runs on shared lab machines, GPU workstations, and computing centers
with CUDA.jl and JACC (threads and CUDA). MPI.jl, AMDGPU.jl, and Metal.jl
in production are not covered by that experience: check the package
documentation. Site rules (batch system, accounts, partitions, storage,
maintenance) come from the site's documentation and the user, never from
guesses. Version numbers below are examples from one time and machine, not
recommendations.

## Environment

- Julia: pin the minor version per environment (juliaup channels,
  `julia +1.11`), and keep `Manifest.toml` per project. Machines drift
  apart even within one minor version, so do not hard-code the path of the
  `julia` binary in scripts: pass it through an environment variable, and
  record `VERSION` at run time. On a shared machine, install Julia from
  the official archive after checking its sha256, in the user's home.
- Set `JULIA_DEPOT_PATH` in the run script, not in `.bashrc`. Put the
  depot and the outputs on the large data partition, not on a small system
  partition, and on storage the compute nodes can see. Check the free
  space with `df` before starting. When borrowing another person's depot,
  put a writable depot of your own first (`mine:theirs:` plus the
  default), or the compile cache is written into theirs; never write
  into the borrowed one. A depot path that points to the wrong folder
  shows up as "package not found" (for example JLD2): at start-up, check
  the depot path and that the main packages load, and stop if not.
- Keep one depot per machine and project. A depot per run grew to tens of
  GB on one machine. A depot with CUDA.jl is a few GB (artifacts are the
  largest part; `compiled/` can be rebuilt and may be removed).
- Moving a project to another machine: copy `src/`, `Project.toml`,
  `Manifest.toml`, and `LocalPreferences.toml` (or rsync a given commit),
  compare checksums (sha256) of the copied files with the source, then run
  `Pkg.instantiate()`. `LocalPreferences.toml` holds the JACC backend; a
  project copied without it runs on the CPU without saying so. A package
  not in the registry is added with `Pkg.develop` or by path.
- Compute nodes without network: instantiate and precompile on a node that
  can reach the package server, with the same depot. A GPU package
  instantiated on a node without a GPU may not download its GPU artifacts;
  the first job then tries to fetch them on the compute node and fails
  after many minutes (seen with `CUDA_Runtime_jll`, again after a later
  version update). Pin the runtime artifact and instantiate where the
  network is, or put the artifact into the shared depot by its hash. In
  batch scripts set `JULIA_PKG_OFFLINE=true` and
  `JULIA_PKG_PRECOMPILE_AUTO=0`. If the CPU of the compute node differs,
  the first load recompiles for minutes; warm the cache with a short job
  that only loads the GPU package and checks it (`CUDA.functional()`).
  For CUDA.jl, `CUDA.set_runtime_version!` on a node with network writes
  the runtime version into `LocalPreferences.toml`; check the compute
  node's driver with `nvidia-smi` first, then instantiate and precompile
  there.
- CUDA.jl: let it use its own toolkit artifact. Do not put a system CUDA
  in `LD_LIBRARY_PATH` (a site module can do this too); CUDA.jl warns that
  it loaded system libraries, and running with `env -u LD_LIBRARY_PATH`
  removes the warning. Put tools such as `nvcc` on `PATH` only. On an old
  driver, pin the last CUDA.jl series that supports it in the Manifest and
  do not run `Pkg.update()`.
- Read versions from the right place: the kernel driver is what
  `nvidia-smi` shows, not the `CUDA_Driver_jll` version in the Manifest. A
  project that "works" with a new Julia proves nothing about CUDA.jl unless
  its Manifest contains CUDA.jl.
- `Failed to initialize NVML: Driver/library version mismatch` from
  `nvidia-smi`, and CUDA.jl finding no GPU, mean that an update replaced
  the driver libraries while the old kernel module is loaded. A reboot
  fixes it; wait for running GPU jobs first. Where a machine must not stop
  (a lending period), hold the kernel and driver packages back from
  automatic updates and update them by hand.
- MPI: MPI.jl uses its own MPICH by default, which is not GPU-aware. A
  GPU-aware MPI is the system's (set with MPIPreferences) or one built for
  the purpose. Before spending time on it, check whether the GPUs can
  reach each other directly (peer-to-peer); without that, halo exchange
  goes through the host anyway.
- Julia 1.12: `@eval using CUDA` inside a function and a call from the
  same function fail with a world-age error. Load packages at top level
  (or call through `Base.invokelatest`).
- A warning at load time (for example from a package that uses Requires)
  may be harmless: compare with the output of a run known to be good
  before acting on it.
- Helper scripts in other languages: call a fixed interpreter version; an
  old default can fail on non-ASCII text.
- Mixed package versions (an old global environment, a `Manifest.toml`
  made with another Julia) show up as errors from inside packages; see
  `juliaqcd-setup` SKILL.md.

## Before a run counts

- Check at start-up, from inside the run (for example a small file loaded
  with `julia -L` before the script): the backend, the device name, the
  Julia version, the path of the active environment, and the code version
  (a commit hash). Print one line saying the check passed. A run whose log
  lacks that line is not production: it may have run on the CPU or loaded
  another environment.
- Write at the head of the log: job id, node, working folder, date,
  `julia --version`, loaded modules, `nvidia-smi`, threads,
  `JULIA_PROJECT`, the script name, package versions, the GPU name and
  CUDA and driver versions, and the sha256 of the input configuration, the
  code, `Project.toml`, `Manifest.toml`, and `LocalPreferences.toml`.
- Trial in two stages on the target machine. First the plumbing on 4⁴: a
  cold SU(3) configuration has plaquette 1, the GPU package is functional
  (false is correct on a node without a GPU), the device count and
  versions are as expected, the depot is visible, the output format can be
  written and read back, and the GPU's UUID is the intended one. On a
  machine with several GPUs, run a tiny kernel on each device, set
  `CUDA_DEVICE_ORDER=PCI_BUS_ID`, and check that the UUID of the device
  Julia uses is the one chosen in `nvidia-smi` (the two can number devices
  differently). Then the
  numbers: the same input through the CPU and the GPU backends, the same
  output lines, and differences within the tolerance written beforehand
  (`juliaqcd/references/performance.md`). A GPU path that does not agree
  is not used.
- Then a short trial of the real thing: one trajectory (fewer MD steps
  are fine) or one configuration. Look at ΔH, acceptance, plaquette, time,
  and the check line, and keep that log as the evidence before production.
  Rebuild the time estimate from this trial.
- Measurements check their input: the checksum of each configuration
  against what the generating run recorded, and the code version that
  made it. Stop on a mismatch.
- Save the settings of each segment of a run (MD steps, step size,
  tolerances, couplings) in the segment's folder, and read them from there
  for a restart or a comparison, never from memory or another segment. If
  reading a checkpoint does not check the couplings, compare them with the
  saved settings before starting.

## Running

- Threads: derive the number from what the scheduler gave
  (`JULIA_NUM_THREADS=${SLURM_CPUS_PER_TASK:-1}`, then `julia
  --threads=$JULIA_NUM_THREADS`); on a shared machine without a scheduler,
  at most the cores the run may use. Choose the number by measurement
  (`juliaqcd/references/performance.md`). With many processes, give each
  one thread and set `OPENBLAS_NUM_THREADS=1` and `OMP_NUM_THREADS=1`, or
  BLAS starts its own threads.
- `julia --project=.` looks in the current folder: `cd` to the job's
  folder first.
- Request CPUs and memory explicitly. On some GPU partitions CPUs and
  memory come with each GPU, and a large memory request takes more CPUs.
- GPUs: select one with the backend's variable (`CUDA_VISIBLE_DEVICES` for
  NVIDIA). It does not restrict other users. Before starting, look at
  `nvidia-smi`; do not share a GPU with another job, and let a queue of
  measurements wait while one is there. Judge load by the process list and
  its owner, not by the power reading.
- Workstation GPUs and CPUs can run hot under many threads. Watch the
  temperature on a new machine; a watcher can pause a run (SIGSTOP) while
  the temperature stays high and resume it (SIGCONT).
- On a GPU, one or a few CPU threads are enough (`JULIA_NUM_THREADS=1`,
  `OPENBLAS_NUM_THREADS=1`, a few cores for the job).
- Measure the speed of a running job from its progress lines in the log
  (count them twice, minutes apart), not from the output file, which may
  be written only at the end.
- Starting Julia once per unit of work costs compilation each time; on a
  GPU borrowed for a short while, the gaps also let other jobs take the
  GPU. Run several units in one Julia process there.
- Do not compare speeds of jobs that ran on different nodes. A newer Julia
  or GPU package is not automatically faster; measure.
- A long run on a remote machine without a batch system:
  `cd WORKDIR; setsid nohup COMMAND > LOG 2>&1 < /dev/null &`, started
  through `ssh -n`. Joining `cd` and the command with `&&` kept the ssh
  session from returning. A run in the foreground over a VPN or a laptop
  connection stops when the connection drops.

## Batch jobs

- Write the batch script from the site's documentation, run a short job
  first, and submit nothing without the user's approval. Debug partitions
  are for debugging the script itself; short checks go to a normal short
  partition.
- In a non-login batch shell `module` may not exist: source the site's
  module initialization at the top. Name output files with the job name and
  id (`%x-%j` in Slurm), so nothing is overwritten.
- Where the login shell is not bash, send a script through `bash -s` on
  standard input. Inside such a script, an `ssh` or `srun` reads the rest
  of the script from standard input and the script stops silently: give
  `ssh` the `-n` option and `srun` and `julia` `< /dev/null`.
  Keep the environment settings in one file sourced by the script rather
  than passing them on the command line (`sbatch --export` splits values at
  commas).
- Split a run that is longer than the time limit into jobs within the
  limit, with the length computed from the measured time per trajectory.
  Inside the job, check the remaining time and do not start a unit that
  cannot finish, so no half-written output is left when the limit hits.
  Chain them with dependencies (`afterok`, or `singleton` for one at a
  time) and check the dependency after submitting. A failed job leaves the
  later ones waiting forever (`DependencyNeverSatisfied` in Slurm): look at
  the queue and clean up.
- Give an explicit time limit (`-t`) before a scheduled maintenance; jobs
  with the default limit may be held or stopped. Review automatic
  resubmission before the stop.
- Do not connect to a center's login node many times in a short while; it
  can stop answering for many minutes. Reuse one connection (ssh
  `ControlMaster`) and space out status checks. Do not compute on login
  nodes.

## Long runs

- Split a long chain into segments. At the end of each segment, check it
  (number of trajectories, checkpoint present, settings saved, no leftover
  temporary files, no NaN or Inf) and write a line saying the segment is
  complete; after the last, a line saying the run is complete.
- Chain the segments by checksum: record the sha256 of each checkpoint
  read and written, and check it before the next segment starts. Keep the
  trajectory numbers continuous. Give each segment its own seed, derived
  from the run's seed and the trajectory number, so a restart reproduces
  the chain (`hmc_puregauge.jl` does this).
- Do not replace the physics code of a running chain. New scripts go to a
  separate place after the code's checksum is checked. Never edit an
  expected checksum to make a failing check pass. A configuration made
  only to recover from a failure is recorded as such and not used in the
  analysis.
- Stop at a segment boundary with a file the run looks for (a `STOP`
  file), not with `kill`. A run can also check at each checkpoint for the
  file and for another user's process on its GPU, write a checkpoint, and
  exit. When resuming, rename the file instead of deleting it, so the stop
  and the restart stay on record. Before stopping someone's run, look at
  its log and timing to see whether it is in the middle of a segment.
- Restart automatically only a run that stopped for a reason on the
  machine's side, with the same code version. Starting a new run is the
  user's decision; on a shared machine, put no cron job or service that
  starts runs by itself.
- On a machine shared by several people or agents, keep a register of
  runs: who owns each, its process id and folder. Only the owner starts or
  stops a run, and a run is marked running only after its trial passed.
  Never kill another person's process.
- Outputs per configuration are never overwritten when they have content.
- For many independent units (measurements on many configurations), keep
  the list of units in one file, and let each job take the first unit
  without a done or failed marker, with a claim marker while it works. A
  job stopped anywhere is then continued by the next. A unit is done only
  after its output passes the check; an output that fails is renamed and
  kept, and the job stops, so one cause does not fail unit after unit.
- Check outputs by machine: line counts, the last flow time or trajectory,
  no NaN or Inf, the completion record, no temporary files left. Check the
  content as well as the line count; a header of a different length is
  not a wrong result.
- Count measurements by configuration number, not by the number of runs:
  a configuration measured twice counts once.
- Before removing a lock or a half-written file of a stopped run, check
  that the process id written in it is dead; otherwise a second copy of
  the run starts.

## Watching

- A watcher reports when it finds a problem or the end, and then exits. A
  watcher that reports every few minutes is noise, and a waiting loop that
  never ends is a leak: one stayed for a month because `pgrep -f` matched
  its own command line. Write the pattern so it cannot match itself
  (`pgrep -f "[j]ulia"`), and give every wait a time limit.
- Two kinds help: one that matches log lines (FAIL, STOP, the completion
  line), and one that fires when a GPU has had no compute process for a
  while (an idle GPU is lost time).
- Find sensors by name, not by number (`coretemp`, not `hwmon3`); numbers
  change at reboot.
- Run watchers and relays on a lab machine that stays up, not in an
  interactive session or on a laptop; when those stop, the watcher stops
  with them.
- Report "cannot reach the machine" separately from "the run failed",
  and retry a failed connection a few times before deciding that a job is
  gone. Use
  an address the watching machine can actually reach; the first address a
  machine lists for itself may be a container bridge.
- When a running chain feeds a measurement, hand over configurations at
  the rate the measurement consumes them, and update the estimate from
  the first measured configuration.

## Data and disks

- Estimate the disk before starting: one checkpoint is one link field
  (Nc² complex numbers per link; a 32⁴ SU(3) field is about 0.6 GB), times
  the number kept. Runs that write hundreds of GB a month fill a
  workstation: check `df` daily, warn at about 85 %, and aim to stay
  below 80 %.
- Move data directly between lab machines or cluster storage, never
  through a laptop: a large relay through a laptop has filled its memory
  and disk. Pull from the receiving machine. If a relay is needed, run it
  on a lab machine (`ssh SRC cat FILE | ssh DST "cat > FILE.part"`), then
  check and rename. Keep keys off shared machines, and do not forward an
  ssh agent to a machine others administer.
- Limit the load: one rsync at a time on a center's nodes, with `nice`,
  `ionice -c3`, or a bandwidth limit. External USB disks and Wi-Fi are
  slow: write long jobs to an internal disk, and move large configurations
  between wired machines.
- Check every transfer two ways: `rsync -a -c -n -i` shows no differences
  (apart from folder attributes), and the lists of both sides match (sha256
  per file, symlink targets, count, and bytes, sorted with `LC_ALL=C`).
  Then mark the folder as verified. Some `awk` versions print sums above
  2³¹ − 1 wrongly with `%d`; use `%.0f`. `rsync -a` copies symlinks as
  links, not their targets; to a disk without Unix permissions use
  `rsync -rlt`.
- Over a slow connection, large ssh output stalls: summarize on the remote
  machine and bring back small results.
- Send to a new dated folder on the receiving side, never into an existing
  one, and keep the source. Compare the sha256 at the source with what the
  generating run recorded before sending, and again at the destination.
  On the first connection to a machine, check its host key against a
  fingerprint you have from a trusted source.
- If another project is filling a shared disk, do not delete your own data
  to make room in a hurry: tell the other user and the administrator, and
  copy, compare, then delete.
- Log progress inside a long step (time per stage, the convergence measure
  during iterations, time and residual per solve). A log with only a final
  line hid a gauge fixing that did not converge for hours. Skip a
  configuration that does not converge, with the reason, and measure it
  again later with other settings.
- Choose the number of parallel processes from the peak memory; a machine
  short of memory kills processes (SIGKILL).
- Clean up without wildcards: list what would be removed (a dry run),
  check each path, and remove one at a time. Move before deleting, compare
  the copy, then delete the old one and leave a symlink if others expect
  the path. The trash is not a safety net on a remote machine. Use the
  home quota, not `/tmp`, on shared machines.

## Sharing machines

Look at `nvidia-smi` and the process list before every use, and do not
start if someone else is there. Run CPU analysis on a shared machine with
`nice`. Do not stop or reprioritize other people's jobs. Agree on GPU time
with the other users of the machine.
