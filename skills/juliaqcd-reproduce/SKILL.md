---
name: juliaqcd-reproduce
description: "Reproduce a published lattice result or read an ILDG ensemble with JuliaQCD, through three gates: configuration, settings, result. Use when the user says 'same setup as arXiv:XXXX', or wants to measure on configurations made elsewhere: a public ensemble (ILDG, JLDG), files from a colleague (NERSC, openQCD, MILC), or another code."
---

# juliaqcd-reproduce

Status: placeholder. Not written yet.

## When this skill is called

Tell the user that this skill is not written yet: reading outside configurations and the three gates below are not automated or tested. Then, by case.

A published result:

1. Get the paper (arXiv) and read it; build the settings table from it with page, table, and equation numbers. Do not fill in values from memory.
2. If the user's request differs from the paper (for example a β the paper does not have), show both and let the user choose: reproducing the paper's point, or a new point that has nothing in the paper to compare with.
3. For a pure-gauge result that `juliaqcd-generate` and `juliaqcd-measure` cover, generate the ensemble with the paper's settings and compare one number from the paper before measuring anything new. Different update algorithms (heat bath in the paper, HMC here) sample the same distribution.

Configurations from elsewhere (downloaded ILDG ensembles, files from a colleague):

1. Ask for β, the action, the sea-quark content, and the source and citation terms of the data. Pure-gauge measurements on a dynamical ensemble are fine; label them as such.
2. Record what each file states about itself before converting anything (a NERSC header has PLAQUETTE, LINK_TRACE, CHECKSUM, and the precision; ILDG files carry their metadata in LIME records). ILDG: read with `load_configuration!(U, file; format=:ildg)` (Gaugefields). NERSC, openQCD, MILC: JuliaQCD has no reader. Ask the provider for ILDG files, or convert them with a code that reads the format and writes ILDG (for example Grid; follow its documentation), or ask the JuliaQCD developers. Do not write a binary reader or converter here.
3. Configuration gate: on each file, compare the plaquette (`measure_plaquette`, normalized to 1 on a cold field, averaged over all planes) with the recorded value, to about 1e-12 for double precision and 1e-6 for single, and check that the links are in SU(N). ILDG files often record no plaquette: then compare with the paper or the provider's list, and at least check SU(N), that the plaquettes of all files are close to each other, and that a JLD2 round trip of one file gives the same plaquette. The `:ildg` reader itself is untested here. Stop on a mismatch.
4. The JLD2 copies take as much disk as the originals; check the space first. Put the data on the machine that will measure it (download it there, or copy it once directly), not on a laptop. To use the measurement scripts, write the loaded configurations into a run folder as glue code: `checkpoints/conf_NNNNNN.jld2` with `save_configuration`, a `meta.toml` with `colors`, `lattice`, and `beta`, and a `history.csv` with at least the columns `traj` and `plaquette`. Number the configurations from 1 (the analysis keeps `traj > therm`, so with `therm=0` a configuration numbered 0 is dropped), in the order of the Monte Carlo chain, and ask how many trajectories separate them. There is no HMC history, so skip `monitor.jl` and pass `therm=0` to the analysis scripts; say that the autocorrelation then comes only from the measured observables. With fewer than about 40 configurations the bin cap leaves bin 1 and the errors assume independent configurations: say so.

## Planned scope

- Configuration gate: metadata matches the file, plaquette matches
- Settings gate: table of the paper's settings with page and equation numbers; blanks are asked, not guessed
- Result gate: reproduce one number from the paper before any new measurement
- Convention table against other codes (gamma matrices, kappa vs mass, link ordering, boundary conditions, normalization)
- The user obtains the data and checks the usage and citation terms
