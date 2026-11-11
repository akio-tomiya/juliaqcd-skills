# JuliaQCD v1 feature map

Checked against the default branches on 2026-11-06 (eigenvalue, I/O, and LatticeQCD compat entries against the installed source on 2026-11-07) (README, changes.md,
docstrings, source). Regenerate for each release; do not trust this file for
a newer version without checking.

## Versions

Julia 1.11 and 1.12 (the versions the packages are tested with).

| Package | Version checked | Lower bound for everything below |
|---|---|---|
| LatticeMatrices.jl | 1.2.9 | 1.2.8 |
| Wilsonloop.jl | 0.1.5 | 0.1.5 |
| Gaugefields.jl | 1.1.11 (NERSC I/O read in the 1.1.13 source) | 1.1.10 (learned link smearing since 1.1.7, NERSC I/O since 1.1.12) |
| LatticeDiracOperators.jl | 1.1.4 (RHMC checked again on 1.1.6) | 1.1.4 (smeared-link HMC since 1.1.3, generalized domain-wall even-odd since 1.1.4) |
| QCDMeasurements.jl | 1.0.1 | 1.0.1 (local densities) |
| LatticeQCD.jl | 2.0.4 | 2.0 |

LatticeQCD.jl 1.3 and earlier need Gaugefields 0.7 or older (before v1);
LatticeQCD 2.0 needs Gaugefields 1.1.4 or later, LatticeDiracOperators
1.1.2 or later, and QCDMeasurements 1. An environment that resolves to
LatticeQCD 1.x is a pre-v1 environment: errors from inside `run_wizard()` or
`run_LQCD` there are version problems, not bugs in the user's input. Check
with `Pkg.status()` and create a fresh environment with LatticeQCD 2.

VisualizingLQCD.jl 0.1.0 (registered, Julia 1.11 or later) requires
Gaugefields 1.1 and shares an environment with the v1 packages; it reads
the JLD2 and ILDG files that v1 writes (`juliaqcd-visualize`). Version
0.0.1 required Gaugefields 0.5 and could not.

## Packages

Higher packages depend on lower ones.

- **LatticeMatrices.jl**: real or complex matrices on a lattice of any
  dimension. MPI domain decomposition and JACC run the same code on CPU and
  NVIDIA, AMD, and Intel GPUs; multi-GPU runs are marked experimental.
  `normalize_matrix!` projects each site onto SU(N) (onto SO(N) for real
  element types). ComplexF32 support, device-direct MPI (CUDA, ROCm),
  decomposition-independent random streams.
- **Wilsonloop.jl**: Wilson loops and lines defined symbolically, for any
  number of colors and dimensions; staples (`make_staple`) and derivatives
  (`derive_U`). No adjoint-representation links.
- **Gaugefields.jl**: `gauge_configuration` for SU(Nc) in 2, 3, 4 dimensions
  with any action built from Wilson loops. U(1) is documented in 2
  dimensions only.
  - Heat bath and overrelaxation (`heatbath_updater`, Nc ≥ 2).
  - HMC molecular dynamics: `md_driver`, `md_trajectory!`; integrators QPQ,
    PQP, Sexton–Weingarten, or user-defined.
  - Momentum normalization: default p²/2; Grid/Bridge++ with
    `momentum_denominator=2` and Gaussian width √2.
  - Gradient flow (`gradient_flow`, `flow!`), also for general actions.
  - Smearing: APE, stout, HYP, HEX, nHYP (4D, LatticeMatrices path). APE
    and HYP in HMC need `projection=:polar`.
  - Gauge fixing: Landau and Coulomb in 4D (`gaugefixing!`).
  - Z(Nc) 2-form gauge fields ('t Hooft flux) and twisted boundary
    conditions (4D); dynamical B field for SU(N)/Z(N).
  - I/O: `save_configuration(file, U; format)` and
    `load_configuration!(U, file; format)` with `format=:jld2` (default),
    `:ildg` (32 and 64 bit), `:bridge` (Bridge++ text), or `:nersc`
    (Gaugefields 1.1.12 or later; 4D SU(3) only; two-row or full matrices,
    32 or 64 bit, either byte order; the header's checksum, plaquette, and
    link trace are checked on reading). The allocating
    `load_configuration(file; format)` takes `:jld2` or `:nersc`. JLD2 can
    be read back with a different process grid, device, or precision. No
    openQCD or MILC format.
  - Enzyme automatic differentiation; learned link smearing (L-CNN, `LExp`).
  - Instanton initial configurations (SU(2) and embedded in SU(N)).
- **LatticeDiracOperators.jl**: Wilson, Wilson–clover, staggered, HISQ,
  Shamir and Möbius domain wall, generalized domain wall.
  - Even-odd preconditioning on the standard path: generalized domain wall
    (`"evenodd"=>true`).
  - Pseudofermions and dynamical-fermion HMC, also with smeared links
    (`SmearedFermiAction`, `NHYPSmearedFermiAction`).
  - RHMC (AlgRemez_jll) for staggered and HISQ. In LatticeDiracOperators
    1.1.5 and earlier (found on 1.1.4) the stored rational approximations
    for Nf = 1 are wrong (the force misses a finite difference by about
    18%), some orders stop with an error, and computing a new table can
    fail on macOS: use 1.1.6 or later. On 1.1.6 the regression tests for
    these passed (reported on 2026-11-10: the stored tables, new tables
    from AlgRemez on macOS, and the Nf = 1 and 2 forces against finite
    differences). Untested here: before any use, compare the RHMC force
    with a finite difference on a small lattice.
  - Solvers: CG, BiCG, BiCGStab, multishift CG.
  - Eigenvalues by the Sakurai–Sugiura method (`eigensystem`). In 1.1.4
    (not checked again on 1.1.6) it stops for `GeneralFermion` operators, and its fixed acceptance
    threshold can discard correct eigenvalues. Untested here: compare with
    a dense diagonalization on a small lattice first.
  - `GeneralFermionAction` for a user-defined operator (force by Enzyme),
    four dimensions only.
  - Standard path: 4D, and 5D for domain wall.
- **QCDMeasurements.jl**: plaquette, Polyakov loop, Wilson loops, t₀ and w₀,
  topological charge (including improved definitions), topological and
  action densities, gluon correlators. Fermionic measurements by operator:

  | Measurement | Operators |
  |---|---|
  | Pion and meson correlators | Wilson, clover, staggered |
  | PCAC mass | Wilson, clover |
  | Residual mass | domain wall (Shamir) |
  | Chiral condensate | Wilson, staggered |
  | Eigenvalues of D (`EigenvalueMeasurement`) and of M†M (`MdagMSpectrumMeasurement`) | Wilson only (Arpack) |

  `EigenvalueMeasurement(U; fermiontype="Wilson", κ=1, r=1, nev=10,
  which=:SM, isDdagD=false, solver="Arpack", BoundaryCondition=nothing)`
  (QCDMeasurements 1.0.1): `measure` builds D as a sparse matrix and calls
  Arpack `eigs(D; nev, which)`, or `eigs(D†D)` with `isDdagD=true`;
  `solver="exact"` diagonalizes the dense matrix. The default κ = 1 is not
  a physical choice: always pass κ.

  Dimension limits, checked with QCDMeasurements 1.0.1:
  `WilsonLoopMeasurement` works in 4D only (in 2D and 3D its constructor
  throws, and its normalization assumes three spatial directions);
  `GradientFlowScaleMeasurement` and the topological charge are 4D only.
  `estimate_flow_scales` gives leave-one-out jackknife errors without
  binning, too small for autocorrelated configurations.
  `juliaqcd-measure` covers Wilson loops and the flow energy density in any
  dimension, with binned errors.

- **LatticeQCD.jl**: wraps Wilsonloop, Gaugefields, LatticeDiracOperators,
  and QCDMeasurements. Interactive setup with `run_wizard()`. 4D only.
  Domain wall (Shamir, Möbius) is experimental. SLHMC and measurement-only
  runs.

## Not available

State these plainly; do not invent APIs for them.

- Gauge groups other than SU(Nc) and U(1): no SO(N), Sp(2N), G₂. See
  `juliaqcd-extend`.
- QCDMeasurements eigenvalue measurement for operators other than Wilson.
  `eigensystem` from LatticeDiracOperators is the candidate, with the
  caveats above.
- Readers for openQCD or MILC configurations, and NERSC before Gaugefields
  1.1.12. Convert them to ILDG with another tool, or ask the JuliaQCD
  developers.
- Wilson fermion boundary phases through `Initialize_pseudofermion_fields`:
  its `boundarycondition` keyword is dropped silently (always (1, 1, 1, −1)),
  and the operator's `"boundarycondition"` parameter is not used; the
  phases stored in the field act. `MesonCorrelatorMeasurement` accepts only
  the default phases. See `juliaqcd-measure/references/mesons.md`.
- U(1) outside 2 dimensions is not documented (the code does not forbid
  4D, and tests use it). Heat bath and overrelaxation need Nc ≥ 2.
- A public random gauge transformation.
- Multi-GPU runs are experimental.
