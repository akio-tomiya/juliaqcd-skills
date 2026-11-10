# LatticeMatrices.jl 1.2.11: code map

Part of `../code-map.md`; read its first part (versions, how to cite a line) before this one. Paths are relative to the package root; `file:N` is line N in version 1.2.11.

## File map
- `src/LatticeMatrices.jl`: module root. Wrapper types (`Shifted_Lattice`, `Adjoint_Lattice`, `Traceless_AntiHermitian`), shift construction, long-distance (alltoallv) shift materialization, `JACC.parallel_for`/`parallel_reduce` convenience overloads, Enzyme/AD stubs, and the include order.
- `src/LatticeMatrices_core.jl`: the `LatticeMatrix` abstract type and `LatticeMatrix_standard` struct, constructors, MPI transport selection, halo epochs, `_parallel_for_mutating!`, halo exchange (`set_halo!`, `exchange_dim!`), and gather/allsum. Also includes `LatticeScratchPool.jl`.
- `src/LatticeScratchPool.jl`: lazily grown scratch-array pool (wraps PreallocatedArrays). Used for temporaries and materialized shifts.
- `src/Latticeindices.jl`: the `DIndexer` type and `linearize`/`delinearize`/`shiftindices`, which map a kernel index to a site.
- `src/communication.jl`: the `SerialCommunicator` (single process) and the communication hooks (`_irecv!`, `_alltoallv!`, ...) whose MPI methods live in `ext/LatticeMatricesMPIExt.jl`.
- `src/device_selection.jl`: picks a GPU from the MPI rank (`select_device_by_mpi_rank!`). Each backend fills in its own hooks.
- `src/utilities/randomgenerator.jl`: random generators that run inside kernels (PCG32, xoshiro256++, Philox4x32-10), `RNGStreamKey`, `site_rng`, and the uniform/normal/bounded draws.
- `src/LinearAlgebras/linearalgebra.jl`: fallback errors for `mul!`/`expt!`. Includes `matrixexp.jl`, `linearalgebra_D.jl`, `cg.jl`.
- `src/LinearAlgebras/linearalgebra_D.jl`: dimension-generic field operations: axpby, substitute!, tr, dot, expt!, random fills, clear/identity, add_matrix!, traceless-antihermitian products. Includes `mul.jl`.
- `src/LinearAlgebras/mul.jl`: every `mul!` variant for combinations of plain, adjoint and shifted operands (with α,β), plus their kernels.
- `src/LinearAlgebras/mul_nowing.jl`: fused periodic-shift `mul!` for nw=0 lattices (`_LazyShifted_Lattice`).
- `src/LinearAlgebras/scaled_identity.jl`: `ScaledIdentityLattice` (a scalar field times the identity).
- `src/LinearAlgebras/staggered.jl`: `Staggered_Lattice` (staggered η phases) and its `mul!` methods.
- `src/LinearAlgebras/matrixexp.jl`, `src/LinearAlgebras/cg.jl`: small-matrix exponentials (3x3 Padé, SU(3) Cayley–Hamilton) and the CG solver.
- `src/TA/TA.jl`: `TALattice` and `traceless_antihermitian!` kernels.
- `src/ND.jl`: numerical-differentiation helpers used to check gradients.
- `src/measurements/*.jl`: `set_global_component!` (global_source), projected bilinear slices, and domain-wall physical source/solution import and export.
- `src/Operators/*.jl`: Dirac operators (Wilson, Clover, Staggered, HISQ, 5D domain-wall), `DiracOp` and `solve!`, link smearing (Stout, APE/HYP, nHYP, HEX, HISQ) and their pullbacks. These are 4D-specific.
- `ext/LatticeMatricesMPIExt.jl`: MPI.jl methods for the hooks in `communication.jl`.
- `ext/LatticeMatrices{CUDA,AMDGPU,oneAPI}Ext.jl` and `ext/*MPIExt.jl`: backend hooks for device selection, pinned buffers, and device-aware MPI detection.
- `ext/LatticeMatricesEnzymeExt.jl` and `ext/AD/*.jl`: Enzyme reverse-mode rules, including reverse halo folding.

## Main types and functions
| Name | Kind | Location | What it is |
|---|---|---|---|
| `Lattice{D,T,AT,NC1,NC2,NW}` | abstract type | src/LatticeMatrices.jl:12 | Top abstract type for fields (subtype of `AbstractLattice`, line 10) |
| `LatticeMatrix{D,T,AT,NC1,NC2,nw,DI}` | abstract type | src/LatticeMatrices_core.jl:26 | D = number of dimensions, T = element type, AT = array type, NC1×NC2 = matrix at each site, nw = halo width, DI = `DIndexer` type |
| `LatticeMatrix_standard{...,DI,C}` | struct | src/LatticeMatrices_core.jl:196 | The concrete field. `A` is the padded array laid out `(NC1,NC2,X+2nw,...)`. Also holds phases, `cart`/`coords`/`dims`/`nbr` (process grid), `buf`/`buf_host` (halo buffers), `PN` (local size), `indexer`, `temps`, `halo_epoch` |
| `LatticeMatrix(NC1,NC2,dim,gsize,PEs; nw, elementtype, phases, comm0, ...)` | constructor | src/LatticeMatrices_core.jl:423 | Public constructor (2 methods; the second, at :429, builds from a global array). Forwards to `LatticeMatrix_standard` |
| `LatticeMatrix_standard(...)` | constructor | src/LatticeMatrices_core.jl:438 | Validates sizes, builds the periodic Cartesian grid (:480), neighbour ranks `nbr` (:485), the padded array (:491) and 4D face buffers (:500-527). Global-array method at :547 |
| `Base.similar` | method | src/LatticeMatrices_core.jl:348 | Copies an existing field's structure with zeroed data. A generic fallback at :605 calls the constructor again |
| `_lattice_alias_with_array` | function | src/LatticeMatrices_core.jl:387 | Same field metadata wrapped around a different array |
| `HaloEpoch` | struct | src/LatticeMatrices_core.jl:31 | Counters for data writes vs last halo sync, used to skip unneeded halo updates |
| `mark_halo_dirty!` / `halo_is_dirty` | function | src/LatticeMatrices_core.jl:287 / :302 | Mark the halo stale / ask whether it is stale |
| `set_halo!` | function | src/LatticeMatrices_core.jl:700 | **Main halo update.** Loops `d=1:D` and calls `exchange_dim_local!` (one rank) or `exchange_dim!`. The nw=0 method at :695 only marks the halo clean |
| `ensure_halo!` | function | src/LatticeMatrices_core.jl:723 | Calls `set_halo!` only if the halo is stale. Shifted-lattice methods at src/LatticeMatrices.jl:994, :1001 |
| `_ensure_halo_for_shift!` | function | src/LatticeMatrices_core.jl:728 | Called by shift kernels before reading neighbours |
| `exchange_dim_local!` | function | src/LatticeMatrices_core.jl:852 | Periodic copy of faces into ghosts with boundary phases (dimension not decomposed) |
| `exchange_dim!` | function | src/LatticeMatrices_core.jl:1118 | MPI halo exchange for one dimension: pack the face, multiply the phase, post Isend/Irecv, unpack the ghost |
| `_exchange_dim_full_buffers!` | function | src/LatticeMatrices_core.jl:1059 | Full-face-buffer fallback (oneAPI) |
| `_post_packed_halo_exchange!` / `_finish_packed_halo_exchange!` | function | src/LatticeMatrices_core.jl:887 / :929 | Post and complete the sends/receives, either direct (device-aware MPI) or staged through host memory |
| `_exchange_packed_halo_buffers!` | function | src/LatticeMatrices_core.jl:1008 | Buffer-level exchange reused by the AD reverse pass (ext/AD/AD.jl:4799) |
| `_exchange_slab_matrix` | function | src/LatticeMatrices_core.jl:809 | Face/ghost slab views. Dimensions `<d` include their halos, so corners propagate |
| `_faceMatrix` / `_ghostMatrix` | function | src/LatticeMatrices_core.jl:747 / :780 | Generic slab views. Each also has a 6-dim-array (4D lattice) method at :762 / :792 |
| `compute_interior!` | hook | src/LatticeMatrices_core.jl:1216 | Empty hook called during the exchange (for overlapping compute) |
| `_resolve_mpi_transport` / `MPITransportConfig` | function / struct | src/LatticeMatrices_core.jl:110 / :55 | Chooses local, host_direct, host_staged or device_direct transport |
| `mpi_transport_info` | function | src/LatticeMatrices_core.jl:619 | Reports the chosen transport |
| `SerialCommunicator` | struct | src/communication.jl:2 | Single-process stand-in for MPI (comm hooks at :19-91) |
| `_cart_create`, `_cart_shift`, `_cart_coords`, `_cart_rank` | hooks | src/communication.jl:28/50/36/44; MPI methods at ext/LatticeMatricesMPIExt.jl:21-33 | Process-grid setup and queries |
| `select_device_by_mpi_rank!` | function | src/device_selection.jl:19 | Maps the node-local rank to a GPU ordinal |
| `DIndexer{D,dims,strides}` | struct | src/Latticeindices.jl:2 | Local-size indexer that can be passed into kernels |
| `delinearize` | function | src/Latticeindices.jl:127 | Kernel index i → site tuple (+nw offset). 9 methods: hand-written for D=1..6 at :67-116, `Val{nw}` wrapper at :160 |
| `linearize` | function | src/Latticeindices.jl:37 | Site tuple → linear index (Int32) |
| `shiftindices` | function | src/Latticeindices.jl:194 | Adds a shift vector to a site tuple |
| `Shifted_Lattice{D,Dim}` | struct | src/LatticeMatrices.jl:29 | A field plus a shift. Constructor at :288 → `Shifted_Lattice_construct` (:870 for nw>0, :851 for nw=0) |
| `shift_L` | function | src/LatticeMatrices.jl:898 | Public shift helper. A `ScaledIdentityLattice` method is at src/LinearAlgebras/scaled_identity.jl:31 |
| `release!` / `with_shifted_lattice` | function | src/LatticeMatrices.jl:136 / :163 | Return the scratch storage borrowed by a materialized long shift |
| `_materialize_direct_shift` | function | src/LatticeMatrices.jl:694 | Shift with \|s\|>nw: pack, `_alltoallv!`, unpack (plan at :499) |
| `_materialize_periodic_shift` | function | src/LatticeMatrices.jl:833 | nw=0 periodic shift. Repeated one-step shifts on the host via MPI when there are several ranks (:812); used by the Operators |
| `_LazyShifted_Lattice` | struct | src/LatticeMatrices.jl:47 | Internal nw=0 lazy shift used by src/LinearAlgebras/mul_nowing.jl:102 onward |
| `Adjoint_Lattice` | struct | src/LatticeMatrices.jl:63 | Lazy `A'` |
| `global_site_coordinates` / `global_site_id` | function | src/LatticeMatrices.jl:312 / :335 | Local → global coordinates, and the global site id that seeds the random streams |
| `_parallel_for_mutating!` | function | src/LatticeMatrices_core.jl:319 | **Standard kernel launcher.** Marks the halo dirty, then `JACC.parallel_for(count, bound_kernel)`. Public alias `parallel_for_mutating!` at :341 |
| `JACC.parallel_for(kernel, C::LatticeMatrix, ...)` | method | src/LatticeMatrices.jl:1013 | Convenience overloads (8 methods, :1013-1115). They append `Val(NC1),Val(NC2),Val(nw),indexer` to the kernel arguments. The `parallel_reduce` versions also call `_allreduce_sum` |
| `LinearAlgebra.mul!` (C = A B) | method | src/LinearAlgebras/mul.jl:232 | Generic product. Kernel `kernel_Dmatrix_mul!` at :244, with an NC=3 specialization at :288. About 120 `mul!` methods in src: 43 in mul.jl, others in mul_nowing.jl, staggered.jl, scaled_identity.jl, linearalgebra_D.jl:1850, Operators/* |
| `mul!` with α,β | method | src/LinearAlgebras/mul.jl:426 | C = αAB + βC |
| `mul!` (C = A·shift(B)) / `mul_AshiftB!` | method / function | src/LinearAlgebras/mul.jl:758 / :776 | Pattern for shifted products. Kernel at :814 |
| `mul_shiftAshiftB!`, `mul_A_shiftBdag!` | function | src/LinearAlgebras/mul.jl:829, :2021 | Exported shifted-product helpers (2 methods each) |
| `substitute!` | function | src/LinearAlgebras/linearalgebra_D.jl:1730 | Copy C = A (5 methods there, also in mul_nowing.jl:261, scaled_identity.jl:59) |
| `axpby!` | method | src/LinearAlgebras/linearalgebra_D.jl:2 | Y = aX + bY |
| `add_matrix!` | function | src/LinearAlgebras/linearalgebra_D.jl:2902 | C += αA (4 methods: plain, shifted, adjoint, shifted adjoint) |
| `tr` / `dot` | method | src/LinearAlgebras/linearalgebra_D.jl:2235 / :3528 | Global reductions (JACC reduce + `_allreduce_sum`) |
| `expt!` | function | src/LinearAlgebras/linearalgebra_D.jl:714 | Matrix exponential at each site (3 methods there, also :147, :1459, and src/TA/TA.jl:417) |
| `clear_matrix!`, `makeidentity_matrix!`, `normalize_matrix!` | function | src/LinearAlgebras/linearalgebra_D.jl:2796, :2859, :2359 | Set to zero, set to identity, re-unitarize |
| `traceless_antihermitian_add!` / `traceless_antihermitian_product_add!` | function | src/LinearAlgebras/linearalgebra_D.jl:3173 / :3225 | C += factor × TA(A) and TA(A B); used for forces and projections (2 and 4 methods) |
| `traceless_antihermitian!` | function | src/TA/TA.jl:269 | Projection onto traceless anti-Hermitian matrices (4 methods, also :29, :148, :287) |
| `cg!` | function | src/LinearAlgebras/cg.jl:73 | Conjugate-gradient solver |
| `RNGStreamKey` | struct | src/utilities/randomgenerator.jl:98 | Stream tag: (seed, sweep, direction, color, subgroup) |
| `site_rng` | function | src/utilities/randomgenerator.jl:158 | Builds the per-site generator state from the key and global site id. 5 methods: PCG32 :158, Xoshiro :169, Philox :184, plus 2 convenience methods |
| `rand_u32`, `rand_uniform`, `rand_normal_pair`, `rand_bounded` | function | src/utilities/randomgenerator.jl:219, :341, :380, :406 | Draws inside a kernel. Each returns `(new_rng, value)` |
| `randomize_matrix!` | function | src/LinearAlgebras/linearalgebra_D.jl:2580 | Uniform [-0.5,0.5) fill, same result for any MPI decomposition. Kernel at :2689; keyword-argument method at :2605 |
| `randomize_gaussian_matrix!` | function | src/LinearAlgebras/linearalgebra_D.jl:2630 | Gaussian fill. Kernel at :2737 |
| `LatticeScratchPool` / `get_block` | struct / method | src/LatticeScratchPool.jl:12 / :133 | Scratch arrays (`unused!` at :162) |
| `gather_matrix` / `gather_and_bcast_matrix` | function | src/LatticeMatrices_core.jl:1226 / :1298 | Collect the global array on the root rank (and broadcast). This is the only I/O-like code; no file I/O was found in src/ |
| `allsum` | function | src/LatticeMatrices_core.jl:665 | Sum over the core region, reduced to rank 0 only |
| `set_global_component!` | function | src/measurements/global_source.jl:15 | Writes one global component (point source) |

## Dirac operators and smearing kernels (`src/Operators/`, 4D only)

The v1 stencils of every Dirac operator are here, not in LatticeDiracOperators, which wraps them.

The module includes `Operators/Operators.jl`, `Operators/DiracOperators.jl`, and `Operators/DiracOperators_5D.jl` at src/LatticeMatrices.jl:1210–1212; `DiracOperators.jl` includes the files of each operator and smearing (src/Operators/DiracOperators.jl:15–24), and each file exports its own names. A new stencil file goes in this include list.

| Name | Kind | Location | What it is |
|---|---|---|---|
| `OperatorOnKernel` | abstract type | src/Operators/Operators.jl:1 | Supertype of the kernel operators below |
| `Oneγ{pm,μ}` | struct | src/Operators/Operators.jl:15 | Spin projector (1 ± γμ) used by the Wilson stencil |
| `WilsonDiracOperator4D` | struct | src/Operators/WilsonDiracOperator.jl:2 | Wilson operator (links and κ); constructor at :24 |
| `mul!` (Wilson D) | method | src/Operators/WilsonDiracOperator.jl:60 | Launches `kernel_WilsonDiracOperator4D!` (:80, NC = 3 specialization at :413); adjoint `mul!` at :425 |
| `WilsonDiracOperator4D_Donly` | struct | src/Operators/WilsonDiracOperator.jl:522 | Hopping part only; `mul!` at :535 |
| `WilsonDiracCloverOperator4D` | struct | src/Operators/WilsonDiracCloverOperator.jl:434 | Wilson–clover; constructor at :447; clover field strength `CloverFieldStrength4D` at :28 |
| `wilson_clover_link_pullback!` | function | src/Operators/WilsonCloverPullback.jl:426 | Clover force (2 methods, also :475) |
| `StaggeredDiracOperator4D` | struct | src/Operators/StaggeredDiracOperator.jl:18 | Staggered; constructor at :46 |
| `HISQDiracOperator4D` / `HISQDiracCache4D` | struct | src/Operators/HISQDiracOperator.jl:72 / src/Operators/HISQFullSmearing.jl:504 | HISQ operator and the cache that LatticeDiracOperators wraps |
| `hisq_link_pullback!` | function | src/Operators/HISQPullback.jl:1198 | HISQ force (2 methods, also :1280) |
| `D5DW_MobiusDomainwallOperator5D` | struct | src/Operators/DiracOperators_5D.jl:8 | 5D Möbius domain wall; generalized version at :62 |
| `DiracOp` / `DdagDOp` / `solve!` | struct / struct / method | src/Operators/DiracOperators.jl:30 / :98 / :146 | Generic operator from `apply`/`apply_dag` callbacks and a CG on D†D |
| Smearing caches | struct | src/Operators/StoutSmearing.jl:30, src/Operators/ProjectedSmearing.jl:437 (APE), :704 (HYP), src/Operators/NHYPSmearing.jl:74, src/Operators/HEXSmearing.jl:43 | Kernels of the smearings that Gaugefields exposes |

## Where to make changes
- **New site-local operation or kernel**:
  - Write `@inline kernel!(i, C, A, ..., ::Val{NC1}, ::Val{NC2}, ::Val{nw}, dindexer)` that starts with `indices = delinearize(dindexer, i, nw)` (src/Latticeindices.jl:127).
  - Launch it with `_parallel_for_mutating!(C, prod(C.PN), kernel!, C.A, ...)` (src/LatticeMatrices_core.jl:319), so the halo of C is marked dirty.
  - Model it on `mul!`/`kernel_Dmatrix_mul!` (src/LinearAlgebras/mul.jl:232/244) or `axpby!` (src/LinearAlgebras/linearalgebra_D.jl:2).
  - For neighbour reads, first call `_ensure_halo_for_shift!` (src/LatticeMatrices_core.jl:728), then use `shiftindices` (src/Latticeindices.jl:194). Pattern: `mul_AshiftB!` at mul.jl:776/814.
  - For a global sum, use `JACC.parallel_reduce` followed by `_allreduce_sum`, as in `tr` (linearalgebra_D.jl:2235).
  - Put the code in src/LinearAlgebras/ and add an `include` in linearalgebra.jl or LatticeMatrices.jl, plus an `export`.
- **Number of dimensions**:
  - D comes from the runtime argument `dim` of the constructor (src/LatticeMatrices_core.jl:438). Core, halo, shift and random code is written for any D.
  - Check `delinearize`: hand-written for D≤6 (src/Latticeindices.jl:67-116), with a generic recursive version at :127.
  - The 6-dim-array slab views are 4D-only (src/LatticeMatrices_core.jl:762, :792); they are used only by the full-buffer path.
  - `Base.display` is 4D-only (src/LatticeMatrices_core.jl:637).
  - `TALattice` `expt!` and `traceless_antihermitian!` are 4D-only (src/TA/TA.jl:417, :287).
  - All of src/Operators/ is 4D (`*4D` types).
- **Halo width or exchange pattern**:
  - The width is the `nw` keyword and type parameter (src/LatticeMatrices_core.jl:423/438). It is checked against `PN` at :466 and sets the buffer shapes at :500-527.
  - The slab ranges come from `_exchange_slab_matrix` (:809) and `_faceMatrix`/`_ghostMatrix` (:747/:780).
  - Whether a shift reads the halo or is materialized is decided by the threshold in `Shifted_Lattice_construct` (src/LatticeMatrices.jl:870, `|s|<=nw`).
  - The exchange order (dimension by dimension) is in `set_halo!` (:700).
  - The per-dimension protocol, tags and boundary phases are in `exchange_dim!` (:1118), `exchange_dim_local!` (:852), and `_post_/_finish_packed_halo_exchange!` (:887/:929).
  - The AD reverse halo pass must be kept consistent (ext/AD/AD.jl:4751-4890).
- **New GPU backend path**:
  - Add `ext/LatticeMatrices<Backend>Ext.jl` and register it in Project.toml `[weakdeps]`/`[extensions]`.
  - Implement `_backend_device_count(::Val{:name})` and `_select_backend_device!` (fallbacks at src/device_selection.jl:63/:69).
  - Implement as needed: `_mpi_device_buffer_supported`, `_mpi_device_kind`, `_uses_full_halo_buffers`, `_prepare_mpi_host_buffer` (defaults at src/LatticeMatrices_core.jl:46, :62-69), and `_center_component_threads` (src/LinearAlgebras/scaled_identity.jl:70).
  - For device-aware MPI, add a `<Backend>MPIExt` defining `_mpi_device_aware_available`. Model: ext/LatticeMatricesCUDAExt.jl and ext/LatticeMatricesCUDAMPIExt.jl.
  - Kernels need no change; JACC does the dispatch.
- **New random-number stream**:
  - A new independent stream needs no code change: use a new `RNGStreamKey` (src/utilities/randomgenerator.jl:98), for example a different sweep, direction, color or subgroup.
  - A new generator algorithm: add a `SiteRNGAlgorithm` selector, a `SiteRNG` state struct, a `site_rng` method, and `rand_u32`/`rand_u64` methods in randomgenerator.jl. Add them to the export list at :416.
  - A new fill distribution: copy `kernel_randomize_global_sites!` and `_global_site_rng` (src/LinearAlgebras/linearalgebra_D.jl:2689, :2674).

## Notes
- **Misleading names**:
  - `kernel_tr_4D` (src/LinearAlgebras/linearalgebra_D.jl:2253, :2271), `kernel_clear_4D!` (:2823) and `kernel_makeidentity_4D!` (used at :2860) work for any D despite the "4D".
  - `allsum` (src/LatticeMatrices_core.jl:665) reduces to rank 0 only (`_reduce_sum`), not to all ranks.
- **Two implementations of long shifts**:
  - Public `Shifted_Lattice` uses an alltoallv plan (src/LatticeMatrices.jl:694).
  - The Operators call `_materialize_periodic_shift` (:833), which shifts one step at a time on the host (:812). Users: src/Operators/WilsonDiracOperator.jl:794, src/Operators/StaggeredDiracOperator.jl:348.
- **Halo staleness tracking**: halos are synchronized lazily through `HaloEpoch`. Writes made directly to `lattice.A` need a manual `mark_halo_dirty!` (src/LatticeMatrices_core.jl:277-287 docstring). `set_halo!` is collective, so every rank must follow the same control flow.
- **Unreachable branches in `exchange_dim!`**: the `rankM == me` and `rankP == me` branches (src/LatticeMatrices_core.jl:1162-1184; also :1075-1091 in the full-buffer path) can never run. On a periodic grid both neighbours are this rank (handled earlier at :1125) or neither is. They also look wrong: :1163 copies `fminus` into `gminus`, and :1177 uses the phase where the other code uses its inverse.
- **Boundary phases** are applied only during halo filling and shifts. A zero phase means an absorbing wall (src/LatticeMatrices_core.jl:1-6). The process grid is always periodic (:477).
- **Legacy code kept alongside**:
  - Commented-out old `Shifted_Lattice` (src/LatticeMatrices.jl:907-973).
  - Commented-out `HaloComm.jl` and 1D includes (:16-18), and `AD/AD.jl` (:95).
  - Commented-out `linearalgebra_1D..4D.jl` includes; those files do not exist (src/LinearAlgebras/linearalgebra.jl:17-22).
  - Commented-out old `randomize_matrix!` that calls a nonexistent `pcgrand` (src/LinearAlgebras/linearalgebra_D.jl:2539-2556).
  - The old `pcg32_step`/`mix_seed` are kept for compatibility (src/utilities/randomgenerator.jl:7, :35).
- **Code that is never loaded**: `ext/AD/misc.jl` (5239 lines) is not included anywhere, yet it defines `fold_halo_to_core_grad!` again (ext/AD/misc.jl:4947). The live version is ext/AD/AD.jl:4751.
- **Halo/AD function stubs**: `zero_halo_region!`, `zero_halo_dim!` and `fold_halo_dim_to_core_grad!` are empty in src (src/LatticeMatrices.jl:260-266). Their methods exist only when Enzyme is loaded (ext/AD/AD.jl:4765, :4881, :4890).
- **Include nesting**: `LatticeScratchPool.jl` is included from src/LatticeMatrices_core.jl:24, not from the module file. `mul.jl` is included from src/LinearAlgebras/linearalgebra_D.jl:44.
- **Environment variables**: `LATTICEMATRICES_MPI_TRANSPORT` and the older `GENERALIZED_CUDAAWARE_MPI` choose the MPI transport (src/LatticeMatrices_core.jl:82).
- **Exported names that may surprise users**:
  - Misspelled `Wiltinger!` is kept as a deprecated alias (src/LatticeMatrices.jl:1177).
  - The package defines and exports its own `diff`/`nodiff` (:1200-1202). That `diff` is a different function from `Base.diff` and may clash with it in user code.
- **Inconsistent `JACC.parallel_reduce` calls**: the wrappers pass the reduction operator in two ways, positionally at src/LatticeMatrices.jl:1020 and as `op=+` at :1072.
- **`TALattice` is only partly general**: `TALattice` (src/TA/TA.jl:1) accepts any D, but its `traceless_antihermitian!` and `expt!` methods exist only for D=4.
