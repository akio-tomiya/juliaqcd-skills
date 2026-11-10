# Wilsonloop.jl 0.1.5: code map

Part of `../code-map.md`; read its first part (versions, how to cite a line) before this one. Paths are relative to the package root; `file:N` is line N in version 0.1.5.

## File map
- `src/Wilsonloop.jl`: the whole package (869 lines). It contains the link and line types, the symbolic loop constructors, staples and derivatives, LaTeX printing, and the precomputed lookup tables. The only dependencies are LaTeXStrings and LinearAlgebra.

## Main types and functions
| Name | Kind | Location | What it is |
|---|---|---|---|
| export list | - | src/Wilsonloop.jl:2 | Exported names on lines 2-20. `make_rect`, `make_cloverloops`, `make_polyakov`, `make_loopforactions` and `check_rectset` are not exported |
| `Gaugelink{Dim}` | abstract type | src/Wilsonloop.jl:26 | Supertype of links |
| `GLink{Dim}` | struct | src/Wilsonloop.jl:28 | `direction::Int8`, `position::NTuple{Dim}`, `isdag`. `adjoint` flips `isdag` (line 47) |
| `Adjoint_GLink{Dim}` | struct | src/Wilsonloop.jl:38 | Effectively unused, because `GLink'` returns a `GLink` |
| `get_direction` / `get_position` / `isdag` | functions | src/Wilsonloop.jl:53 / 57 (also 147 for `DwDU`) / 61 | Link accessors |
| `Wilsonline{Dim}` | mutable struct | src/Wilsonloop.jl:71 | A vector of `GLink`s. The main constructor is `Wilsonline([(μ, ±n), ...]; Dim=4)` (line 77). It expands each segment through `make_links` (line 507) and tracks the position from the origin |
| `adjoint(::Wilsonline)` | method (also for vectors, line 182) | src/Wilsonloop.jl:173 | Reverses the line and daggers each link |
| `DwDU{Dim}` | struct | src/Wilsonloop.jl:130 | Derivative term: left links ⊗ right links, with the insert index and origin. Accessors `get_leftlinks` (139) and `get_rightlinks` (143) |
| `derive_U` | function | src/Wilsonloop.jl:350 | ∂W/∂U_μ: one `DwDU` per un-daggered μ link, with the neighbouring links repositioned relative to it |
| `derive_Udag` | function | src/Wilsonloop.jl:399 | The same for daggered μ links, but the links are not repositioned (`position` on line 411 is unused) |
| `make_staple` | function | src/Wilsonloop.jl:277 | Staples of a loop w.r.t. μ: right links followed by left links, for each `derive_U` term |
| `make_Cμ` | function | src/Wilsonloop.jl:290 | Adjoints of the staples of `w` and `w'` |
| `make_staple_and_loop` | function | src/Wilsonloop.jl:303 | Each staple's adjoint times U_μ†. The position `(0,0,0,0)` is hard-coded on line 308 |
| `make_plaq` | function (2 methods) | src/Wilsonloop.jl:523 (also :527) | `make_plaq(μ,ν; Dim)` gives one plaquette. `make_plaq(; Dim)` gives all μ<ν |
| `make_rect` | function | src/Wilsonloop.jl:558 | 1×2 and 2×1 rectangles for every μ<ν |
| `make_cloverloops` | function | src/Wilsonloop.jl:597 | The four clover leaves. It does not pass `Dim`, so they are always `Wilsonline{4}` |
| `make_polyakov` / `make_polyakov_xyz` | functions | src/Wilsonloop.jl:611 / 618 | A straight line of length Lμ. The `_xyz` version hard-codes μ = 1:3 |
| `make_loopforactions` | function | src/Wilsonloop.jl:628 | Same name switch as `make_loops_fromname`, but for a list of names |
| `make_loops_fromname` | function | src/Wilsonloop.jl:659 | Known names: `"plaquette"`, `"rectangular"`, `"chair"`, `"polyakov_t"`, `"polyakov_z"`, `"polyakov_y"`, `"polyakov_x"`. The Polyakov names need `L`. `polyakov_z` asserts Dim>3 and `polyakov_y` asserts Dim>2. Other names call `error` |
| `make_chair` | function | src/Wilsonloop.jl:695 | Six-link chair loops. Asserts Dim==4 (line 696) |
| `make_plaq_staple` | function | src/Wilsonloop.jl:741 | All plaquette staples for direction μ |
| `construct_plaq/_rect/_staple_prime/_staple` | functions | src/Wilsonloop.jl:543, 579, 762, 772 | Lookup tables built for Dim = 1:4 only |
| `loops_staple_prime`, `loops_staple`, `loops_plaq`, `loops_rect` | const | src/Wilsonloop.jl:783-786 | Precomputed tables keyed by `(Dim, μ[, ν[, k]])`. `loops_staple` is not exported |
| `check_plaqset` | function (2 methods) | src/Wilsonloop.jl:788 (also :810) | Tests whether a loop (or every loop in a vector) is a plaquette, using `loops_plaq` |
| `check_rectset` | function (2 methods) | src/Wilsonloop.jl:822 (also :854) | The same for rectangles; also returns `(μ,ν)` |

## Where to make changes
- **A new named loop shape:**
  1. Add a `make_X(; Dim=4)` returning `Wilsonline{Dim}[]` next to `make_rect` (line 558) or `make_chair` (line 695). Build each loop with `Wilsonline([(μ,±n),...], Dim=Dim)`.
  2. Add an `elseif name == "X"` branch to both name switches: `make_loops_fromname` (lines 664-690) and `make_loopforactions` (lines 632-654).
  3. Export the function in lines 2-20 if needed.
  4. Without editing the package, a user can instead pass a hand-built `Vector{Wilsonline{Dim}}` to the consumer. QCDMeasurements does this for clover and rect at topological_charge.jl:420-478.
- **Loops in another dimension.** Always pass `Dim=` to `Wilsonline`, since it defaults to 4 (line 77). Then fix the places that ignore `Dim`:
  - `make_cloverloops` (lines 599-602).
  - `make_staple_and_loop` (line 308, 4-tuple).
  - `make_chair` (line 696 assert; the plane sets on lines 699-702 are 4D).
  - `make_polyakov_xyz` (line 620).
  - The `construct_*` tables only cover Dim 1:4 (lines 545, 581, 764, 774). So for Dim>4, `check_plaqset` and `check_rectset` raise a KeyError (lines 795, 830).
  - `derive_U`, `make_staple`, `make_plaq` and `make_rect` are dimension-generic.

## Notes
- **`Dim` is silently 4 in many callers.** `Wilsonline(segments)` defaults to `Dim = 4` (line 77). Code that omits `Dim` gets `Wilsonline{4}` even in 2D: `make_cloverloops` (line 599), QCDMeasurements' `make_cloverloops_topo` and rect loops (topological_charge.jl:453-486), and `make_Wilson_loop` (Wilon_loop.jl:186). Pushing these into `Wilsonline{Dim}[]` with Dim≠4 should then fail to convert.
- **Asymmetry between `derive_U` and `derive_Udag`.** `derive_U` re-bases the right-link positions to the link after μ, and the left links to the origin (lines 361-386). `derive_Udag` copies the links unchanged (lines 414-424).
- **Rect orientations.** `make_rect` returns both orientations for each μ<ν, i.e. 2 loops per plane (lines 567-573). The `"rectangular"` action therefore counts both.
- **Printing side effect.** `Base.show(::IO, ::Wilsonline)` also prints `"\t"` to stdout rather than to `io` (line 272). `show` for `DwDU` does the same (line 502).
- **`check_plaqset` loop control.** It uses `continue` where `break` seems intended (lines 802-804). The result is still correct, only slower.
- **Duplicated name switch.** `make_loopforactions` and `make_loops_fromname` hold the same if-chain (lines 628-657 and 659-693), so they can drift apart.
