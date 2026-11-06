# juliaqcd-skills

[日本語](README.ja.md)

Agent skills for lattice gauge theory with [JuliaQCD](https://github.com/akio-tomiya/LatticeQCD.jl) (v1 and later), for Claude Code and Codex.

Status: early version. Written and tested: pure-gauge HMC with run-quality monitoring (`juliaqcd-generate`), pure-gauge measurements with the gradient flow, t0, w0, Wilson loops, and the static potential, and quenched Wilson and Wilson–clover meson correlators with effective masses (`juliaqcd-measure`), and a reference implementation of gauge groups with checks (`juliaqcd-extend`). The other skills are placeholders.

## What it is for

Install the skills, then ask in plain language, for example:

- "Run quenched HMC for SU(4) in three dimensions."
- "Change the gauge group of this code from U(1) to SU(N)."
- "Read this ILDG ensemble and measure the Dirac eigenvalues with the same setup as arXiv:XXXX.XXXXX."

The skills put verification first. Every request goes through a settings table, a small-lattice trial, and checks that print pass or fail, before any production run. For pure-gauge HMC the checks are reversibility, ΔH scaling with the step size squared, links staying in SU(N), and known values at β = 0, strong coupling, and weak coupling. A good acceptance rate and ⟨exp(−ΔH)⟩ = 1 do not show that the chain samples the intended β; the known values do. For measurements, every number is compared with an independent implementation on plain arrays, and in two dimensions generation and measurement together reproduce the exact area law W(R,T) = u(β)^(RT). Each check is itself tested against deliberately broken code (`selftest*.jl`).

More prompts, with what the agent should do, are in [examples/prompts.md](examples/prompts.md).

## Skills

| Skill | Role |
|---|---|
| `juliaqcd` | Entry point; routes the request and sets the common workflow |
| `juliaqcd-setup` | Environment, versions, GPU, MPI |
| `juliaqcd-generate` | Configuration generation and run-quality monitoring |
| `juliaqcd-measure` | Measurements |
| `juliaqcd-analyze` | Statistical analysis and error budget |
| `juliaqcd-visualize` | Figures and visualization |
| `juliaqcd-reproduce` | Reproduction from ILDG ensembles and arXiv papers |
| `juliaqcd-extend` | New groups, actions, operators, flows |

## Install

Claude Code:

```
/plugin marketplace add akio-tomiya/juliaqcd-skills
/plugin install juliaqcd-skills@juliaqcd-skills
```

Codex: copy the folders under `skills/` into your Codex skills directory. (Not tested yet.)

Then create a JuliaQCD environment once:

```
julia --project=env -e 'using Pkg; Pkg.add(["Gaugefields", "JACC", "QCDMeasurements", "LatticeDiracOperators", "StableRNGs", "JLD2", "Wilsonloop"])'
```

Compiling JuliaQCD takes about 1.5 GB of memory. Run the checks and the simulations on a workstation or cluster node rather than a laptop with little memory; the skills do the same.

## Supported versions

Julia 1.11 and 1.12, JuliaQCD v1 and later (Gaugefields 1.1.10 and later, and so on; see `skills/juliaqcd/references/feature-map.md`). Code written for v0.6 or earlier is translated with `skills/juliaqcd/references/legacy-api.md`, not run as is.

## Reporting problems

Open an issue at https://github.com/akio-tomiya/juliaqcd-skills/issues, in English or Japanese. Please include the request you gave the agent, the Julia and package versions (the `Manifest.toml` of the environment), and the output of the check that failed. A bug in a JuliaQCD package itself belongs to that package's repository; if you are not sure which it is, report it here.

## Citation

If you use JuliaQCD, cite arXiv:2409.03030.

## License

MIT
