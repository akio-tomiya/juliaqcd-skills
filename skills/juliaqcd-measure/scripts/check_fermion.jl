# Checks that the Wilson and Wilson–clover operators of LatticeDiracOperators
# and the meson correlators of QCDMeasurements are correct on a small
# lattice, before measuring an ensemble. Each check prints PASS or FAIL;
# exit code 1 on any FAIL.
#
#   julia --project=ENV check_fermion.jl colors=3 lattice=4,4,4,6
#
# Optional: kappa=0.11, csw=1.5, seed=2024, workdir=<tmp dir>,
# mutation=<name> (deliberately broken variants for selftest_fermion.jl).
# Four dimensions only.
#
# The oracle is FermionReference.jl (plain arrays, Julia standard library):
# the same links and spinors go to JuliaQCD and to the reference. Checks:
#  1. the reference γ matrices satisfy the Clifford algebra and equal JuliaQCD's
#  2. spinor fields written to JuliaQCD come back unchanged, and the field
#     carries the boundary phases asked for (they are what the operator uses)
#  3. Wilson: D ψ and D† ψ equal the reference on a rough field
#  4. Wilson–clover: D ψ and D† ψ equal the reference; the clover term is not zero
#  5. γ5-hermiticity, γ5 D γ5 = D† (Wilson and clover)
#  6. gauge covariance, D[U^g] (g ψ) = g D[U] ψ (Wilson and clover)
#  7. free field: the eigenvalues of JuliaQCD's D equal the momentum-space formula
#  8. free field: QCDMeasurements' pion correlator equals the Fourier sum and is
#     symmetric under Δt → L₄ − Δt
#  9. rough field: all 16 local meson correlators at three momenta from
#     QCDMeasurements equal the reference propagators and contraction
#     (Wilson and clover, source away from the origin)
# 10. rough field: the pion correlator is positive

import JACC
JACC.@init_backend
using Gaugefields
using Printf
using Random
include(joinpath(@__DIR__, "measure_common.jl"))
include(joinpath(@__DIR__, "fermion_common.jl"))
include(joinpath(@__DIR__, "LatticeReference.jl"))
import .LatticeReference as LR
include(joinpath(@__DIR__, "FermionReference.jl"))
import .FermionReference as FR
include(joinpath(@__DIR__, "..", "..", "juliaqcd-extend", "scripts", "GaugeGroups.jl"))
using .GaugeGroups

const RESULTS = Tuple{String,Bool,String}[]

# Deliberately broken variants, used only by selftest_fermion.jl:
#   bc_periodic   JuliaQCD with periodic instead of antiperiodic time
#                 boundary conditions
#   csw_halved    clover coefficient c_SW/2 in JuliaQCD
#   dagger_is_D   D used where D† is meant
#   source_shift  meson source one site off in x
const MUTATION = Ref("none")

function record(name, ok, detail)
    push!(RESULTS, (name, ok, detail))
    println("  ", ok ? "PASS" : "FAIL", "  ", rpad(name, 52), detail)
    flush(stdout)
end

jq_bc(bc) = MUTATION[] == "bc_periodic" ? (bc[1], bc[2], bc[3], 1) : bc
jq_csw(cSW) = MUTATION[] == "csw_halved" ? cSW / 2 : cSW
jq_source(s) = MUTATION[] == "source_shift" ? (s[1] + 1, s[2], s[3], s[4]) : s

"JuliaQCD operator and work fields for the links in `U`."
function juliaqcd_dirac(U; κ, cSW=0.0, bc)
    x = fermion_field(U; bc=jq_bc(bc))
    y = similar(x)
    D = Dirac_operator(U, x, dirac_parameters(; κ, cSW=jq_csw(cSW), bc=jq_bc(bc)))
    return (D, x, y)
end

jq_apply(op, ψ; dagger=false) =
    apply_juliaqcd(op[1], op[2], op[3], ψ; dagger=dagger && MUTATION[] != "dagger_is_D")

"Rough field: each link exp(s X) with X a Gaussian element of the algebra."
function rough_field(rng, G, L; s=0.6)
    gens = generators(G)
    return [[exp(s * sum(randn(rng) * Ta for Ta in gens)) for _ in CartesianIndices(L)] for _ in 1:4]
end

relerr(a, b) = maximum(abs.(a .- b)) / maximum(abs.(b))

"Meson correlators from QCDMeasurements, or the error message if it throws."
function try_mesons(U; kw...)
    try
        m = meson_measurement(U; kw...)
        return get_value(measure(m, U)), solver_residual(m), ""
    catch e
        msg = first(split(sprint(showerror, e), '\n'))
        return nothing, NaN, "error: " * msg[1:min(end, 100)]
    end
end

"Apply γ5 (any 4×4 spin matrix) to every site of ψ[c, α, x...]."
spin_apply(Γ, ψ) = mapslices(m -> m * transpose(Γ), ψ; dims=(1, 2))

"Greatest distance from each target eigenvalue to its nearest unused computed one."
function match_spectra(computed, target)
    used = falses(length(computed))
    worst = 0.0
    for λ in target
        d, j = findmin(k -> used[k] ? Inf : abs(computed[k] - λ), eachindex(computed))
        used[j] = true
        worst = max(worst, d)
    end
    return worst
end

function main(args)
    a = parse_args(args)
    N = getarg(a, "colors", 3)
    L = getarg(a, "lattice", (4, 4, 4, 6))
    κ = getarg(a, "kappa", 0.11)
    cSW = getarg(a, "csw", 1.5)
    seed = getarg(a, "seed", 2024)
    workdir = mkpath(getarg(a, "workdir", mktempdir()))
    MUTATION[] = getarg(a, "mutation", "none")
    MUTATION[] == "none" || println("!! mutation = ", MUTATION[], " (deliberately broken)")
    length(L) == 4 || error("four dimensions only")
    bc = (1, 1, 1, -1)
    G = SU(N)
    rng = Xoshiro(seed)
    tol = 1e-10
    t_start = time()
    println("== check_fermion: SU($N), lattice ", join(L, "x"), ", κ = $κ, c_SW = $cSW, ",
        "boundary phases $bc")

    # 1. γ matrices
    γ = FR.GAMMA
    cliff = maximum(maximum(abs.(γ[μ] * γ[ν] + γ[ν] * γ[μ] - 2 * (μ == ν) * I)) for μ in 1:4, ν in 1:4)
    herm = maximum(maximum(abs.(g - g')) for g in (γ..., FR.GAMMA5))
    jq_γ = QCDMeasurements._euclidean_gamma_matrices()
    same = maximum(maximum(abs.(γ[μ] - jq_γ[μ])) for μ in 1:4)
    record("γ: Clifford algebra, Hermitian, equal to JuliaQCD", max(cliff, herm, same) <= 1e-14,
        @sprintf("Clifford %.1e, Hermitian %.1e, JuliaQCD %.1e", cliff, herm, same))

    # rough field in JuliaQCD and in the reference
    F = rough_field(rng, G, L)
    U = gauge_configuration(L; colors=N, start=:cold, process_grid=(1, 1, 1, 1))
    set_links!(U, LR.to_host(F), joinpath(workdir, "rough.jld2"))
    ψ = randn(rng, ComplexF64, N, 4, L...)
    wil = juliaqcd_dirac(U; κ, bc)
    clo = juliaqcd_dirac(U; κ, cSW, bc)

    # 2. round trip of a spinor field
    rt = maximum(abs.(get_fermion(set_fermion!(wil[2], ψ)) .- ψ))
    phases = Tuple(real.(wil[2].f.phases))
    record("spinor round trip and boundary phases", rt == 0 && phases == bc,
        @sprintf("max |Δψ| = %.1e, phases %s", rt, phases))

    # 3, 4. operators against the reference
    Fcl = FR.clover_fields(F)
    for (name, op, c) in (("Wilson", wil, 0.0), ("Wilson–clover", clo, cSW))
        e1 = relerr(jq_apply(op, ψ), FR.apply_dirac(F, ψ; κ, cSW=c, bc, F=Fcl))
        e2 = relerr(jq_apply(op, ψ; dagger=true), FR.apply_dirac(F, ψ; κ, cSW=c, bc, F=Fcl, dagger=true))
        extra = ""
        ok = max(e1, e2) <= tol
        if c != 0
            term = relerr(jq_apply(op, ψ), jq_apply(wil, ψ))
            extra = @sprintf(", clover term / D ψ = %.2f", term)
            ok &= term > 1e-3
        end
        record("$name: D ψ and D† ψ equal the reference", ok,
            @sprintf("relative difference %.1e, %.1e%s", e1, e2, extra))
    end

    # 5. γ5-hermiticity
    for (name, op) in (("Wilson", wil), ("Wilson–clover", clo))
        lhs = spin_apply(FR.GAMMA5, jq_apply(op, spin_apply(FR.GAMMA5, ψ)))
        e = relerr(lhs, jq_apply(op, ψ; dagger=true))
        record("$name: γ5 D γ5 = D†", e <= tol, @sprintf("relative difference %.1e", e))
    end

    # 6. gauge covariance
    g = [random_element(rng, G) for _ in CartesianIndices(L)]
    Ug = gauge_configuration(L; colors=N, start=:cold, process_grid=(1, 1, 1, 1))
    set_links!(Ug, LR.to_host(LR.gauge_transform(F, g)), joinpath(workdir, "gauge.jld2"))
    color_apply(ψ) = (out = similar(ψ); for x in CartesianIndices(L); out[:, :, x] = g[x] * ψ[:, :, x]; end; out)
    for (name, c) in (("Wilson", 0.0), ("Wilson–clover", cSW))
        opg = juliaqcd_dirac(Ug; κ, cSW=c, bc)
        op = c == 0 ? wil : clo
        e = relerr(jq_apply(opg, color_apply(ψ)), color_apply(jq_apply(op, ψ)))
        record("$name: gauge covariance", e <= tol, @sprintf("relative difference %.1e", e))
    end

    # 7. free spectrum on a 2x2x2x4 lattice
    Ls = (2, 2, 2, 4)
    U0s = gauge_configuration(Ls; colors=N, start=:cold, process_grid=(1, 1, 1, 1))
    op0s = juliaqcd_dirac(U0s; κ, bc)
    M = FR.dense_matrix(v -> jq_apply(op0s, v), (N, 4, Ls...))
    dev = match_spectra(eigvals(M), FR.free_spectrum(Ls, κ; bc, n=N))
    record("free field: spectrum of D (lattice 2x2x2x4)", dev <= 1e-10,
        @sprintf("%d eigenvalues, max distance %.1e", size(M, 1), dev))

    # 8. free pion correlator
    src = (2, 1, 3, 2)
    moms = [(0, 0, 0), (1, 0, 0), (0, 1, 1)]
    U0 = gauge_configuration(L; colors=N, start=:cold, process_grid=(1, 1, 1, 1))
    v0, res0, err0 = try_mesons(U0; κ, bc=jq_bc(bc), channels=["pseudoscalar"], momenta=moms, source=jq_source(src))
    Cf = FR.meson_correlator(FR.free_propagator(L, κ, src; bc, n=N), src, FR.GAMMA5, FR.GAMMA5; momenta=moms)
    T = L[4]
    sym = maximum(abs(Cf[1+Δ, 1] - Cf[1+T-Δ, 1]) for Δ in 1:T-1) / maximum(abs.(Cf))
    if v0 === nothing
        record("free field: pion correlator equals the Fourier sum", false, err0)
    else
        e = relerr(v0[:pseudoscalar], Cf)
        record("free field: pion correlator equals the Fourier sum", e <= 1e-9 && sym <= 1e-12,
            @sprintf("relative difference %.1e (JuliaQCD residual %.0e); C(Δt) − C(L₄−Δt): %.1e",
                e, res0, sym))
    end

    # 9, 10. meson correlators on the rough field
    for (name, c) in (("Wilson", 0.0), ("Wilson–clover", cSW))
        t0 = time()
        S, res = FR.point_propagator(F, src; κ, cSW=c, bc)
        jq, resj, err = try_mesons(U; κ, cSW=jq_csw(c), bc=jq_bc(bc), momenta=moms, source=jq_source(src))
        if jq === nothing
            record("$name: 16 channels × 3 momenta = reference", false, err)
            continue
        end
        worst = 0.0
        worst_name = ""
        for ch in standard_local_meson_channels()
            ref = FR.meson_correlator(S, src, ch.sink_matrix, ch.source_matrix;
                momenta=moms, coefficient=ch.coefficient)
            d = relerr(jq[ch.name], ref)
            d > worst && (worst = d; worst_name = String(ch.name))
        end
        record("$name: 16 channels × 3 momenta = reference", worst <= 1e-9,
            @sprintf("worst %s %.1e; residuals JuliaQCD %.0e, reference %.0e; %.0f s",
                worst_name, worst, resj, res, time() - t0))
        pp = real.(jq[:pseudoscalar][:, 1])
        record("$name: pion correlator positive", all(>(0), pp),
            @sprintf("min C(Δt) = %.2e", minimum(pp)))
    end

    ok = all(r -> r[2], RESULTS)
    println(@sprintf("%s (%.0f s)", ok ? "ALL PASS" : "SOME CHECKS FAILED", time() - t_start))
    return ok
end

exit(main(ARGS) ? 0 : 1)
