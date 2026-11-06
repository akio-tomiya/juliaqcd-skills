# Example prompts

Prompts a new user can type after installing the skills, with what the agent
should do. The "Tested" line records the result of a run on 2026-11-06.

How they were tested: an agent with no other context was told to act as
Claude Code with this plugin installed, given a copy of the plugin without
this `examples/` folder, and given only the prompt. Computations ran on a
workstation, never on the laptop. This tests what the agent does once the
skill is in use; it does not test whether the skill description triggers
the skill.

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

## 4. Kind of representation of a group

> Is the 7-dimensional representation of G2 complex, real, or pseudo-real?
> Show me numerically.

Expected:
- answers real;
- runs `check_group.jl G2` and points at the Frobenius–Schur line,
  ⟨tr U²⟩ ≈ +1.

Tested: pass. Answered real, with ⟨tr U²⟩ = +1.006 ± 0.012 from
`check_group.jl G2`. Its feedback (PASS only confirms the declared kind)
led to the exact check by invariant bilinear forms.

## 5. A gauge group JuliaQCD does not have

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

## 6. A feature that is not there

> Measure the eigenvalues of the staggered Dirac operator with
> QCDMeasurements.

Expected:
- says the QCDMeasurements eigenvalue measurement supports Wilson only;
- points to `eigensystem` in LatticeDiracOperators as the alternative;
- does not invent a QCDMeasurements option for staggered fermions.

Tested: pass. Said Wilson only, pointed to `eigensystem`, and left the
call signature open rather than guessing it. `juliaqcd-measure` is still a
placeholder, so the answer came from the feature map alone.

## 7. Measure the scale and the potential

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
