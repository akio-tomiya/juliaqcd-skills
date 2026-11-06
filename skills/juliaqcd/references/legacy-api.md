# Translating pre-v1 code

Code written for Gaugefields 0.x and LatticeQCD 1.x (and what language
models often remember) uses the names on the left. Translate to the right
before running. The authoritative table is `docs/src/legacyapi.md` in
Gaugefields.jl.

The old names still run: they select the compatibility `LegacyBackend`,
which does not take the LatticeMatrices/JACC path (no GPU, no explicit
seeds). Translate rather than keep them.

**Normalizations changed, not only names.** `calculate_Plaquette` returned
the sum over sites and planes (4608 for a cold 4⁴ SU(3) field);
`measure_plaquette` returns the normalized value (1 for a cold field).
Pass `normalize=false` to get the old sum, for example when comparing with
numbers from old runs. The same holds for `measure_polyakov_loop`. After
translating, run once on a cold start and check the value against the
expected one.

| Before v1 | v1 |
|---|---|
| `Initialize_Gaugefields(NC, NDW, L1, ..., Ld; condition="hot")` | `gauge_configuration((L1, ..., Ld); colors=NC, start=:hot, seed=...)` |
| `Nwing`, `NDW` | `halo` (default 1 on the recommended path; leave it out) |
| `Temporalfields(U[1], num=...)` passed to measurements | not needed: v1 measurements allocate their own work fields |
| `condition="cold"` / `"hot"` | `start=:cold` / `:hot` |
| `randomnumber="Reproducible"` | explicit `seed` and `rng` |
| `mpi`, `PEs`, `isMPILattice` | `process_grid` (and `comm`) |
| `cuda`, `accelerator` | choose the JACC backend before `using Gaugefields` |
| `calculate_Plaquette(U, temp1, temp2)` (sum) | `measure_plaquette(U)` (normalized; `normalize=false` for the sum) |
| `calculate_Polyakov_loop` (sum) | `measure_polyakov_loop(U)` (normalized; `normalize=false` for the sum) |
| `initialize_TA_Gaugefields` | `gauge_momenta` |
| `gauss_distribution!` | `gaussian_momenta!` |
| `Gradientflow`, `Gradientflow_general` | `gradient_flow`, `flow!` |
| `Heatbath`, `Heatbath_update` | `heatbath_updater`, `heatbath!` |
| `STOUT_Layer`, `CovNeuralnet`, `calc_smearedU` | `smear` with `StoutSmearing` (native path) or `stout_smearing` (arbitrary loops) |
| `saveU`, `loadU` | `save_configuration`, `load_configuration!` |
| hand-written `MDstep!`, `U_update!`, `P_update!` | `md_driver`, `md_trajectory!`, or a custom integrator through `update_momenta!` and `update_gaugefields!` |
| `topological_charge_density` in Gaugefields | QCDMeasurements measurements |
| `Plaquette_measurement` and other snake-case measurement types | `PlaquetteMeasurement` and so on (old names remain as aliases) |
| `prepare_measurement_from_dict` | `prepare_measurement` |
| domain-wall field `w[s]` (one 4D field per slice) | one 5D `LatticeMatrix` |
| old LatticeQCD wizard | `run_wizard()` (old one: `run_wizard_legacy()`) |

Every v1 script starts with

```julia
import JACC
JACC.@init_backend
using Gaugefields
```
