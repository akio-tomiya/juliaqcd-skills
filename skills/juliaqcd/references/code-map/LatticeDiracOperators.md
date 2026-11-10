# LatticeDiracOperators.jl 1.1.6: code map

Part of `../code-map.md`; read its first part (versions, how to cite a line) before this one. Paths are relative to the package root; `file:N` is line N in version 1.1.6.

## File map
Paths are relative to the package root. "v1" means the LatticeMatrices/JACC standard path. "legacy" means wing/nowing/accelerator/CUDA code that is kept only for API compatibility.
- `src/LatticeDiracOperators.jl`: top-level module. Includes `communication.jl`, `rhmc/`, `Diracoperators.jl`, `SakuraiSugiura/SSmodule.jl`, `action/NHYPSmearedFermiAction.jl` and `PseudofermionMDAction.jl`. Holds imports and exports, and re-exports γ1..γ4 from LatticeMatrices (line 31).
- `src/communication.jl`: `module Communication`, the serial communicator. MPI is plugged in by `ext/LatticeDiracOperatorsMPIExt.jl`.
- `src/Diracoperators.jl`: `module Dirac_operators`. Holds the abstract operator types, the string-dispatched `Dirac_operator` and `DdagD_operator` constructors, generic `solve_DinvX!`, generic D†D `mul!`, `check_parameters` and `construct_sparsematrix`. It includes everything below except rhmc, SSmodule, NHYP and PseudofermionMD.
- `src/cgmethods.jl`: solvers: `bicg`, `bicgstab`, `cg`, `shiftedcg`, `gmres`, even/odd BiCGStab, and the `SolverDiagnostics` struct. `src/cg/cgs.jl` is a second `shiftedcg` that is **not included anywhere** (dead).
- `src/rhmc/AlgRemez.jl`: wrapper that runs the AlgRemez_jll binary. `src/rhmc/rhmc.jl`: `module Rhmc`, the stored coefficient tables and `struct RHMC`.
- `src/AbstractFermions.jl`: abstract field types, σμν, `__init__` (`@require` for legacy MPI/CUDA) and legacy `Initialize_pseudofermion_fields`. `src/AbstractFermion_MPILattice.jl`: the v1 `Initialize_pseudofermion_fields`.
- `src/AbstractFermions_{2D,3D,4D,5D}.jl`: abstract `_ND` field types plus legacy shifted-field machinery (mostly legacy).
- `src/WilsonFermion/`: v1 files are `WilsonFermion.jl` (abstract types, legacy `Wilson_Dirac_operator`, `DdagD_Wilson_operator`, `mk_gamma`), `WilsonFermion_4D.jl` (common 4D interface and the legacy even/odd helpers), `WilsonFermion_4D_MPILattice.jl` (v1 field), `linearalgebra_4D.jl` (transitional LatticeMatrix kernels, partly commented out), `WilsonFermion_improved.jl` (v1 Wilson wrapper around LM `WilsonDiracOperator4D`) and `WilsonFermion_clover.jl` (v1 clover wrapper). `deprecated/` and `deprecated/kernelfunctions/` are legacy (still included).
- `src/StaggeredFermion/`: v1 files are `StaggeredFermion.jl` (abstract type and `DdagD_Staggered_operator`), `StaggeredFermion_4D_MPILattice.jl` (field), `StaggeredDiracOperator_4D_MPILattice.jl` and `HISQDiracOperator_4D_MPILattice.jl`. `deprecated/` is legacy. `deprecated/notused/` is not included.
- `src/DomainwallFermion/`: `DomainwallFermion_5D_MPILattice.jl` (v1 5D field plus the Shamir/Möbius LM operator wrapper; it is included from `MobiusDomainwallFermion/MobiusDomainwallFermion.jl:4`), `linearalgebra_5D.jl` (v1 5D kernels), `physical_propagator.jl` and `residual_mass_gradient.jl` (v1 measurements). `DomainwallFermion.jl` only includes `deprecated/DomainwallFermion_legacy.jl` (legacy).
- `src/MobiusDomainwallFermion/`: `MobiusDomainwallFermion.jl` (5-line include file). `deprecated/MobiusDomainwallFermion_legacy.jl` is **mixed**: it holds the v1 high-level `MobiusDomainwall_Dirac_operator` (see Notes). `deprecated/MobiusDomainwallFermion_5d.jl` is legacy.
- `src/GeneralizedDomainwallFermion/`: `GeneralizedDomainwallFermion.jl` (outer operator, shared by legacy and v1), `GeneralizedDomainwallFermion_5D_MPILattice.jl` (v1), `GeneralizedDomainwall_evenodd.jl` (v1 even/odd Schur solver). `deprecated/` is legacy.
- `src/GeneralFermion/generalFermion.jl`: `GeneralFermion` (LatticeMatrix-backed and dimension-generic) and the callback operator `DdagDgeneral`.
- `src/action/`: `FermiAction.jl` (abstract type and dispatch), `WilsonFermiAction.jl`, `StaggeredFermiAction.jl` (includes RHMC), `HISQFermiForce.jl`, `LatticeStaggeredFermiAction.jl` (GeneralFermion-based staggered/HISQ action), `MobiusDomainwallFermiAction.jl`, `GeneralizedDomainwallFermiAction.jl` plus `_evenodd.jl`, `GeneralFermionAction.jl` and `NHYPSmearedFermiAction.jl` (NHYP and generic smeared wrappers). Legacy: `DomainwallFermiAction.jl` (not reached on v1, see Notes) and `WilsontypeFermiAction.jl` (for `Wilson_GeneralDirac_operator`). Not included at all: `GeneralWilsonFermiAction.jl` and `clover_data.jl` (dead).
- `src/PseudofermionMDAction.jl`: adapter from an LDO action to the Gaugefields MD interface (`md_potential`, `md_force!`, refresh).
- `src/Z4Noise.jl`: Z4 noise sources.
- `src/SakuraiSugiura/SakuraiSugiuramethod.jl`: `eigensystem` (used). `SSmodule.jl` is included as `module SSmodule` but nothing imports it (unused).
- `ext/LatticeDiracOperatorsEnzymeExt.jl` and `ext/AD_generalfermion.jl`: Enzyme AD for `GeneralFermionAction` and `dSFdU!`. `ext/fallbackmacro.jl`: Enzyme fallback rules. `ext/LatticeDiracOperatorsMPIExt.jl`: MPI communicator. `ext/deprecated/mpi/*`: legacy MPI fields, loaded through `@require`.

## Main types and functions (v1 path)
| Name | Kind | Location | What it is |
|---|---|---|---|
| `Abstractfermion` / `AbstractFermionfields{NC,Dim}` | abstract types | src/AbstractFermions.jl:5 / :16 | Root of all fermion fields |
| `AbstractFermionfields_4D` / `_5D` | abstract types | src/AbstractFermions_4D.jl:3 / src/AbstractFermions_5D.jl:1 | Dimension layer |
| `WilsonFermion_4D` → `WilsonFields_4D_MPILattice` | abstract types | src/WilsonFermion/WilsonFermion_4D.jl:2 → src/WilsonFermion/WilsonFermion_4D_MPILattice.jl:28 | Wilson field hierarchy |
| `WilsonFermion_4D_MPILattice` | struct | src/WilsonFermion/WilsonFermion_4D_MPILattice.jl:40 | v1 Wilson field: `f::LatticeMatrix`, NC×4 per site, default BC `[1,1,1,-1]` (line 60) |
| `StaggeredFermion_4D_MPILattice` | struct | src/StaggeredFermion/StaggeredFermion_4D_MPILattice.jl:26 | v1 staggered/HISQ field, NC×1 per site |
| `DomainwallFermion_5D_MPILattice` | struct | src/DomainwallFermion/DomainwallFermion_5D_MPILattice.jl:8 | v1 5D field for all domain-wall families. `MobiusDomainwallFermion_5D_MPILattice` is a `const` alias (line 145) |
| `GeneralFermion` | struct | src/GeneralFermion/generalFermion.jl:26 | Callback field wrapping a LatticeMatrix, any dimension |
| `Initialize_pseudofermion_fields(u::Gaugefields_4D_MPILattice, name::String)` | function | src/AbstractFermion_MPILattice.jl:19 | v1 field factory: "Wilson", "staggered", "Domainwall", "MobiusDomainwall", "GeneralizedDomainwall" |
| `Initialize_WilsonFermion` (MPILattice) / `Initialize_StaggeredFermion` | function | src/WilsonFermion/WilsonFermion_4D_MPILattice.jl:120 / src/StaggeredFermion/StaggeredFermion_4D_MPILattice.jl:101 | Build a field from a gauge link |
| `Operator`, `Dirac_operator{Dim}`, `DdagD_operator`, `γ5D_operator`, `Adjoint_Dirac_operator` | abstract types | src/Diracoperators.jl:43, 46, 48, 50, 62 | Operator hierarchy |
| `Wilson_Dirac_operators{Dim}` / `Staggered_Dirac_operators{Dim}` | abstract types | src/WilsonFermion/WilsonFermion.jl:6 / src/StaggeredFermion/StaggeredFermion.jl:3 | Family supertypes. `FermiAction` dispatches on these |
| `Dirac_operator(U, x, parameters)` | function | src/Diracoperators.jl:162 | String entry point. The `parameters["Dirac_operator"]` if-chain is at lines 168–220 |
| `DdagD_operator(U, x, parameters)` | function | src/Diracoperators.jl:231 | D†D entry point, string chain at lines 237–258 |
| `check_parameters` | function | src/Diracoperators.jl:518 | Dict lookup with a default |
| `Wilson_Dirac_operator_improved` | struct | src/WilsonFermion/WilsonFermion_improved.jl:2 | v1 Wilson and Wilson–clover wrapper. Field `D` holds the LM operator. Chosen for "Wilson" plus MPILattice links when "improved gpu" is true, which is the default (Diracoperators.jl:191–194) |
| `Wilson_Dirac_operator_improved(U,x,p)` / `_build_Wilson_Dirac_operator_LM` | function | src/WilsonFermion/WilsonFermion_improved.jl:131 / :53 | Builds LM `WilsonDiracOperator4D(links, κ)` (or `_Donly`), then validates BC, temporaries and solver settings |
| `mul!` D / D† (Wilson, clover) | method | src/WilsonFermion/WilsonFermion_improved.jl:220 / :239 | Applies `factor * D_LM`. The adjoint struct is at :209 |
| `(D::Wilson_Dirac_operator_improved)(U)` | functor | src/WilsonFermion/WilsonFermion_improved.jl:192 | Rebuilds the operator for new links. Actions call this |
| `_solver_mul!` etc. (Wilson) | method | src/WilsonFermion/WilsonFermion_improved.jl:263–278 | Solver hooks that defer the halo exchange. Generic defaults are in src/cgmethods.jl:33–36 |
| `Wilson_Dirac_operator_clover` | function | src/WilsonFermion/WilsonFermion_clover.jl:21 | "WilsonClover" builds LM `WilsonDiracCloverOperator4D(links,κ,cSW)`, default `cSW=1.5612` (line 40). Clover apply: `_mul_Wilson_LM!` at :67, adjoint at :76 |
| `has_cloverterm` | function | src/Diracoperators.jl:60 (default); src/WilsonFermion/WilsonFermion_clover.jl:45 | Clover flag (4 methods, also in WilsonFermion.jl:31 and WilsonFermion_improved.jl:197) |
| `DdagD_Wilson_operator` | struct | src/WilsonFermion/WilsonFermion.jl:1019 | D†D wrapper. Its `mul!` is the generic one at src/Diracoperators.jl:475 |
| Hopping term / gamma (v1) | external | LatticeMatrices (`WilsonDiracOperator4D`, `Oneγ`) | The v1 stencil is **not in this repo**. LDO-side spin projectors are `mul_1plusγμx!` / `mul_1minusγμx!` / `mul_x1plusγμ!` at src/WilsonFermion/WilsonFermion_4D_MPILattice.jl:458 / :469 / :432, and the `Oneγμ` struct at src/WilsonFermion/linearalgebra_4D.jl:228 |
| `mk_gamma` / `γ_all` | function / const | src/WilsonFermion/WilsonFermion.jl:342 / :528 | Legacy chiral-basis gammas, documented at lines 319–341. The improved wrapper still fills `γ`, `rplusγ`, `rminusγ` from these (WilsonFermion_improved.jl:92) |
| `σμν` | struct | src/AbstractFermions.jl:44 | σ_{μν} tags |
| BC: field phases | — | src/WilsonFermion/WilsonFermion_4D_MPILattice.jl:96 (`LatticeMatrix(...; phases)`) | Phases live in the LatticeMatrix. `set_wing_fermion!` → `set_halo!` (line 372, BC-checking variant at 379) applies them |
| BC: operator validation | function | src/WilsonFermion/WilsonFermion_improved.jl:32 (`_wilson_lm_boundarycondition`), :45 (`_check_operator_field_boundaries`); default no-op at src/Diracoperators.jl:266 | Operator BC must equal field phases (0, +1 or −1). Staggered check: src/StaggeredFermion/StaggeredFermion_4D_MPILattice.jl:9. DW check: src/MobiusDomainwallFermion/deprecated/MobiusDomainwallFermion_legacy.jl:314–325 |
| `Staggered_Dirac_operator_MPILattice` | struct | src/StaggeredFermion/StaggeredDiracOperator_4D_MPILattice.jl:3 | Wraps LM `StaggeredDiracOperator4D`. Constructor `Staggered_Dirac_operator` at :25, `mul!` D/D† at :111/:121 |
| `HISQ_Dirac_operator_MPILattice` | struct | src/StaggeredFermion/HISQDiracOperator_4D_MPILattice.jl:11 | Wraps LM `HISQDiracCache4D`. Constructor at :60, `mul!` D/D† at :154/:166 |
| `DdagD_Staggered_operator` | struct + `mul!` | src/StaggeredFermion/StaggeredFermion.jl:12 / :31 | D†D for staggered and HISQ |
| `D5DW_MobiusDomainwall_operator_MPILattice` | struct | src/DomainwallFermion/DomainwallFermion_5D_MPILattice.jl:365 | Wraps LM `D5DW_MobiusDomainwallOperator5D`. Constructor at :385, `mul!` D/D† at :572/:588 |
| `MobiusDomainwall_Dirac_operator` | struct | src/MobiusDomainwallFermion/deprecated/MobiusDomainwallFermion_legacy.jl:191 | Outer operator D(m)·D(PV)^{-1}. Constructor at :210 (default b=2, c=1). `mul!` D/D† at :596/:557 |
| `Domainwall_Dirac_operator` (MPILattice) | function | src/MobiusDomainwallFermion/deprecated/MobiusDomainwallFermion_legacy.jl:357 | v1 Shamir: Möbius with b=c=1 |
| `DdagD_MobiusDomainwall_operator`, `MobiusD5DWdagD5DW_Wilson_operator` | struct | same file :414, :433 (`mul!` at :472) | D†D used by actions |
| `D5DW_GeneralizedDomainwall_operator_MPILattice` | struct | src/GeneralizedDomainwallFermion/GeneralizedDomainwallFermion_5D_MPILattice.jl:8 | Wraps LM generalized 5D operator (as/bs/cs per slice). Constructor at :31, `mul!` at :118/:128 |
| `GeneralizedDomainwall_Dirac_operator` | struct / v1 ctor | src/GeneralizedDomainwallFermion/GeneralizedDomainwallFermion.jl:160 / src/GeneralizedDomainwallFermion/GeneralizedDomainwallFermion_5D_MPILattice.jl:148 | Outer operator. Defaults as=1, bs=1.5, cs=0.5. `Renew` at :187/:219 |
| Even/odd (generalized DW, v1) | struct / func | src/GeneralizedDomainwallFermion/GeneralizedDomainwall_evenodd.jl:315 (`..._evenodd_MPILattice`), `solve_DinvX_eo!` :525, solve/mul! overrides :554–611 | Enabled by `parameters["evenodd"]=true` (…_5D_MPILattice.jl:59) |
| Even/odd (Wilson, legacy only) | struct / func | src/WilsonFermion/WilsonFermion.jl:34; `calc_beff!` src/WilsonFermion/WilsonFermion_4D.jl:59; `Toex!` :106; `WWx!` :184; `bicgstab_evenodd` src/cgmethods.jl:579; dispatch src/Diracoperators.jl:311 | `method_CG="preconditiond_bicgstab"`. Clover rejects it (WilsonFermion_clover.jl:32) |
| `solve_DinvX!` | function | src/Diracoperators.jl:300 (Dirac), :354 (adjoint), :433 (DdagD → `cg`) | Chooses bicg or bicgstab from `A.method_CG` (6+ methods, also in GeneralizedDomainwall_evenodd.jl) |
| `bicg` / `bicgstab` / `cg` / `shiftedcg` / `gmres` | function | src/cgmethods.jl:64 / :176 / :799 / :904 / :1308 | Krylov solvers. `shiftedcg` is the multishift CG used by RHMC. `SolverDiagnostics` at :19 |
| `FermiAction{Dim,Dirac,fermion,gauge}` | abstract type | src/action/FermiAction.jl:10 | Action supertype |
| `FermiAction(D, params)` | function | src/action/FermiAction.jl:22 | Dispatches on the operator supertype (lines 35–54) |
| `evaluate_FermiAction` / `gauss_sampling_in_action!` / `sample_pseudofermions!` / `calc_UdSfdU` / `calc_UdSfdU!` | generic fallbacks | src/action/FermiAction.jl:65 / :78 / :107 / :121 / :141 | Interface every action implements |
| `WilsonFermiAction` | struct | src/action/WilsonFermiAction.jl:11 | Wilson and clover action. `evaluate` :145, `calc_UdSfdU!` :165, `calc_UdSfdU_fromX!` (analytic hopping force) :204, clover force `_calc_lm_clover_force_fromX!` (LM `wilson_clover_link_pullback!`) :112, `calc_p_UdSfdU!` :302, `sample_pseudofermions!` (ϕ = D†ξ) :454 |
| `StaggeredFermiAction` | struct | src/action/StaggeredFermiAction.jl:4 | RHMC objects built at lines 31–53. `evaluate` :125 (rational), :172 (Nf=8), :186 (Nf=4). `sample_pseudofermions!` :251. Force `calc_UdSfdU!` :309 (rational, shiftedcg), :362/:372 (Nf=4/8). MPILattice `calc_UdSfdU_fromX!` :454. Nf=4 parity projection in `gauss_sampling_in_action!` :210 |
| HISQ force | method | src/action/HISQFermiForce.jl:1 | `calc_UdSfdU_fromX!` for HISQ via LM `hisq_link_pullback!` (needs halo ≥ 3) |
| `StaggeredFermiAction(U, ::GeneralFermion; mass, Nf, discretization)` | function | src/action/LatticeStaggeredFermiAction.jl:82 | Alternative keyword constructor (`:staggered` or `:hisq`). RHMC at :57, sample :249, force :343 |
| `MobiusDomainwallFermiAction` | struct | src/action/MobiusDomainwallFermiAction.jl:5 | Used for v1 "Domainwall" and "MobiusDomainwall". `calc_UdSfdU!` :68, shared DW force kernel `_calc_UdSfdU_fromX_MPILattice!` :121, sample :350 |
| `GeneralizedDomainwallFermiAction` | struct | src/action/GeneralizedDomainwallFermiAction.jl:5 | `evaluate` :81, `calc_UdSfdU!` :99, sample :503. EO versions in `GeneralizedDomainwallFermiAction_evenodd.jl` :5/:16/:30 |
| `combine_generalized_domainwall_force!` | function | src/DomainwallFermion/DomainwallFermion_5D_MPILattice.jl:512 | Per-slice coefficients in the generalized DW force |
| `AlgRemez_coeffs` / `calc_coefficients` | struct / function | src/rhmc/AlgRemez.jl:10 / :54 | f(x)=α0+Σα_i/(x+β_i). `calc_coefficients` runs AlgRemez_jll in a temp dir |
| `RHMC` | struct | src/rhmc/rhmc.jl:1136 (ctors :1142 Rational, :1163 (y,z)) | Table lookup at :1183–1240, otherwise AlgRemez at :1244. Defaults `n=10, lambda_low=0.0004, lambda_high=64, precision=42`. Getters `get_α` etc. at :1273–1297 |
| Stored RHMC tables | const | src/rhmc/rhmc.jl:4–1093 (`coeffs_12` :4 … `coeffs_m38_n15` :1093) | Precomputed x^{±p/q} tables |
| `eigensystem` | function | src/SakuraiSugiura/SakuraiSugiuramethod.jl:64 | Sakurai–Sugiura contour eigensolver (uses `shiftedbicg_2003`, src/cgmethods.jl:1224). Also `eigensystem_old` :500, `estimate_numberofeigenvalues` :2 |
| `GeneralFermionAction` | struct | src/action/GeneralFermionAction.jl:16 | Action built from user `apply_D!` / `apply_Ddag!` callbacks. `calc_UdSfdU!` :107, `vdD` :99, sample :71 |
| `DdagDgeneral` | struct | src/GeneralFermion/generalFermion.jl:300 | Callback D†D, `mul!` at :383 |
| `_general_fermion_derivative!` | stub / Enzyme impl | src/action/GeneralFermionAction.jl:1 / ext/LatticeDiracOperatorsEnzymeExt.jl:32 | Force via Enzyme. `dSFdU!` stub at src/GeneralFermion/generalFermion.jl:7, impl at ext/AD_generalfermion.jl:8 |
| `NHYPSmearedFermiAction` | struct | src/action/NHYPSmearedFermiAction.jl:40 | nHYP-smeared action. `md_force!` (pullback) :103, `refresh_nhyp_pseudofermions!` :162 |
| `SmearedFermiAction` | struct | src/action/NHYPSmearedFermiAction.jl:232 | Any Gaugefields `NativeLinkSmearing` that has a pullback. `md_force!` :296, `refresh_smeared_pseudofermions!` :345 |
| `PseudofermionMDAction` | struct | src/PseudofermionMDAction.jl:29 | MD provider. `refresh_pseudofermion!` :133/:151, `md_force!` :225/:255 (force = −TA(calc_UdSfdU)) |
| `construct_sparsematrix` | function | src/Diracoperators.jl:554 | Dense or sparse matrix of an operator, for testing |

## Where to make changes
- **New Dirac operator.**
  - From a separate package that depends on LatticeDiracOperators (the route the skills recommend), define the type and its methods below, construct it with your own constructor, and give `FermiAction` a method for the new type (more specific than the if-chain); this changes no file of the package. The string branches in `Dirac_operator`, `DdagD_operator`, and `Initialize_pseudofermion_fields` are needed only to select the operator by name from a parameter Dict, and they patch the package itself.
  - Subtype `Dirac_operator{Dim}` (src/Diracoperators.jl:46). Use `Wilson_Dirac_operators{Dim}` or `Staggered_Dirac_operators{Dim}` if you want `FermiAction` to reuse the Wilson or staggered action.
  - Store the fields that the generic code reads: `U`, `_temporary_fermi`, `_temporary_fermion_forCG` (`Temporalfields`), `boundarycondition`, `eps_CG`, `MaxCGstep`, `method_CG`, `verbose_print`. They are read in src/Diracoperators.jl:95–117, :300–352, :417–431 and in the solvers in src/cgmethods.jl.
  - Define `mul!(y, D, x)`, an `Adjoint_Dirac_operator` subtype, `Base.adjoint` and `mul!` for D†. These follow the pattern in src/WilsonFermion/WilsonFermion_improved.jl:209–255.
  - Define the functor `(D)(U)`, which rebuilds the operator for new links. Actions call it on every evaluation.
  - Define a `DdagD_operator` subtype with a `.dirac` field. The generic D†D `mul!` is at src/Diracoperators.jl:475. `DdagD_Wilson_operator`'s catch-all inner constructor (WilsonFermion.jl:1046) assumes the first three type parameters are `{Dim,T,fermion}`.
  - Optionally define `_check_operator_field_boundaries` (Diracoperators.jl:266) and the `_solver_*` hooks (cgmethods.jl:33).
  - Add a string branch in `Dirac_operator` (src/Diracoperators.jl:168–220) and in `DdagD_operator` (:237–258). If the operator needs its own field type, also add a branch in `Initialize_pseudofermion_fields` (src/AbstractFermion_MPILattice.jl:40–55).
  - Add a branch in `FermiAction(D, params)` (src/action/FermiAction.jl:35–54) unless the new type subtypes an existing family.
- **New fermion action or force.**
  - Subtype `FermiAction{Dim,Dirac,fermion,gauge}` (src/action/FermiAction.jl:10). Implement `evaluate_FermiAction`, `gauss_sampling_in_action!`, `sample_pseudofermions!` and `calc_UdSfdU!`. They must return `U (∂S/∂U)†`, the convention described at FermiAction.jl:113–119.
  - Add the file's include in FermiAction.jl:12–20 and a dispatch branch at :35.
  - HMC integration then works through `PseudofermionMDAction` (src/PseudofermionMDAction.jl:29) or the smeared wrappers (src/action/NHYPSmearedFermiAction.jl), with no further changes.
  - Templates: Wilson force at src/action/WilsonFermiAction.jl:204, rational force at src/action/StaggeredFermiAction.jl:309, DW force at src/action/MobiusDomainwallFermiAction.jl:121.
  - Without an analytic force, use `GeneralFermionAction` plus Enzyme.
- **New solver.**
  - Add the function in src/cgmethods.jl. It takes temporaries via `get_temporaryvectors_forCG(A)` and `get_temp`/`unused!`, applies the operator with `_solver_mul!`, and returns `SolverDiagnostics`.
  - Add a `method_CG` branch in `solve_DinvX!` (src/Diracoperators.jl:307–346 and :360–410). The D†D path is hard-wired to `cg` at :451.
  - Export it from src/LatticeDiracOperators.jl:43–105 and the export lines.
- **Changing the RHMC approximation.**
  - Staggered order and degree are fixed in `StaggeredFermiAction`: action `RHMC(Nf//16, n=15)` and MD `RHMC(Nf//8, n=10)` (src/action/StaggeredFermiAction.jl:41, :49), and the same in src/action/LatticeStaggeredFermiAction.jl:63–64. Allowed Nf: 1, 2, 4, 8 (LatticeStaggered :58). Nf=4/8 skip RHMC.
  - Range and precision are keyword arguments of `RHMC` (src/rhmc/rhmc.jl:1163). They take effect only when no stored table matches (n, num, den) (:1183–1240), so a new range for e.g. 1/2 at n=10 needs that table branch removed or bypassed.
  - New tables go next to `coeffs_*` in rhmc.jl, plus a branch at :1183.
  - Generation itself is in src/rhmc/AlgRemez.jl:54.
- **Different dimension.**
  - The v1 path is 4D-only.
  - `Initialize_pseudofermion_fields` hard-codes `Dim = 4` (src/AbstractFermion_MPILattice.jl:38) and is typed on `Gaugefields_4D_MPILattice`.
  - Field types are `*_4D_MPILattice` / 5D with 4 spatial directions. `shift_fermion` maps ν=±1..4 (src/WilsonFermion/WilsonFermion_4D_MPILattice.jl:304–327).
  - The Wilson wrapper requires four links and asserts `Dim == 4` (WilsonFermion_improved.jl:27, :65). Clover asserts `Dim == 4` (WilsonFermion_clover.jl:26), staggered requires four links (StaggeredDiracOperator_4D_MPILattice.jl:19), and DW asserts `Dim == 4` (DomainwallFermion_5D_MPILattice.jl:397). Generalized DW sets `Dim = 4` (GeneralizedDomainwallFermion_5D_MPILattice.jl:40, :153). The DW force rejects other dimensions (MobiusDomainwallFermiAction.jl:131).
  - `GeneralFermionAction` callbacks take U1..U4 (GeneralFermionAction.jl:99, ext/LatticeDiracOperatorsEnzymeExt.jl:32).
  - Only `GeneralFermion` is dimension-generic (generalFermion.jl:26).
  - 2D/3D support exists only in legacy files.
- **Fermion in another representation.**
  - There is no v1 support.
  - The field's color size is taken from the gauge link (`Initialize_WilsonFermion` passes `NC`, WilsonFermion_4D_MPILattice.jl:120–134).
  - The LM operator receives `link.U` directly (`_wilson_lm_links`, WilsonFermion_improved.jl:26). A representation change therefore means passing representation-converted links (of rep dimension) and building the field with that NC.
  - The force chain rule back to fundamental links would have to be added in the action's `calc_UdSfdU!`. A smeared-style pullback wrapper (NHYPSmearedFermiAction.jl:103) is the closest pattern.
  - Legacy adjoint-representation code exists only in src/WilsonFermion/deprecated/WilsonFermion_4D_wing_Adjoint.jl:6.

## Notes
- **v1 domain-wall code lives in a file under `deprecated/`.** The v1 `MobiusDomainwall_Dirac_operator` (struct :191, constructor :210) and the MPILattice `Domainwall_Dirac_operator` (:357) are both in src/MobiusDomainwallFermion/deprecated/MobiusDomainwallFermion_legacy.jl. So is the `import` of LM `D5DW_MobiusDomainwallOperator5D` (:4).
- **"Domainwall" (Shamir) on v1 is Möbius with b=c=1.** `FermiAction` therefore returns `MobiusDomainwallFermiAction`, not `DomainwallFermiAction` (src/action/FermiAction.jl:39–42). `DdagD_operator` checks for this at src/Diracoperators.jl:249.
- **Wilson v1 constructor name is misleading.** "Wilson" on MPILattice links builds `Wilson_Dirac_operator_improved` (Diracoperators.jl:191–194), not `Wilson_Dirac_operator` (the legacy struct, WilsonFermion.jl:8). The "faster version" branch is legacy-only.
- **Wilson even/odd does not appear to work with the v1 operator.** `preconditiond_bicgstab` builds `Wilson_Dirac_operator_evenodd(A)`, whose constructor only accepts the legacy `Wilson_Dirac_operator` (WilsonFermion.jl:37–39). I did not run it. The only v1 even/odd code is the generalized domain-wall one.
- **The clover-force docstring disagrees with the code.** The `calc_UdSfdU` docstring (src/action/FermiAction.jl:117–119) says Wilson–clover needs Enzyme. The code uses the analytic LM `wilson_clover_link_pullback!` (src/action/WilsonFermiAction.jl:3, :128), which matches src/WilsonFermion/README.md.
- **The legacy clover force is multiplied by zero:** `add_U!(UdSfdU[μ], -coeff * 0, temp0_g)` at src/action/WilsonFermiAction.jl:288. This branch is not reached on v1 (lm-clover returns early at :212).
- **Stored RHMC tables ignore `lambda_low`/`lambda_high`/`precision`** whenever (n, p/q) matches a table (src/rhmc/rhmc.jl:1183–1240). Several tables are never referenced in the dispatch: `coneffs_12_n15` (typo, :213), `coeffs_316_n10` (:404), `coeffs_116_n10` (:538). `coeffs_12`'s inner array (:5–31) has no `_n10` suffix but is the n=10 table.
- **Staggered Nf: Nf=4 and Nf=8 share the D†D force path** (StaggeredFermiAction.jl:381). Nf=4 differs only by the parity projection in `gauss_sampling_in_action!` (:210). In 2D, Nf is doubled (:24–25).
- **Gamma and hopping kernels for v1 are external** (LatticeMatrices). `mk_gamma` (WilsonFermion.jl:342) is legacy but is still called by the v1 wrapper to fill the unused `γ` fields. `mul_x1plusγμ!` implements right-multiplication by swapping signs for μ=1,3 (WilsonFermion_4D_MPILattice.jl:432–444).
- **The generic D†D `mul!` runs a NaN scan on every application:** `any(isnan, temp.f)` at src/Diracoperators.jl:492.
- **Force convention:** LDO forces are `U (∂S/∂U)†`, described as "−1/2 of the usual link gradient" (NHYPSmearedFermiAction.jl:120–123). MD providers apply `Traceless_antihermitian_add!(force, -1, …)` (PseudofermionMDAction.jl:245).
- **Buggy legacy dispatcher:** `Initialize_pseudofermion_fields(u, parameters)` at src/AbstractFermions.jl:302 compares the function `Dirac_operator` with a string (lines 310, 318).
- **Dead or unused files:** src/cg/cgs.jl, src/action/GeneralWilsonFermiAction.jl and src/action/clover_data.jl are not included. `module SSmodule` (src/SakuraiSugiura/SSmodule.jl) is included but never used. The include of src/StaggeredFermion/deprecated/notused/ is commented out.
- **Loading MPI activates two code paths:** the MPI extension (ext/LatticeDiracOperatorsMPIExt.jl) and, through `@require` in `__init__` (src/AbstractFermions.jl:153–157), the legacy ext/deprecated/mpi/legacy_mpi.jl.
- **DW 5th direction is not MPI-split:** `PEs[5] == 1` is enforced (src/DomainwallFermion/DomainwallFermion_5D_MPILattice.jl:60). The default 5D BC is `[1,1,1,-1,1]` (:31). The DW operator's `boundarycondition` is copied from the field phases (:424).
- **`solve_DinvX!` for D†D returns nothing,** not `SolverDiagnostics`, because its last expression is `set_wing_fermion!` (src/Diracoperators.jl:460).
- **Stencils in LatticeMatrices:** the Wilson, clover, staggered, HISQ and DW stencil kernels and `hisq_link_pullback!` are imported from LatticeMatrices; see "Dirac operators and smearing kernels" in `LatticeMatrices.md`.
