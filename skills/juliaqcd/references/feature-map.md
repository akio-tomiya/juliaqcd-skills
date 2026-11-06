# JuliaQCD v1 feature map

Checked against the default branches on 2026-11-06 (README, changes.md,
docstrings, source). Regenerate for each release; do not trust this file for
a newer version without checking.

## Versions

Julia 1.11 and 1.12 (the versions the packages are tested with).

| Package | Version checked | Lower bound for everything below |
|---|---|---|
| LatticeMatrices.jl | 1.2.9 | 1.2.8 |
| Wilsonloop.jl | 0.1.5 | 0.1.5 |
| Gaugefields.jl | 1.1.11 | 1.1.10 (learned link smearing since 1.1.7) |
| LatticeDiracOperators.jl | 1.1.4 registered | 1.1.4 (smeared-link HMC since 1.1.3, generalized domain-wall even-odd since 1.1.4) |
| QCDMeasurements.jl | 1.0.1 | 1.0.1 (local densities) |
| LatticeQCD.jl | 2.0.4 | 2.0 |

VisualizingLQCD.jl 0.0.1 requires Gaugefields 0.5 and cannot share an
environment with the v1 packages. Visualize ILDG files written by v1 in a
separate environment.

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
  - I/O: `save_configuration`, `load_configuration!` with ILDG (32 and 64
    bit), Bridge++ text, JLD2. JLD2 can be read back with a different
    process grid, device, or precision.
  - Enzyme automatic differentiation; learned link smearing (L-CNN, `LExp`).
  - Instanton initial configurations (SU(2) and embedded in SU(N)).
- **LatticeDiracOperators.jl**: Wilson, Wilson–clover, staggered, HISQ,
  Shamir and Möbius domain wall, generalized domain wall.
  - Even-odd preconditioning on the standard path: generalized domain wall
    (`"evenodd"=>true`).
  - Pseudofermions and dynamical-fermion HMC, also with smeared links
    (`SmearedFermiAction`, `NHYPSmearedFermiAction`).
  - RHMC (AlgRemez_jll); staggered and HISQ with Nf = 1, 2, 4, 8.
  - Solvers: CG, BiCG, BiCGStab, multishift CG. Eigenvalues of any operator
    by the Sakurai–Sugiura method (`eigensystem`).
  - `GeneralFermionAction` for a user-defined operator (force by Enzyme).
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
  Use `eigensystem` from LatticeDiracOperators instead.
- U(1) outside 2 dimensions is not documented (the code does not forbid
  4D, and tests use it). Heat bath and overrelaxation need Nc ≥ 2.
- A public random gauge transformation.
- Multi-GPU runs are experimental.
