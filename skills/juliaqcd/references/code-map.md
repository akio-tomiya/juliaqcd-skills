# Code map of JuliaQCD v1

Where things are in the source of the five v1 packages, and where to make
changes to add something. Used by "Questions about the code" in the entry
skill. Answer with locations and reasons; write no implementation unless
the user asks for one.

This file has the versions, how the packages fit together, and a table of
where to look first. The details are in one file per package, in the
folder `code-map/`: `LatticeMatrices.md`, `Gaugefields.md`,
`LatticeDiracOperators.md`, `QCDMeasurements.md`, `Wilsonloop.md`. Each has
a file map, a table of the main types and functions with their lines,
"Where to make changes", and "Notes". Read the file of the package the
question is about; a question that crosses packages needs several.

Versions: the registered versions of 2026-11-10, LatticeMatrices.jl
1.2.11, Gaugefields.jl 1.1.13, LatticeDiracOperators.jl 1.1.6,
QCDMeasurements.jl 1.0.2, Wilsonloop.jl 0.1.5. Paths are relative to each
package's root, and `file:N` is line N in that version. Lines move between
versions: before citing one, check the user's installed version
(`Pkg.status()`) and, if it differs, find the name again in the installed
source (`dirname(pathof(Gaugefields))` is its `src/` folder). Each package
still contains older code from before v1 (marked legacy in the package
files); answer for the v1 path unless the user works with the old one.

The map was written by reading the source, not by running it. "Notes"
records what looked surprising in the source (dead code, names that
mislead, possible bugs); a possible bug is unconfirmed until a test on a
small lattice shows it, and then belongs on the package's issue tracker.

`feature-map.md` was checked on older versions (its table gives them).
Its RHMC warnings apply to LatticeDiracOperators 1.1.5 and earlier; its
warning on `eigensystem` was found on 1.1.4 and has not been checked on
1.1.6. When citing a line of this map next to such a warning, say which
version the warning is from.

## How the packages fit together

- LatticeMatrices.jl, the bottom layer: a matrix at every site of a
  distributed lattice (`LatticeMatrix`), halo exchange over MPI, JACC
  kernels for CPU and GPU, random streams per site, matrix exponentials and
  projections, and the kernels of the Dirac operators and link smearings
  (`src/Operators/`, 4D).
- Wilsonloop.jl: Wilson loops and lines as symbols (`Wilsonline`), staples,
  and their derivatives. No lattice data.
- Gaugefields.jl: gauge fields built on `LatticeMatrix`, gauge actions from
  Wilson loops, molecular dynamics, heat bath, gradient flow, the smearing
  interface, gauge fixing, configuration files.
- LatticeDiracOperators.jl: fermion fields, the operator types that wrap the
  LatticeMatrices kernels, the string-based constructor `Dirac_operator`,
  fermion actions and forces, solvers, RHMC, eigenvalues.
- QCDMeasurements.jl: observables on configurations, gluonic and fermionic.

## Where to look first

| Question | Package | Location |
|---|---|---|
| Halo (ghost cell) update | LatticeMatrices | `set_halo!` src/LatticeMatrices_core.jl:700, one direction in `exchange_dim!` :1118; done lazily, tracked by `HaloEpoch` :31 |
| Launching a kernel over sites | LatticeMatrices | `_parallel_for_mutating!` src/LatticeMatrices_core.jl:319; site from the kernel index by `delinearize` src/Latticeindices.jl:127 |
| Random numbers | LatticeMatrices | `RNGStreamKey` src/utilities/randomgenerator.jl:98, `site_rng` :158 |
| Wilson operator stencil | LatticeMatrices | `mul!` src/Operators/WilsonDiracOperator.jl:60, kernel :80 |
| Choosing an operator by name | LatticeDiracOperators | `Dirac_operator(U, x, parameters)` src/Diracoperators.jl:162, the if-chain on the name at :168–220 |
| Fermion force | LatticeDiracOperators | Wilson `calc_UdSfdU_fromX!` src/action/WilsonFermiAction.jl:204; clover pullback in LatticeMatrices src/Operators/WilsonCloverPullback.jl:426 |
| RHMC coefficients | LatticeDiracOperators | stored tables src/rhmc/rhmc.jl:4–1093, `RHMC` :1136, generation with AlgRemez src/rhmc/AlgRemez.jl:54 |
| Solvers (CG, BiCGStab, multishift CG) | LatticeDiracOperators | src/cgmethods.jl; chosen in `solve_DinvX!` src/Diracoperators.jl:300 |
| Gauge action and its force | Gaugefields | `GaugeAction` src/action/GaugeActions.jl:40, `calc_dSdUμ!` :95, MD force `md_force!` src/molecular_dynamics.jl:279 |
| HMC integrators and trajectory | Gaugefields | `PQP`, `QPQ`, `SextonWeingarten` src/molecular_dynamics.jl:529–553, `md_trajectory!` :990 (no momentum refresh and no Metropolis step) |
| Exponential and projection to SU(N) | Gaugefields | `exptU!` src/4D/mpi_jacc/TA_gaugefields_4D_MPILattice.jl:196, `normalize_U!` src/4D/mpi_jacc/gaugefields_4D_MPILattice.jl:900 |
| Heat bath and overrelaxation | Gaugefields | src/heatbath/heatbathmodule.jl, SU(2) subgroups in `SUNupdate_matrix_rng!` :1179 |
| Gradient flow | Gaugefields | src/smearing/gradientflow.jl, `flow!` :171 |
| Link smearing | Gaugefields, LatticeMatrices | interface src/smearing/nhyp.jl (Gaugefields); kernels src/Operators/*Smearing.jl (LatticeMatrices) |
| Configuration files | Gaugefields | `save_configuration` src/API.jl:741, `load_configuration!` :822; NERSC src/output/nersc.jl, ILDG src/output/ildg_format.jl |
| Plaquette, Polyakov loop | Gaugefields | `measure_plaquette` src/API.jl:396, `measure_polyakov_loop` :413 |
| Other observables | QCDMeasurements | one file per measurement in src/measurements/; parameters in src/parameters/parameters.jl |
| Loop shapes for an action | Wilsonloop | `make_loops_fromname` src/Wilsonloop.jl:659 |

For a task that crosses packages, the "Where to make changes" parts of the
package files go together:

- A new Dirac operator: LatticeDiracOperators (types, methods, the name in
  `Dirac_operator`, the action), and LatticeMatrices `src/Operators/` for a
  new stencil kernel.
- A new gauge action: usually no source change (Gaugefields and Wilsonloop).
- A new observable: QCDMeasurements (or Gaugefields `src/API.jl` for a
  simple gauge one).
- A new gauge group: every SU(N) assumption listed under Gaugefields, the
  exponential and projection in LatticeMatrices, and the color size of the
  fermion fields in LatticeDiracOperators.
- Another dimension: LatticeMatrices is general; Gaugefields has 2, 3, and
  4; the v1 fermions and most measurements are 4D only; Wilsonloop defaults
  to `Dim = 4`.
