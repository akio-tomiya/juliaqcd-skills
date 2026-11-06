---
name: juliaqcd-generate
description: "Generate gauge configurations with JuliaQCD (heat bath, overrelaxation, HMC with or without dynamical fermions) and monitor their quality. Use when the user wants an ensemble, or asks whether a run is thermalized, has a healthy acceptance rate, or suffers from topology freezing."
---

# juliaqcd-generate

Status: placeholder. Not written yet.

## Planned scope

- Cost estimate from a small-lattice measurement, shown before the run
- Thermalization, acceptance, ΔH, ⟨exp(−ΔH)⟩, reversibility
- Integrated autocorrelation time (Γ method)
- Topological charge history; warn before measuring if it is frozen
- Checkpoints, restart, ensemble metadata; never overwrite configurations
