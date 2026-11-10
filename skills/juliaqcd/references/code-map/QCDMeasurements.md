# QCDMeasurements.jl 1.0.2: code map

Part of `../code-map.md`; read its first part (versions, how to cite a line) before this one. Paths are relative to the package root; `file:N` is line N in version 1.0.2.

## File map
- `src/QCDMeasurements.jl`: module root. Brings in Wilsonloop, Gaugefields, LatticeDiracOperators, Arpack, JACC and LatticeMatrices; defines the v1 CamelCase aliases (lines 30-64) and the exports.
- `src/support.jl`: `supported_fermions` traits, which list the fermion types each measurement is validated for.
- `src/parameters/parameters.jl`: parameter structs for fermions and measurements, the string-to-type Dicts, `prepare_measurement*` (building a measurement from a Dict), and the shared fermion helpers.
- `src/measurements/AbstractMeasurement.jl`: abstract type, `MeasurementOutput`, `get_value` and `get_string`, the fallback `measure`, the default boundary conditions, and the `include`s for every measurement file.
- `src/measurements/measure_plaquette.jl`: plaquette.
- `src/measurements/measure_polyakov.jl`: Polyakov loop.
- `src/measurements/measure_Wilon_loop.jl`: rectangular T×R Wilson loops (the "Wilon" typo is in the file name).
- `src/measurements/measure_energy_density.jl`: legacy clover energy density, plus the `calc_large_wilson_loop!` helper.
- `src/measurements/measure_correlation.jl`: two-point correlation of two loop traces. Lines 184-251 are commented-out dead code.
- `src/measurements/measure_Guluonic_correlators.jl`: gluonic correlator of two loops at given sites.
- `src/measurements/measure_topological_charge.jl`: global Q (plaquette, clover, and two improved definitions), the loop sets and the epsilon tensor.
- `src/measurements/measure_topological_charge_density_correlation.jl`: q(x)q(y) evaluated at single sites.
- `src/measurements/measure_gauge_density.jl`: topological-charge and action densities as fields, run through JACC kernels on CPU or GPU.
- `src/measurements/measure_gradient_flow_scale.jl`: Wilson-flow history, and ensemble t0/w0 with jackknife errors.
- `src/measurements/measure_Pion_correlator.jl`: point-source quark propagators, the pion correlator and solver diagnostics.
- `src/measurements/measure_Meson_correlator.jl`: general local Wilson and staggered meson channels with momenta.
- `src/measurements/measure_PCAC_mass.jl`: PCAC mass built on the meson measurement.
- `src/measurements/measure_Domainwall_residual_mass.jl`: Shamir domain-wall residual mass.
- `src/measurements/measure_chiral_condensate.jl`: stochastic (Z4-noise) chiral condensate.
- `src/measurements/measure_eigenvalues.jl`: Dirac eigenvalues from a sparse matrix, using Arpack or a dense solve.
- `src/measurements/measure_MdagMspectrum.jl`: local spectral density of D†D, computed with RSCG.
- Outside `src/`: `ext/QCDMeasurementsMPIExt.jl:6` implements `_density_legacy_mpi_result`, the MPI extension used by the gauge densities.

## Main types and functions
| Name | Kind | Location | What it is |
|---|---|---|---|
| `AbstractMeasurement` | abstract type | src/measurements/AbstractMeasurement.jl:2 | Supertype of every measurement |
| `MeasurementOutput{T}` | struct | src/measurements/AbstractMeasurement.jl:14 | `(value, outputstring)` returned by every `measure`. The alias `Measurement_output` is at line 21 |
| `get_value` / `get_string` | function | src/measurements/AbstractMeasurement.jl:23 / :27 | Accessors for the typed value and the printed text |
| `measure` (fallback) | function | src/measurements/AbstractMeasurement.jl:31 | `measure(m, itrj, U)` throws MethodError. The real methods are `measure(m, U; additional_string="")` |
| `get_temporary_fermionfields` | function | src/measurements/AbstractMeasurement.jl:4 | Returns `m._temporary_fermionfields` |
| `BoundaryCondition_4D_default` / `_2D_default` | const | src/measurements/AbstractMeasurement.jl:35 / :36 | `[1,1,1,-1]` and `[1,-1]` |
| `supported_fermions` | function (9 methods) | src/support.jl:10 | Validated fermion types. Specialisations are at lines 14-25 |
| `Fermion_parameters` + `Quench/Wilson/Staggered/Domainwall_parameters` | abstract + @kwdef structs | src/parameters/parameters.jl:4, 6, 10, 18, 24 | Fermion settings. Wilson uses `hop`, `r`, `hasclover`, `Clover_coefficient` |
| `FERMION_PARAMETER_TYPES` | const Dict | src/parameters/parameters.jl:31 | Maps `"nothing"`, `"Wilson"`, `"WilsonClover"`, `"Staggered"`, `"Domainwall"` to a parameter type |
| `initialize_fermion_parameters` | function | src/parameters/parameters.jl:39 | Looks up the fermion type by name. For WilsonClover it sets `hasclover=true` |
| `Measurement_parameters` | abstract type | src/parameters/parameters.jl:56 | Supertype of the measurement parameter structs (Plaq 58, Poly 67, Wilson_loop 77, Pion 88, MesonCorrelator 110, PCACMass 126, DomainWallResidualMass 141, ChiralCondensate 157, Energy_density 182, GradientFlowScale 191, Correlation 209, Guluonic_correlators 223, TopologicalCharge 234, TopologicalChargeDensityCorrelation 248, Eigenvalue 259, MdagMspectrum 281). Every one has `methodname`, `fermiontype`, `verbose_level`, `printvalues` and `measure_every` |
| `MEASUREMENT_PARAMETER_TYPES` | const Dict | src/parameters/parameters.jl:305 | String dispatch from methodname to parameter type. Both `"Guluonic_correlators"` and `"Gluonic_correlators"` are accepted |
| `initialize_measurement_parameters` | function | src/parameters/parameters.jl:326 | Looks up `methodname`, otherwise throws ArgumentError |
| `construct_Measurement_parameters_from_dict` | function | src/parameters/parameters.jl:375 | Fills the measurement struct, then the fermion struct, from Dict keys. Renames `L5`→`N5`, `mass`→`m` (DWF) and `cSW`→`Clover_coefficient` (lines 401-407). Unknown keys throw (line 421). Values pass through `_convert_parameter_value` (line 344) |
| `prepare_measurement` / `prepare_measurement_from_dict` | function (18 methods) | src/parameters/parameters.jl:370 / :366 | Dict → params → measurement. There is one typed method per params type at lines 436-484 (these choose the default filenames), and a fallback that throws at line 486 |
| `make_fermionparameter_dict` | function | src/parameters/parameters.jl:493 | Builds the LatticeDiracOperators `params` Dict and the pseudofermion `x`, keyed on the fermiontype string |
| `fermionparameter_params` | function | src/parameters/parameters.jl:547 | Turns params into a NamedTuple of constructor kwargs (`κ`, `r`, `cSW`, `mass`, `Nf`, `eps_CG`, ...) |
| `Plaquette_measurement` / `measure` | struct / method | src/measurements/measure_plaquette.jl:31 / :110 | Re tr P normalised by `factor` (line 69). Params constructor at line 92 |
| `Polyakov_measurement` / `measure` | struct / method | src/measurements/measure_polyakov.jl:1 / :61 | Complex Polyakov loop, computed by Gaugefields' `calculate_Polyakov_loop`. Params constructor at line 45 |
| `Wilson_loop_measurement` / `measure` | struct / method | src/measurements/measure_Wilon_loop.jl:1 / :91 | Tmax×Rmax matrix of W(T,R). Loops come from `make_Wilson_loop` (line 170) |
| `Energy_density_measurement` / `measure` | struct / method | src/measurements/measure_energy_density.jl:1 / :66 | Legacy clover E. Computed in `calculate_energy_density` (line 96) |
| `Correlation_measurement` / `measure` | struct / method | src/measurements/measure_correlation.jl:3 / :95 | tr(loop1)·tr(loop2). Either at a single site (`originonly`) or as a full-volume sum |
| `Guluonic_correlators_measurement` / `measure` | struct / method | src/measurements/measure_Guluonic_correlators.jl:1 / :71 | Takes `measure(m, U, loop1position, relativeposition)`. This is a different call signature from the others |
| `Topological_charge_measurement` / `measure` | struct / method | src/measurements/measure_topological_charge.jl:37 / :125 | Returns a Dict with keys `"plaquette"`, `"clover"`, `"clover improved"` and `"clover improved bilson-thompson"`. Defaults: the keyword constructor takes `TC_methods=["plaquette"]` (:53), the parameter struct `kinds_of_topological_charge = ["plaquette", "clover"]` (src/parameters/parameters.jl:244); the improved definition is `"alexandrou"` in both |
| `calculate_topological_charge_plaq/_clover/_improved/_bilson_thompson` | functions | src/measurements/measure_topological_charge.jl:198, 205, 212, 225 | Alexandrou: 5/3 Q_clov − 1/12·(2 Q_rect). BT: F_imp = 5/3 F_1×1 − 1/6 A_rect, with a cross term (line 255) |
| `calc_UμνTA!` | function (2 methods; 2 more in the density-correlation file) | src/measurements/measure_topological_charge.jl:291, 303 | Traceless anti-Hermitian part of the loop sums |
| `calc_Q` | function | src/measurements/measure_topological_charge.jl:336 | Q = −Σ ε tr(F F)/(32π² nloops²) |
| `epsilon_tensor` | function | src/measurements/measure_topological_charge.jl:372 | Hard-coded 4D Levi-Civita symbol |
| `calc_loopset_μν_name` | function | src/measurements/measure_topological_charge.jl:420 | Builds the `"plaq"` (1 loop), `"clover"` (4) and `"rect"` (8) loop sets |
| `make_cloverloops_topo` | function | src/measurements/measure_topological_charge.jl:481 | The four clover leaves |
| `Topological_charge_density_correlation_measurement` / `measure` | struct / method | src/measurements/measure_topological_charge_density_correlation.jl:1 / :87 | q(x)·q(x+r) at single sites. Takes `measure(m, U, loop1position, relativeposition)`. Per-site helpers are at lines 180-386 |
| `GaugeDensityWorkspace` | struct + constructor | src/measurements/measure_gauge_density.jl:27 / :37 | Reusable scratch space for the density functions |
| `topological_charge_density(!)` | function | src/measurements/measure_gauge_density.jl:230 / :243 | q(x) as an `Array{Float64,4}`. Methods: plaquette, clover, alexandrou, bilson_thompson. The empty stub is declared at src/QCDMeasurements.jl:5 |
| `action_density(!)` | function | src/measurements/measure_gauge_density.jl:296 / :308 | e(x) for the clover or plaquette definition |
| `GradientFlowScale_measurement` / `measure` | struct / method | src/measurements/measure_gradient_flow_scale.jl:81 / :243 | Flows a private copy of U and returns a `GradientFlowHistory` (line 10) |
| `estimate_flow_scales` | function | src/measurements/measure_gradient_flow_scale.jl:394 | Ensemble t0 and w0 with jackknife errors, returned as `GradientFlowScaleEstimate` (line 55) |
| `Pion_correlator_measurement` / `measure` | struct / method | src/measurements/measure_Pion_correlator.jl:17 / :402 | The inner constructor at line 32 builds `D`. The params constructor at line 207 handles stout smearing |
| `calc_quark_propagators_point_source_each` | function | src/measurements/measure_Pion_correlator.jl:538 | One point-source solve with `solve_DinvX!` (line 595), plus a `PionSolverDiagnostic` (line 2) |
| `Meson_correlator_measurement` / `measure` | struct / method | src/measurements/measure_Meson_correlator.jl:157 / :462 | Holds two `Pion_correlator_measurement`s as its quark solvers (lines 291, 296). kwargs constructor at line 240, params constructor at line 327 |
| `LocalMesonChannel` / `StaggeredMesonChannel` / `local_meson_channel` / `simulateqcd_staggered_channels` | struct / struct / function / function | src/measurements/measure_Meson_correlator.jl:14 / 40 / 74 / 126 | Channel definitions. Strings are parsed at line 197 |
| `PCAC_mass_measurement` / `measure` | struct / method | src/measurements/measure_PCAC_mass.jl:41 / :174 | PP and A_aP correlators from the meson measurement, returned as `PCACMassResult` (line 18) |
| `Domainwall_residual_mass_measurement` / `measure` | struct / method | src/measurements/measure_Domainwall_residual_mass.jl:33 / :159 | J5qP/PP ratio, returned as `DomainWallResidualMassResult` (line 14) |
| `Chiral_condensate_measurement` / `measure` | struct / method | src/measurements/measure_chiral_condensate.jl:2 / :231 | Z4 noise with Nr samples, and an optional higher `order`. Params constructor at line 162 |
| `Eigenvalue_measurement` / `measure` | struct / method (2) | src/measurements/measure_eigenvalues.jl:1 / :129 (also :140, which takes a Dirac operator) | `eigs` from Arpack or a dense `eigen` (`solver = "exact"`) |
| `MdagMspectrum_measurement` / `measure` | struct / method | src/measurements/measure_MdagMspectrum.jl:2 / :153 | ρ_ij(E) from RSCG `greensfunctions` |

How parameters flow, and how printing and return values work:
- **Construction.** Each measurement has a keyword constructor (the inner constructor) and an outer `X(U, params::X_parameters, filename)` constructor. The outer one copies fields into the kwargs; the fermionic ones go through `fermionparameter_params`.
- **Printing.** When `printvalues=true`, the constructor creates `Verbose_print(verbose_level, myid, filename)`. `measure` then writes through `println_verbose_level2(m.verbose_print, ...)`. These helpers and `get_myrank` come from Gaugefields; they are not defined in this package.
- **Return value.** Every `measure` returns `MeasurementOutput(value, measurestring)`. `measurestring` is `""` unless printing is on.
- **Exceptions.** Meson, PCAC and DWF have no `verbose_print`. For them `printvalues` only adds lines to the returned string and nothing is written to a file (Meson line 534, PCAC line 208, DWF line 191).
- **`measure_every` is never read in `src/measurements`.** The driver has to apply it.

## Where to make changes
- **Normalizations that assume SU(N) (for a new gauge group):** the plaquette `factor` (src/measurements/measure_plaquette.jl:69), the legacy energy density `/NV/6/NC/8` (src/measurements/measure_energy_density.jl:106), the flow energy `2·NC·Nplanes·(1−plaq)` (src/measurements/measure_gradient_flow_scale.jl:226), and the traceless anti-Hermitian F and `calc_Q` of the topological charge (src/measurements/measure_topological_charge.jl:291, :336).
- **A new gauge observable:**
  1. Add a `src/measurements/measure_X.jl` file with a struct `<: AbstractMeasurement`. Copy the pattern of `measure_plaquette.jl`: a keyword inner constructor (lines 39-88), a params constructor (lines 92-103), and `measure(m, U; additional_string="")` returning `Measurement_output` (line 110).
  2. `include` it in `src/measurements/AbstractMeasurement.jl` (the list at lines 39-55).
  3. Add an `X_parameters <: Measurement_parameters` struct in `src/parameters/parameters.jl` (near lines 58-302).
  4. Add a `MEASUREMENT_PARAMETER_TYPES` entry (line 305) and a typed `prepare_measurement` method (lines 436-484), so that Dict/TOML input works.
  5. Add the v1 aliases and exports in `src/QCDMeasurements.jl` (lines 30-64 and 66-133).
  6. `supported_fermions` defaults to `()` (support.jl:10), so a gauge observable needs no entry there.
  7. Reusable loop machinery: `calc_loopset_μν_name` (topological_charge.jl:420), `calc_UμνTA!` (:291), `calc_large_wilson_loop!` (energy_density.jl:140), and `evaluate_gaugelinks!` from Gaugefields.
- **A new fermionic observable:**
  1. Follow `Pion_correlator_measurement` (Pion_correlator.jl:32-200). `make_fermionparameter_dict` (parameters.jl:493) returns the LatticeDiracOperators `params` Dict and the pseudofermion `x`. You then add `eps_CG`, `MaxCGstep` and `boundarycondition` (Pion lines 127-130), and call `D = Dirac_operator(U, x, params)` and `FermiAction(D, parameters_action)` (lines 153-154).
  2. Inside `measure`, rebind the current links with `D = m.D(U)` (Pion line 484, Chiral line 241), then solve with `solve_DinvX!` (Pion line 595, Chiral line 262).
  3. A new fermion type needs a branch in `make_fermionparameter_dict` and `fermionparameter_params` (parameters.jl:507-543 and 551-585), plus `FERMION_PARAMETER_TYPES` (line 31).
  4. Declare the validated fermion types in `src/support.jl`.
  5. Meson-type observables can reuse `Meson_correlator_measurement` with custom `LocalMesonChannel`s, as `PCAC_mass_measurement` does (PCAC_mass.jl:113-143).
  6. The DWF path builds its own `Dirac_operator` Dict directly (Domainwall_residual_mass.jl:105-116).
- **Another dimension.** The following are 4D-only, and this is where it is enforced:
  - Topological charge: `calc_Q` errors for Dim≠4 at topological_charge.jl:338-342. `epsilon_tensor` is fixed 4×4×4×4 (line 390). The `"rect"` loops hard-code `μ,ν = 1:4` (lines 447-448). The cross term checks Dim at line 260. The constructor itself does not check.
  - Topological charge density correlation: `calc_Q_each` (density_correlation.jl:361-365) and line 246.
  - Gauge densities: `_density_lattice_size` (gauge_density.jl:4).
  - Gradient flow: `GradientFlowScale_measurement` (gradient_flow_scale.jl:110). Its `measure` is also typed `AbstractGaugefields{NC,4}` (line 245).
  - Energy density: `@assert Dim == 4` (energy_density.jl:124), and `NDir = 6` is hard-coded (line 105).
  - Wilson loop: `make_Wilson_loop` allocates a 4×4 array (Wilon_loop.jl:181), and `NDir = 3.0` is hard-coded (line 112).
  - Pion: `Dim == 4 || error` (Pion_correlator.jl:439, checked only after the propagators are solved), `_accumulate_pion_correlator!` (line 332), and `source_position` must have 4 entries (line 569).
  - Meson: line 262. PCAC: `measure` is typed `{NC,4}` (PCAC_mass.jl:176). DWF: line 73.
  - Plaquette allows only Dim 2 or 4 (plaquette.jl:62-68).
  - Pion, Chiral, Eigenvalue and MdagM constructors pick a 2D boundary condition (e.g. eigenvalues.jl:49-57). For any other Dim, `boundarycondition` is never assigned.
  - Correlation and Gluonic: `Wilsonline(loop)` defaults to `Dim=4` (Wilsonloop.jl:77), and `loop1position` defaults to 4 entries (correlation.jl:26).

## Notes
- **The fallback `measure` has the wrong signature.** It is `measure(m, itrj, U)` (AbstractMeasurement.jl:31), while every real method is `measure(m, U; additional_string)`. Gluonic and topological-density-correlation instead need `(m, U, loop1position, relativeposition)` (Guluonic_correlators.jl:71, density_correlation.jl:87).
- **`"clover"` also returns improved values.** In `kinds_of_topological_charge`, `"clover"` also computes the improved Q chosen by `improved_topological_charge_definition`, which defaults to `"alexandrou"` (topological_charge.jl:147-175). One method therefore gives 2-3 values.
- **The rect normalisation differs between the two improved definitions.** Alexandrou doubles it: `Qrectangle = 2*calc_Q` (topological_charge.jl:221). Bilson-Thompson does not (line 245). The code comments explain this.
- **Two different "energy density" conventions.** `Energy_density_measurement` uses its own normalisation, `/NV/6/NC/8` (energy_density.jl:106). It differs from `action_density` and the gradient-flow E; gauge_density.jl:289-291 says the legacy one returns one for unit links.
- **Gradient-flow return values.** The plaquette energy is `2·NC·Nplanes·(1−plaq)` (gradient_flow_scale.jl:226). `estimate_flow_scales` returns `t0` as a flow time but `w0` as `sqrt(w0²)` (lines 367-369).
- **Duplicated code.**
  - The clover leaves exist both in `make_cloverloops_topo` (topological_charge.jl:481) and in Wilsonloop's `make_cloverloops` (Wilsonloop.jl:597).
  - The site-wise topological helpers (density_correlation.jl:180-386) reimplement the field-wise ones under the same names, as methods with an extra `position` argument.
  - The commented-out copy of the energy-density code sits at correlation.jl:184-251.
  - The smearing setup is copied in Pion (217-241) and Chiral (168-192).
- **Misleading names.**
  - `Guluonic` is a typo kept as the canonical type name. `GluonicCorrelatorMeasurement` is only an alias (QCDMeasurements.jl:39).
  - `measure_Wilon_loop.jl` and `calc_large_wiloson_loop!` (Wilon_loop.jl:192) are typos. The second is different from `calc_large_wilson_loop!` (energy_density.jl:140).
  - `Pion_correlator_measurement` doubles as the generic propagator engine for Meson.
  - The comment at energy_density.jl:97 says "Wilson loop".
- **Default filenames disagree.** Constructor default vs `prepare_measurement` default: Polyakov `"Polyakov.txt"` (polyakov.jl:48) vs `"Polyakov_loop.txt"` (parameters.jl:439). Gluonic `"Guluonic_correlators.txt"` vs `"Gluonic_correlators.txt"`. MdagM `"MdagMspectrums.txt"` (MdagMspectrum.jl:124) vs `"MdagMspectrum.txt"`.
- **Default values disagree.** MdagM emin/emax are −2/2 in params (parameters.jl:296-297) but −3/3 in the kwargs constructor (MdagMspectrum.jl:30-31). Several kwargs constructors default to `κ=1` (Pion line 40, Chiral line 25, Eigen line 25).
- **Probable bug, not covered by the default test run.** For Wilson or WilsonClover, `fermionparameter_params` passes `cSW` (parameters.jl:568). The `Eigenvalue_measurement` and `MdagMspectrum_measurement` kwargs constructors have no `cSW` keyword (eigenvalues.jl:15-34, MdagMspectrum.jl:15-35). So building these from params or a Dict with Wilson fermions should throw an unsupported-keyword error. The only test that does this is `test/dicttest.jl`, which runtests.jl:29 marks as legacy.
- **Chiral condensate reads top-level fields.** It uses `params.mass`, `params.Nf`, `params.hop` and `params.r`, not `fermion_parameters`, which `ChiralCondensate_parameters` does not have (chiral_condensate.jl:201-216). It supports only Wilson and Staggered (line 36).
- **The eigenvalue `measure(m, U)` builds the sparse matrix twice.** Lines 131-134 build `Ds` and discard it, and the second method builds it again (line 148).
- **Pion printing differs.** It uses `println_verbose_level1` (Pion_correlator.jl:468). It also prints progress through `U[1]` regardless of `printvalues` (line 410).
- **Wilson-loop return text.** `measurestring` keeps only the last (T,R) line (Wilon_loop.jl:117).
- **Hardware requirements.** WilsonClover needs the MPILattice backend (Pion_correlator.jl:61-68). DWF needs MPILattice and NC=3 (Domainwall_residual_mass.jl:77-80).
