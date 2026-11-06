---
name: juliaqcd-reproduce
description: "Reproduce a published lattice result or read an ILDG ensemble with JuliaQCD, through three gates: configuration, settings, result. Use when the user says 'same setup as arXiv:XXXX' or wants to measure something on public configurations."
---

# juliaqcd-reproduce

Status: placeholder. Not written yet.

## When this skill is called

Tell the user that this skill is not written yet: reading ILDG files and the three gates below are not automated or tested. Follow the common workflow of the `juliaqcd` skill, and take the settings table from the paper with page and equation numbers. For a pure-gauge result that `juliaqcd-generate` and `juliaqcd-measure` cover, generate the ensemble with the paper's settings and compare one number from the paper before measuring anything new.

## Planned scope

- Configuration gate: metadata matches the file, plaquette matches
- Settings gate: table of the paper's settings with page and equation numbers; blanks are asked, not guessed
- Result gate: reproduce one number from the paper before any new measurement
- Convention table against other codes (gamma matrices, kappa vs mass, link ordering, boundary conditions, normalization)
- The user obtains the data and checks the usage and citation terms
