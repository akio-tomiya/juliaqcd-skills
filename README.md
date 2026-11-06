# juliaqcd-skills

Agent skills for lattice gauge theory with [JuliaQCD](https://github.com/akio-tomiya/LatticeQCD.jl) (v1 and later), for Claude Code and Codex.

Status: early skeleton. The entry skill and the list of sub-skills are in place; their contents are not written yet.

## What it is for

Install the skills, then ask in plain language, for example:

- "Run quenched HMC for SU(4) in three dimensions."
- "Change the gauge group of this code from U(1) to SU(N)."
- "Read this ILDG ensemble and measure the Dirac eigenvalues with the same setup as arXiv:XXXX.XXXXX."

The skills put verification first. Every request goes through a settings table, a small-lattice trial, and checks that print pass or fail, before any production run.

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

## Supported versions

Julia 1.11 and 1.12, JuliaQCD v1 and later. Code written for v0.6 or earlier is translated, not supported.

## Citation

If you use JuliaQCD, cite arXiv:2409.03030.

## License

MIT
