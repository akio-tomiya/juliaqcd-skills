# Gaugefields.jl 1.1.13: code map

Part of `../code-map.md`; read its first part (versions, how to cite a line) before this one. Paths are relative to the package root; `file:N` is line N in version 1.1.13.

## File map
(Paths are relative to the package root. **v1** marks the LatticeMatrices/JACC standard path. **legacy** marks code kept only for compatibility. Items without a tag are shared by both.)
- `src/Gaugefields.jl`: main module. Sets the include order (lines 5-29, 386-389) and holds most imports and exports.
- `src/API.jl`: **v1** high-level API. Backend selectors, `gauge_configuration`, accessors, momenta, `measure_*`, `gradient_flow`, `heatbath_updater`, `stout_smearing`, `smear`, and JLD2/Bridge/ILDG/NERSC save and load dispatch.
- `src/molecular_dynamics.jl`: **v1** MD layer. Action-provider protocol, `MDActionSet`, smeared and B-field action wrappers, integrators, `MDDriver`, `md_trajectory!`.
- `src/AbstractGaugefields.jl`: the core `AbstractGaugefields_module`.
  - Contains the abstract types, `Initialize_Gaugefields`, `RandomGauges` and `IdentityGauges` (these choose the concrete type), generic Wilson-line evaluation, plaquette/staple/Polyakov, `exptU!`/`exp_aF_U!`, `add_force!`, topological charge.
  - It mixes both paths: the generic code also serves the legacy types.
- `src/TA_Gaugefields.jl`: abstract type for traceless anti-Hermitian (momentum/force) fields, `initialize_TA_Gaugefields`, `gauss_distribution!`, and SU(N>3) Lie-algebra kernels.
- `src/4D/mpi_jacc/{gaugefields,TA_gaugefields}_4D_MPILattice.jl`: **v1** concrete 4D link and momentum types, which wrap `LatticeMatrix`.
- `src/3D/mpi_jacc/*`, `src/2D/mpi_jacc/*`: **v1** concrete 3D and 2D link and momentum types.
- `src/{2D,3D,4D}/gaugefields_*D.jl`, `TA_gaugefields_*D.jl`: per-dimension abstract types plus includes.
- **legacy** per-dimension implementations:
  - `src/4D/nowing/*`, `src/4D/TA_gaugefields_4D_serial.jl`
  - `src/3D/{gaugefields_3D_nowing,TA_gaugefields_3D_serial}.jl`
  - `src/2D/{gaugefields_2D_nowing,TA_gaugefields_2D_serial,Isingfields_2D}.jl`
  - The 4D nowing type is still used as a host staging copy (topological charge, Bridge load, B flux).
- `src/4D/deprecated/**`, `src/2D/deprecated/**`, `src/smearing/deprecated/**`: **legacy** wing/accelerator/CUDA/JACC-kernel storage and adjoint representation.
- `ext/deprecated/mpi/**`: **legacy** MPI types, loaded by `@require MPI` in `src/4D/gaugefields_4D.jl:24-41`.
- `src/Adjoint_rep_Gaugefields.jl`: **legacy** adjoint-representation shim.
- `src/MPILattice/MPILattice.jl`: thin re-export shim of LatticeMatrices functions. It is not a separate implementation.
- `src/LatticeMatricesCompat.jl`, `src/communication.jl`: version shims for LatticeMatrices, and the serial communicator (overridden for MPI by `ext/GaugefieldsMPIExt.jl`).
- `src/Temporalfields/temporalfields.jl`: pool of temporary work fields (`Temporalfields`, `get_temp`, `unused!`).
- `src/SUN_generator.jl`: SU(N) generators `Generator(NC)`, `lie2matrix!`, `matrix2lie!`.
- `src/ND.jl`: numerical-derivative helpers (Wirtinger, Enzyme check). Included at the end of `AbstractGaugefields.jl`.
- `src/autostaples/{wilsonloops,Loops}.jl`: older Wilson-loop and staple data structures. The v1 code uses `Wilsonline` and `make_loops_fromname` from the external Wilsonloop.jl package instead.
- `src/action/GaugeActions.jl`: `GaugeAction` (Wilson-loop action), its derivative `calc_dSdUμ!`, and its evaluation.
- `src/Bfields/{Bfields,ScalarBfields,GaugeActions_Bfields}.jl`: Z(N) 2-form (`Bfield`), 't Hooft flux, and the B-aware action, plaquette and force.
- `src/heatbath/heatbathmodule.jl` (plus `portable/kernels.jl`, `portable/rng_protocol.jl`, `rng_adapters.jl`): heat bath and overrelaxation.
  - v1 device kernels for MPILattice types (site RNG, colorings).
  - Legacy serial methods live in the same file.
- `src/smearing/gradientflow.jl` (+ `gradientflow_Bfields.jl`): Wilson-flow and general-action flow integrators.
- `src/smearing/nhyp.jl`: **v1** native link smearings (nHYP, stout/EXP, HEX, APE, HYP). They are thin wrappers over LatticeMatrices.
- `src/smearing/Abstractsmearing.jl`, `stout.jl`, `stout_fast.jl`, `stout_dataset.jl`, `CASK_smearing.jl` + `CASK/*`: the older but still exported `CovNeuralnet`/`CovLayer` smearing framework (`STOUT_Layer`, the CASK attention layer). `stout.jl` is mostly commented out.
- `src/gaugefixing/*`: Landau/Coulomb gauge fixing.
  - `gaugefixing_common.jl` and `gaugefixing_local_matrix.jl` are generic.
  - `gaugefixing_utility_4D_MPILattice.jl` plus `kernelfunctions/gaugefixing_utility_jacc.jl` are v1.
  - `*_nowing*`, `*_legacy_mpi`, `*_wing_mpi`, `*_cuda` are legacy.
- `src/output/io.jl`: object-serialized JLD2 (`saveU`/`loadU`). Legacy format, but still the fallback in `load_configuration`.
- `src/output/ildg_format.jl`: ILDG/LIME. Its MPILattice methods sit inside an `@require JACC` block.
- `src/output/bridge_format.jl`: Bridge++ text format.
- `src/output/nersc.jl`: NERSC read/write (v1, SU(3) and 4D only).
- `src/output/verboseprint_mpi.jl`: verbosity printing.
- Not included anywhere (dead/orphan): `src/Gaugefield_misc.jl`, `src/output/{analyze,print_config,numpy_format,visualize,verboseprint}.jl`.
- `src/lcnn/*`: LCNN (lattice gauge-equivariant CNN) module, which adds `LCNNLinkSmearing`.
- `ext/GaugefieldsEnzymeExt.jl`: provides `enzyme_md_action` and the LCNN pullbacks.
- `ext/GaugefieldsHDF5Ext.jl`, `ext/GaugefieldsOptimisersExt.jl`: LCNN data loading and training.
- `ext/GaugefieldsMPIExt.jl`: MPI communicator backend.

## Main types and functions (v1 path)
| Name | Kind | Location | What it is |
|---|---|---|---|
| `AbstractGaugefields{NC,Dim}` | abstract type | `src/AbstractGaugefields.jl:62` | Root link-field type. `NC` is the number of colors (`colors=1` gives U(1)); `Dim` is the dimension. |
| `Gaugefields_4D_MPILattice{NC,NX,NY,NZ,NT,T,AT,NDW,DI,TU}` | struct | `src/4D/mpi_jacc/gaugefields_4D_MPILattice.jl:34` | v1 4D link field. Field `U::LatticeMatrix{4,T,AT,NC,NC}`; `NDW` is the halo. Constructor at line 48. |
| `Gaugefields_3D_MPILattice` / `Gaugefields_2D_MPILattice` | struct | `src/3D/mpi_jacc/gaugefields_3D_MPILattice.jl:31` / `src/2D/mpi_jacc/gaugefields_2D_MPILattice.jl:32` | v1 3D and 2D link fields. In 3D the extents are named `NX,NY,NT` (there is no `NZ`). |
| `TA_Gaugefields{NC,Dim}` | abstract type | `src/TA_Gaugefields.jl:4` | Traceless anti-Hermitian field (momenta and forces). |
| `TA_Gaugefields_4D_MPILattice` | struct | `src/4D/mpi_jacc/TA_gaugefields_4D_MPILattice.jl:4` | Stores `NC^2-1` real Lie coefficients per site (1 when `NC==1`; line 19). The momentum inner product `*` is at line 147. |
| `LatticeMatricesBackend` / `LegacyBackend` | struct | `src/API.jl:23` / `src/API.jl:32` | Backend selectors for `gauge_configuration`. |
| `gauge_configuration` | function | `src/API.jl:179` (also `:254`) | Creates `Vector` of `Dim` links. Accepts `Dim` in 2, 3, 4 only (line 55). Calls `Initialize_Gaugefields(...; isMPILattice=true)`. |
| `Initialize_Gaugefields` | function | `src/AbstractGaugefields.jl:460` | Shared constructor (legacy entry point that v1 also uses). Delegates per direction to `IdentityGauges` or `RandomGauges`. |
| `RandomGauges` / `IdentityGauges` | function | `src/AbstractGaugefields.jl:579` / `:786` | Dimension/backend switch (MPILattice branch at 605-663 and 812-850). |
| `randomGaugefields_4D_MPILattice` | function | `src/4D/mpi_jacc/gaugefields_4D_MPILattice.jl:480` | Hot start: `randomize_matrix!` then `normalize_matrix!` (LatticeMatrices), seeded by `RNGStreamKey`. Seed sharing in `_shared_mpialattice_seed` (`src/AbstractGaugefields.jl:164`). 2D: `src/2D/mpi_jacc/gaugefields_2D_MPILattice.jl:316`; 3D: `src/3D/mpi_jacc/gaugefields_3D_MPILattice.jl:308`. |
| `GaugeAction{Dim,T,Tdata}` | struct | `src/action/GaugeActions.jl:40` | Wilson-loop action. `dataset::Vector{GaugeAction_dataset}`. Constructor `GaugeAction(U)` at line 215. |
| `GaugeAction_dataset{Dim}` | struct | `src/action/GaugeActions.jl:20` | One term: `β::ComplexF64`, `closedloops::Vector{Wilsonline}`, and per-μ staples built by `make_staple` (line 48). |
| `push!(action, β, loops)` | method | `src/action/GaugeActions.jl:238` | Adds a term. |
| `evaluate_GaugeAction` | function | `src/action/GaugeActions.jl:132` | Returns Σ β tr(loops). B-field version at `src/Bfields/GaugeActions_Bfields.jl:70`. |
| `calc_dSdUμ!` | function | `src/action/GaugeActions.jl:95` | Raw action derivative: Σ β·staple_μ. B-field version at `src/Bfields/GaugeActions_Bfields.jl:42`. |
| `evaluate_gaugelinks!` | function | `src/AbstractGaugefields.jl:2070` (vector of loops); `src/4D/mpi_jacc/gaugefields_4D_MPILattice.jl:339` (one `Wilsonline`, 4D MPILattice) | Evaluates Wilson lines on the lattice. |
| `md_action_workspace` / `md_potential` / `md_force!` | generic functions | `src/molecular_dynamics.jl:13` / `:26` / `:39` | MD action-provider protocol. |
| `md_potential(::GaugeAction)` | method | `src/molecular_dynamics.jl:247` | `-Re S / NC`. |
| `md_force!(::Union{GaugeAction,BfieldGaugeAction})` | method | `src/molecular_dynamics.jl:279` | **Gauge force**: `TA(-1/NC · U_μ·dS/dU_μ)` via `Traceless_antihermitian_product_add!`. |
| `Traceless_antihermitian_product_add!` | method | `src/TA_Gaugefields.jl:147` | `@eval` methods generated by the loop at line 128 for the 2D/3D/4D MPILattice types. Forwards to LatticeMatrices `traceless_antihermitian_product_add!`. |
| `MDActionSet` / `MDForceGroup` | struct | `src/molecular_dynamics.jl:57` / `:77` | Named sum of actions, and selectors for time scales. |
| `BfieldGaugeAction` | struct | `src/molecular_dynamics.jl:262` | Action with a B field. Also reachable through `md_driver(U, action, B)` (line 756). |
| `NHYPSmearedGaugeAction` / `SmearedGaugeAction` | struct | `src/molecular_dynamics.jl:310` / `:420` | Action on smeared links. The force is pulled back to thin links (`md_force!` at 363 / 466). |
| `enzyme_md_action` | function stub | `src/molecular_dynamics.jl:521` | Implementation in `ext/GaugefieldsEnzymeExt.jl:1317` (`md_force!` at 1372). |
| `gauge_momenta` | function | `src/API.jl:332` | Calls `initialize_TA_Gaugefields` (`src/TA_Gaugefields.jl:186`; per-link dispatch at `:197`). |
| `gaussian_momenta!` / `gaussian_momenta` | function | `src/API.jl:342` / `:378` | Calls `gauss_distribution!` (`src/TA_Gaugefields.jl:267`). Per-field version at `src/4D/mpi_jacc/TA_gaugefields_4D_MPILattice.jl:157`. |
| `MDDriver` | struct | `src/molecular_dynamics.jl:656` | Field `momentum_denominator` (line 660). No momentum refresh and no accept/reject (docstring 647-655). |
| `md_driver` | function | `src/molecular_dynamics.jl:690` | Builds the driver. Default `integrator=QPQ()`, `momentum_denominator=1` (2 is the Grid/Bridge++ convention; docstring 684-688). |
| `md_hamiltonian` | function | `src/molecular_dynamics.jl:769` | Kinetic term `p*p/(2*momentum_denominator)` at line 778. |
| `update_momenta!` / `update_gaugefields!` | function | `src/molecular_dynamics.jl:815` (group version `:837`) / `:788` | P kick scaled by `momentum_denominator` (line 823); U update `U ← exp(εP)U`. |
| `PQP` / `QPQ` / `SextonWeingarten` | struct | `src/molecular_dynamics.jl:529` / `:538` / `:553` | Integrators. `md_step!` methods at 882 / 889 / 963. |
| `md_step!` | generic + methods | `src/molecular_dynamics.jl:872` (fallback); `:878` (user `Function`) | User-defined integrators hook in here. |
| `md_trajectory!` | function | `src/molecular_dynamics.jl:990` | One MD trajectory. Uses `_md_trajectory_steps!` (1013; fused PQP at 1022, SW-PQP at 1032). |
| `exptU!` (TA → link) | method | `src/4D/mpi_jacc/TA_gaugefields_4D_MPILattice.jl:196` | **Exponential**. For `NC≤3` calls `LatticeMatrices.expt!` on the coefficients. For `NC>3` builds the matrix with `_sun_lie2matrix!` (`src/TA_Gaugefields.jl:51`) first. 2D/3D versions: `src/2D/mpi_jacc/TA_gaugefields_2D_MPILattice.jl:191`, `src/3D/mpi_jacc/TA_gaugefields_3D_MPILattice.jl:180`. |
| `exptU!` (matrix → link) | method | `src/4D/mpi_jacc/gaugefields_4D_MPILattice.jl:848` (also `:838` for `Traceless_AntiHermitian`) | Exponential of a matrix field. |
| `Traceless_antihermitian_add!` | method | `src/4D/mpi_jacc/TA_gaugefields_4D_MPILattice.jl:263` | Projects a matrix onto the Lie algebra. For `NC>3` uses `_sun_traceless_antihermitian_add!` (`src/TA_Gaugefields.jl:108`). |
| `normalize_U!` | method | `src/4D/mpi_jacc/gaugefields_4D_MPILattice.jl:900` | **Projection to SU(N)** via `LatticeMatrices.normalize_matrix!`. Exists for 4D MPILattice only. |
| `heatbath_updater` | function | `src/API.jl:441` (3 methods, 441-445) | Returns `Heatbath(U, β)` or `Heatbath_update(U, action)`. |
| `Heatbath` / `Heatbath_update` | mutable struct | `src/heatbath/heatbathmodule.jl:55` / `:157` | Plaquette-only updater / general-action updater. Colorings via `heatbath_colorings` (`:347`). |
| `heatbath!` (v1) | method | `src/heatbath/heatbathmodule.jl:2165` (Heatbath, general NC); `:604` (temporaries form); `:505`/`:539`/`:571` (Heatbath_update with NC=2 / 3 / N) | Many methods (about 25 in the file); SU(2) and SU(3) specializations at 2278 and 2296. |
| `overrelaxation!` (v1) | method | `src/heatbath/heatbathmodule.jl:2333` (Heatbath, NC); `:758` (Heatbath_update, NC) | Also at 2314, 2351, 651, 681, 711. |
| `SUNupdate_matrix_rng!` | function | `src/heatbath/heatbathmodule.jl:1179` | Cabibbo–Marinari sweep over random SU(2) subgroups; site kernel `kernel_heatbath_sun_sites!` at 1848. |
| `_su2_update_kp_core!` | function | `src/heatbath/portable/kernels.jl:63` | Kennedy–Pendleton SU(2) step; `k = 2(β/NC)ρ` at line 87. |
| `gradient_flow` | function | `src/API.jl:421` / `:428` | Returns `Gradientflow` (Wilson flow) or `Gradientflow_general` (loops and coefficients). |
| `Gradientflow` / `Gradientflow_general` | struct | `src/smearing/gradientflow.jl:118` / `:33` | Flow integrators. |
| `flow!` | function | `src/smearing/gradientflow.jl:171` / `:240` | 3-stage RK. Force from `add_force!(…; plaqonly=true)` (`src/AbstractGaugefields.jl:2746`) or `F_update!` (`gradientflow.jl:320`). |
| `NativeLinkSmearing` | abstract type | `src/smearing/nhyp.jl:6` | Supertype of the v1 smearings. |
| `NHYPSmearing` / `StoutSmearing` (alias `EXPSmearing`) / `HEXSmearing` / `APESmearing` / `HYPSmearing` | struct | `src/smearing/nhyp.jl:23` / `:59` (`:76`) / `:79` / `:110` / `:143` | Each has fields `parameters` (a LatticeMatrices parameter type) and `iterations`. |
| `LinkSmearingCache` (= `NHYPSmearingCache`) | struct | `src/smearing/nhyp.jl:216` (alias at `:220`) | Workspace from `LatticeMatrices.smearing_cache`. |
| `link_smear!` / `link_smear` / `link_smear_pullback!` / `has_smearing_pullback` | functions | `src/smearing/nhyp.jl:367` / `:408` / `:444` / `:188` | Common native interface; forwards to `LatticeMatrices.smear_links!` and `smear_links_pullback!`. |
| `smear` | function | `src/API.jl:475` (generic `CovNeuralnet` path), `:485` (native) | A third method is in `src/lcnn/smearing.jl:110`. |
| `stout_smearing` / `CovNeuralnet` / `STOUT_Layer` | function / struct / struct | `src/API.jl:455` / `src/smearing/Abstractsmearing.jl:62` / `src/smearing/stout_fast.jl:15` | Older layer-based stout. `calc_smearedU` at `src/smearing/Abstractsmearing.jl:239`. |
| `gaugefixing!` | function | `src/gaugefixing/gaugefixing_common.jl:122` | Los Alamos + steepest descent. |
| Gauge-fixing v1 backend | methods | `src/gaugefixing/gaugefixing_utility_4D_MPILattice.jl:4` | `gaugefixing_backend_supported` for the 4D MPILattice type; `make_g_los_alamos!` at 7, `make_g_steepest_descent!` at 60. |
| `save_configuration` | function | `src/API.jl:741` | Dispatches on `format` = `:jld2`, `:nersc`, `:bridge`, `:ildg`. |
| `load_configuration` / `load_configuration!` | function | `src/API.jl:766` / `:822` | The allocating version supports `:jld2` and `:nersc` only. |
| JLD2 (portable) | functions | `src/API.jl:590` (`_write_portable_jld2`), `:608` (metadata), `:690` (`_load_portable_jld2_lm!`) | Fallback for old object-serialized files: `loadU`/`loadU!` (`src/output/io.jl:53` / `:31`). |
| NERSC | functions | `src/output/nersc.jl:174` (`_save_nersc`), `:121` (`_load_nersc!`), `:139` (`_write_nersc`), `:101` (`_read_nersc`) | NERSC read/write. |
| Bridge++ text | functions | `src/output/bridge_format.jl:143` (`save_textdata`, MPILattice), `:181` (`load_BridgeText!`, MPILattice) | Generic legacy versions at 201 and 249. |
| ILDG | functions | `src/output/ildg_format.jl:888` (`save_binarydata`), `:621` (`_save_binarydata`, MPILattice), `:1024` (`load_binarydata!(U, file)`), `:551` (`load_binarydata!`, MPILattice) | ILDG/LIME. |
| `measure_plaquette` | function | `src/API.jl:396` | Uses `calculate_Plaquette` (`src/AbstractGaugefields.jl:2713`) and `construct_staple!` (`:2901`). Normalized by `binomial(Dim,2)·V·NC`. |
| `measure_polyakov_loop` | function | `src/API.jl:413` | Uses `calculate_Polyakov_loop` (`src/AbstractGaugefields.jl:2957`) along the last direction, with `mul_skiplastindex!` and `partial_tr` (`src/4D/mpi_jacc/gaugefields_4D_MPILattice.jl:524` / `:541`). |
| `Bfield` / `Initialize_Bfields` / `B_TfluxGauges` | struct / function / function | `src/Bfields/Bfields.jl:53` / `:169` / `:501` | Z(N) 2-form and 't Hooft flux. Legacy flux builder: `thooftFlux_4D_B_at_bndry` (`src/4D/nowing/gaugefields_4D_nowing_Bfields.jl:44`). |
| `GaugeAction(U, B)` / `multiply_Bplaquettes!` | method / function | `src/Bfields/GaugeActions_Bfields.jl:6` / `src/Bfields/Bfields.jl:901` | B-aware action. |
| `Generator` | struct | `src/SUN_generator.jl:4` | SU(N) generator set, used by `lambda_k_mul!` (`src/4D/mpi_jacc/gaugefields_4D_MPILattice.jl:867`). |

## Where to make changes
- **New gauge action (Wilson-loop type):** usually no source change is needed.
  - Build `Wilsonline` loops (Wilsonloop.jl `make_loops_fromname`, or hand-built loops plus their adjoints) and `push!` them into `GaugeAction` (`src/action/GaugeActions.jl:238`).
  - The same object then works with `md_driver` (force at `src/molecular_dynamics.jl:279`), `heatbath_updater(U, action)` (`src/heatbath/heatbathmodule.jl:157`; staples come from `calc_dSdUμ!` at `GaugeActions.jl:95`), and `gradient_flow(U, loops, coeffs)` (`src/smearing/gradientflow.jl:59`).
  - A non-Wilson-loop action needs a new provider type implementing `md_action_workspace`, `md_potential` and `md_force!` (`src/molecular_dynamics.jl:13/26/39`), modeled on `SmearedGaugeAction` (`:420`), or `enzyme_md_action`. Combine providers with `MDActionSet` (`:57`).
  - Heat bath only supports actions that are linear in each link (staple form).
- **New smearing (v1 native):** add a struct `<: NativeLinkSmearing` in `src/smearing/nhyp.jl`.
  - It needs `parameters` and `iterations` fields; `_lm_smearing_specification` (`:179`) reads them.
  - Add a `has_smearing_pullback` method (`:188`) and a convenience constructor like `ape_smearing` (`:321`). Export it at `src/API.jl:871`.
  - The numerical work (`smearing_cache`, `smear_links!`, `smear_links_pullback!`) lives in LatticeMatrices.jl, so the kernel and pullback must be added there.
  - `smear` (`src/API.jl:485`), `LinkSmearingCache` and `SmearedGaugeAction` then work unchanged.
  - Alternative (older framework): subtype `CovLayer` and implement `apply_layer!`, `layer_pullback!` and `parameter_derivatives` (`src/smearing/Abstractsmearing.jl:507/518/532`), as `STOUT_Layer` does in `src/smearing/stout_fast.jl`.
- **New integrator:** define a struct (optionally `<: AbstractMDIntegrator`, `src/molecular_dynamics.jl:4`).
  - Add `md_step!(::MyInt, U, P, ε, driver::MDDriver)` composed of `update_momenta!` and `update_gaugefields!` (`:815/:788`); group kicks use the `:837` method.
  - A plain function also works (`:878`).
  - Optional: `_validate_md_integrator` (`:607`) and a fused `_md_trajectory_steps!` (`:1013`).
  - No driver changes are needed.
- **New gauge group (SO(N), Sp(2N), …):** real element types (`Float32`/`Float64`) are already accepted for the links (`_resolve_mpialattice_elementtype`, `src/AbstractGaugefields.jl:155`), which is where real groups would enter. SU(N) is assumed in these places:
  - Lie basis size `NC^2-1` (`src/4D/mpi_jacc/TA_gaugefields_4D_MPILattice.jl:19`, and the same at 2D line 21 and 3D line 20). The momentum inner product (`:147`) and the Gaussian momenta `gauss_distribution!` (`:157`) depend on it.
  - The basis and projection kernels `_kernel_sun_lie2matrix!` and `_kernel_sun_traceless_antihermitian_add!` (`src/TA_Gaugefields.jl:7`, `:66`). For `NC≤3` LatticeMatrices does this (`traceless_antihermitian_add!`, `traceless_antihermitian_product_add!`, `expt!`).
  - The exponential `exptU!` (`TA_gaugefields_4D_MPILattice.jl:196`). It branches on `NC > 3`, not on the group (:203), and the basis size is fixed by `NC`: a real NC = 3 field (SO(3)) would take the SU(3) path with 8 coefficients. This is read from the code, not tested.
  - Projection `normalize_U!` (`gaugefields_4D_MPILattice.jl:900`), which calls LatticeMatrices `normalize_matrix!` (`LatticeMatrices.md`). Its docstring says it projects onto SO(N) for real element types; untested here.
  - The random element: `randomize_matrix!` followed by `normalize_matrix!` (`:480`).
  - Heat bath and overrelaxation over SU(2) subgroups: `SUNupdate_matrix_rng!` (`heatbathmodule.jl:1179`), `_overrelaxation_subgroup!` (`:1248`), Gram–Schmidt only (no determinant fix) in `_normalize_columns_allocationfree!` (`:1221`), `project_onto_SU2!` and `k=2β/NC` (`portable/kernels.jl:14`, `:87`).
  - Gauge-fixing SU(2) hits: `get_SU2_index` (`gaugefixing_common.jl:54`), `_su2_subgroup_hit!` (`gaugefixing_local_matrix.jl:11`).
  - Normalization by N: `md_potential`/`md_force!` (`molecular_dynamics.jl:248, 283`), `measure_plaquette` (`API.jl:403`), `measure_polyakov_loop` (`API.jl:417`), and the normalizations of QCDMeasurements (`QCDMeasurements.md`).
  - The coefficient `GaugeAction_dataset.β` is always `ComplexF64` (`src/action/GaugeActions.jl:22`).
  - Generators: `src/SUN_generator.jl:73`.
  - NERSC writes SU(3) only (`nersc.jl:24, 174`).
- **Different dimension (only 2/3/4 exist):**
  - Lift the check in `_validate_lattice_size` (`src/API.jl:55`).
  - Add new concrete link and TA types modeled on `src/4D/mpi_jacc/*`, and include them from a new `src/ND/` folder (called from `src/AbstractGaugefields.jl:181-186` and `src/TA_Gaugefields.jl:124-126`).
  - Add branches in `RandomGauges`/`IdentityGauges` (`src/AbstractGaugefields.jl:605-663`, `812-850`) and in `initialize_TA_Gaugefields` (`src/TA_Gaugefields.jl:197`).
  - Extend the type lists at `src/TA_Gaugefields.jl:128` and `:274`, the unions at `src/API.jl:42/48`, and the `Union{…_2D…,_3D…,_4D…}` signatures throughout `src/heatbath/heatbathmodule.jl`.
  - Plaquette heat bath reads `loops_staple[(Dim,μ)]` from Wilsonloop.jl (`heatbathmodule.jl:622`).
  - Features that are 4D-only today: native smearing (`nhyp.jl:222`), ILDG/Bridge/NERSC, gauge fixing, topological charge, and B-flux on LatticeMatrices (`Bfields.jl:519`).
- **New configuration file format:** use NERSC (`src/output/nersc.jl`) as the template.
  - The reader produces host arrays `(NC,NC,L...)` per direction plus a metadata named tuple (`dimension, lattice, colors, halo, boundary, element_type`).
  - Then reuse `_validate_portable_jld2_target`, `_load_portable_jld2_lm!`, `_load_portable_jld2_legacy!`, `_portable_jld2_links` and `_portable_jld2_root_operation` (`src/API.jl:676/690/719/558/572`) for rank-0 I/O and distribution.
  - Add branches in `save_configuration` (`:741`), `load_configuration` (format check `:777`, metadata `:783`) and `load_configuration!` (`:822`), and include the file in `src/Gaugefields.jl:388`.
  - NERSC already exists, so it does not need to be added.
- **New observable:** follow `measure_plaquette`/`measure_polyakov_loop` in `src/API.jl:396/413`.
  - Evaluate `Wilsonline` sets with `evaluate_gaugelinks!` or `GaugeAction` plus `evaluate_GaugeAction`, take `tr`, normalize, and export at `src/API.jl:871`.
  - The docstring at `src/AbstractGaugefields.jl:1471-1474` points new measurement workflows to the separate QCDMeasurements.jl package.

## Notes
- **Misleading names.** "MPILattice" types are the v1 LatticeMatrices types and are used even in serial runs. `src/MPILattice/MPILattice.jl` is only an import/re-export shim.
- **`Initialize_Gaugefields` serves both paths.** It is the legacy entry point, but `gauge_configuration` also calls it with `isMPILattice=true` (`src/API.jl:206`).
- **`nhyp.jl` holds every native smearing**, not just nHYP. `NHYPSmearingCache` is the generic cache, also called `LinkSmearingCache` (`src/smearing/nhyp.jl:216-220`).
- **`stout_smearing` and `StoutSmearing` are different.** `stout_smearing` (`src/API.jl:455`) builds the older `CovNeuralnet`; `StoutSmearing` (`nhyp.jl:59`) is the native one.
- **Functions defined in several places:**
  - `smear`: `src/API.jl:475`, `:485`, `src/lcnn/smearing.jl:110`.
  - `link_smear_pullback!`: `nhyp.jl:444`, `src/lcnn/smearing.jl:67`.
  - `GaugeAction` constructor and `calc_dSdUμ!`: also in `src/Bfields/GaugeActions_Bfields.jl:6`, `:42`.
  - `calculate_Plaquette`: `src/AbstractGaugefields.jl:2702-2713`, `src/Bfields/Bfields.jl:1242-1257`.
  - `STOUT_Layer`: active in `stout_fast.jl:46-66` and `CASK/stoutsmearing.jl:1`; the copies in `stout.jl:97/110` are commented out.
  - `shift_U`: also extended in `src/smearing/CASK/additionalfunctions.jl:347`.
- **Normalization conventions differ.**
  - MD uses `-1/NC` (`molecular_dynamics.jl:248, 283`).
  - Gradient flow's `F_update!` uses factor 1 (`gradientflow.jl:320-330`).
  - General-action heat bath passes the constant `heatbath_factor = 2` as β (`heatbathmodule.jl:374`, used at 521). β therefore lives in the action coefficients, and the kernel divides by NC (`portable/kernels.jl:87`).
- **`GaugeAction_dataset.β` is always stored as `ComplexF64`** (`GaugeActions.jl:22`), whatever the field element type.
- **`GaugeAction(U; hascovnet=true)` is effectively broken.** It calls `CovNeuralnet(Dim=Dim)` (`GaugeActions.jl:220`), which emits an "is not supported now" `@error` (`Abstractsmearing.jl:75-76`).
- **Hidden SU(3) assumption:** the 4-argument `_make_embedded_su2_matrix!` hardcodes NC=3 (`src/heatbath/portable/kernels.jl:58`).
- **Unitarization without a determinant fix.** The SU(N) heat bath and overrelaxation finish with Gram–Schmidt only (`heatbathmodule.jl:1221`).
- **Dimension-specific code in v1:**
  - `normalize_U!` exists only for 4D MPILattice (`gaugefields_4D_MPILattice.jl:900`).
  - ILDG and Bridge loop over `NX..NT` and `μ=1:4` (`ildg_format.jl:813-829`, `bridge_format.jl:221-239`).
  - Default process grid `(1,1,1,nprocs)` (`gaugefields_4D_MPILattice.jl:68`); `gauge_configuration` always passes an explicit grid.
- **Host staging through legacy types.** MPILattice topological charge (`src/AbstractGaugefields.jl:1440`), Bridge load (`bridge_format.jl:181`) and B-flux (`Bfields.jl:519-540`) copy to or from the legacy `Gaugefields_4D_nowing` or `Initialize_Gaugefields(...,0,...)` on the host. They are serial or single-rank only.
- **ILDG and Bridge MPILattice methods are inside `@require JACC` blocks** (`ildg_format.jl:541-742`, `bridge_format.jl:134`), even though JACC is a hard dependency.
- **Legacy `add_force!` has a broken branch.** In the non-`plaqonly` case it references an undefined `gparam` (`src/AbstractGaugefields.jl:2774`). Only `plaqonly=true` is used (by `Gradientflow`).
- **A legacy `heatbath!` method references a missing field.** `heatbath!(U, h::Heatbath_update)` at `heatbathmodule.jl:1116` reads `h._tempotal_gauges`, which `Heatbath_update` does not have (its field is `_temporary_gaugefields`). The more specific method at `:481` shadows it in practice.
- **Gradient flow scheme.** The comment at `gradientflow.jl:192` says "RK4 integrator -> RK3?"; the code is a 3-stage RK with coefficients 1/4, 8/9 and 17/36, 3/4.
- **What `gaugefixing!` returns.** Its `g_transform` holds the last checkerboard transformation, not the accumulated one (docstring at `gaugefixing_common.jl:119-120`).
- **What `md_trajectory!` does not do.** It performs no momentum refresh and no Metropolis step (`molecular_dynamics.jl:647-655`, `:983-984`). Accept/reject is the caller's job.
- **Wilson-loop objects come from an external package.** `Wilsonline`, `make_loops_fromname`, `make_staple`, `loops_staple` and `loops_staple_prime` are imported from Wilsonloop.jl (`src/action/GaugeActions.jl:12`, `src/Gaugefields.jl:213, 284`). `src/autostaples/*` is the older in-package version.
- **Field-name typo:** `Heatbath._tempotal_gauges` (`heatbathmodule.jl:57`).
- **Kernels in LatticeMatrices:** `expt!`, `normalize_matrix!`, `smear_links!`, and `traceless_antihermitian_product_add!` are defined in LatticeMatrices, not here; see `LatticeMatrices.md`.
