# Checks that HMC with two flavors of Wilson or Wilson–clover fermions,
# optionally on stout-smeared links, is correct on a small lattice, before
# any production run. Each check prints PASS or FAIL; exit code 1 on any FAIL.
# Run check_fermion.jl in juliaqcd-measure first: it tests the operator D
# itself against the reference.
#
#   julia --project=ENV check_hmc_wilson.jl colors=3 lattice=4,4,4,4 kappa=0.12 csw=0
#   julia --project=ENV check_hmc_wilson.jl colors=3 lattice=4,4,4,4 kappa=0.12 csw=1.5 rho=0.1 smear_iterations=2
#
# The checks choose their own β; kappa, csw, rho, and smear_iterations select
# the code path to test (use the production values). Optional: ntraj=80,
# therm=20, seed=1234, workdir=<tmp dir>, mutation=<name> (deliberately
# broken variants for selftest_hmc_wilson.jl). Four dimensions only.
#
# Checks:
#  1. heat bath: S_F right after the refresh equals |ξ|², and ξ has unit
#     variance per complex component
#  2. S_F equals φ†(D†D)⁻¹φ computed with FermionReference on the same links
#     (on the stout links when rho > 0)
#  3. (rho > 0) the stout links equal the reference, V ← exp(ρ Z) V with
#     Z = −TA(V Σ staples), and rho = 0 leaves the links unchanged
#  4. κ = 0: the fermion force vanishes (D = 1)
#  5. reversibility: +τ then −τ returns U and H, with the fermion term, to
#     the solver tolerance
#  6. rms ΔH ∝ δτ² for the Sexton–Weingarten integrator: the fermion force
#     (and its stout pullback) is the gradient of S_F
#  7. a short chain: <exp(−ΔH)> = 1, and the links stay in SU(N)

import JACC
JACC.@init_backend
using Gaugefields
using LinearAlgebra
using Printf
include(joinpath(@__DIR__, "common.jl"))
include(joinpath(@__DIR__, "stats.jl"))
include(joinpath(@__DIR__, "fermion_hmc.jl"))
include(joinpath(@__DIR__, "..", "..", "juliaqcd-extend", "scripts", "GaugeGroups.jl"))
using .GaugeGroups
include(joinpath(@__DIR__, "..", "..", "juliaqcd-measure", "scripts", "LatticeReference.jl"))
import .LatticeReference as LR
include(joinpath(@__DIR__, "..", "..", "juliaqcd-measure", "scripts", "FermionReference.jl"))
import .FermionReference as FR

const RESULTS = Tuple{String,Bool,String}[]

# Deliberately broken variants, used only by selftest_hmc_wilson.jl:
#   force_kappa   the MD force uses κ·1.05 while the action uses κ
#   force_rho     the MD force uses ρ·1.3 while the action uses ρ (needs rho > 0)
#   phi_D         the heat bath sets φ = D ξ instead of D† ξ
const MUTATION = Ref("none")

function record(name, ok, detail)
    push!(RESULTS, (name, ok, detail))
    println("  ", ok ? "PASS" : "FAIL", "  ", rpad(name, 52), detail)
    flush(stdout)
end

function setup(U, o; kappa=o.kappa)
    fk = MUTATION[] == "force_kappa" ? 1.05kappa : kappa
    fr = MUTATION[] == "force_rho" ? 1.3o.rho : o.rho
    fermion_setup(U; kappa, o.csw, o.rho, o.smear_iterations, force_kappa=fk, force_rho=fr)
end

function refresh!(f, U, seed, k)
    xi2 = refresh_phi!(f, U, seed, k)
    if MUTATION[] == "phi_D"
        V = fermion_links!(f, U)
        mul!(f.phi, f.fa.diracoperator(V), f.noise)
    end
    return xi2
end

new_field(lattice, colors, start, seed) = gauge_configuration(lattice; colors, start, seed, process_grid=(1, 1, 1, 1))

"Plain-array CG for (D†D) z = b with the reference operator."
function reference_DdagD_solve(V, b; kappa, csw, tol=1e-13)
    F = csw != 0 ? FR.clover_fields(V) : nothing
    A(v) = FR.apply_dirac(V, FR.apply_dirac(V, v; κ=kappa, cSW=csw, F); κ=kappa, cSW=csw, F, dagger=true)
    z = zero(b); r = copy(b); p = copy(r); rr = real(dot(r, r)); target = tol^2 * rr
    for _ in 1:20000
        Ap = A(p); α = rr / real(dot(p, Ap))
        z .+= α .* p; r .-= α .* Ap
        rrn = real(dot(r, r)); rrn < target && break
        p .= r .+ (rrn / rr) .* p; rr = rrn
    end
    return z
end

function reference_stout(U, rho, n)
    V = U
    for _ in 1:n
        V = LR.apply(LR.combine((rho,), (LR.flow_force(V),)), V)
    end
    return V
end

maxdiff(a, b) = maximum(maximum(abs, a[μ][I] - b[μ][I]) for μ in eachindex(a) for I in eachindex(a[μ]))

function main(args)
    a = parse_args(args)
    check_keys(a, ("colors", "csw", "kappa", "lattice", "mutation", "ntraj", "rho", "seed", "smear_iterations", "therm", "workdir"))
    for key in ("kappa", "csw")
        haskey(a, key) || error("$key=... is required (use the production value; csw=0 for plain Wilson)")
    end
    colors = getarg(a, "colors", 3)
    lattice = getarg(a, "lattice", (4, 4, 4, 4))
    length(lattice) == 4 || error("four dimensions only")
    o = (kappa=getarg(a, "kappa", 0.12), csw=getarg(a, "csw", 0.0),
        rho=getarg(a, "rho", 0.0), smear_iterations=getarg(a, "smear_iterations", 1))
    ntraj = getarg(a, "ntraj", 80)
    therm = getarg(a, "therm", 20)
    seed = getarg(a, "seed", 1234)
    workdir = mkpath(getarg(a, "workdir", mktempdir()))
    MUTATION[] = getarg(a, "mutation", "none")
    MUTATION[] == "none" || println("!! mutation = ", MUTATION[], " (deliberately broken)")
    N = colors
    beta = 0.63 * N^2
    V = prod(lattice)
    println("== check_hmc_wilson: SU($N), lattice ", join(lattice, "x"), ", β = ", beta,
        ", κ = ", o.kappa, ", c_SW = ", o.csw, o.rho > 0 ? ", stout ρ = $(o.rho) × $(o.smear_iterations)" : ", no smearing")

    U0 = new_field(lattice, N, :hot, seed)
    # Bring the hot field closer to β with a few pure-gauge trajectories.
    let md = md_driver(U0, wilson_action(U0, beta); steps=20, trajectory_length=1.0, integrator=QPQ()),
        p = gauge_momenta(U0), old = copy_configuration(U0)
        for k in 1:10
            hmc_trajectory!(U0, p, old, md, seed, k)
        end
    end
    f = setup(U0, o)

    # 1. heat bath
    xi2 = refresh!(f, U0, seed, 1)
    S = fermion_action_value(f, U0)
    ncomp = 4N * V
    record("S_F after the heat bath = |ξ|²", abs(S - xi2) < 1e-8 * xi2, @sprintf("S_F = %.10g, |ξ|² = %.10g", S, xi2))
    record("|ξ|² / (4 N V) = 1", abs(xi2 / ncomp - 1) < 5 / sqrt(ncomp), @sprintf("%.4f (±%.4f)", xi2 / ncomp, 1 / sqrt(ncomp)))

    # 2. S_F against the reference
    Vlinks = LR.from_host(host_links(fermion_links!(f, U0), joinpath(workdir, "V.jld2")))
    phi = fermion_array(f.phi)
    z = reference_DdagD_solve(Vlinks, phi; o.kappa, o.csw)
    Sref = real(dot(phi, z))
    record("S_F = φ†(D†D)⁻¹φ of the reference", abs(S - Sref) < 1e-8 * abs(Sref), @sprintf("S_F = %.10g, reference %.10g", S, Sref))

    # 3. stout links
    if o.rho > 0
        thin = LR.from_host(host_links(U0, joinpath(workdir, "U.jld2")))
        d = maxdiff(Vlinks, reference_stout(thin, o.rho, o.smear_iterations))
        record("stout links = reference", d < 1e-12, @sprintf("max difference %.1e", d))
        f0 = fermion_setup(U0; o.kappa, o.csw, rho=1e-300, o.smear_iterations)
        d0 = maxdiff(LR.from_host(host_links(fermion_links!(f0, U0), joinpath(workdir, "V0.jld2"))), thin)
        record("stout with ρ → 0 leaves the links", d0 < 1e-14, @sprintf("max difference %.1e", d0))
    end

    # 4. κ = 0
    fz = fermion_setup(U0; kappa=0.0, o.csw, o.rho, o.smear_iterations)
    refresh_phi!(fz, U0, seed, 1)
    ws = Gaugefields.md_action_workspace(fz.provider, U0)
    F = initialize_TA_Gaugefields(U0)
    Gaugefields.md_force!(F, fz.provider, U0, ws)
    fmax = maximum(maximum(abs, LM.gather_and_bcast_matrix(F[μ].a)) for μ in 1:4)
    record("κ = 0: fermion force = 0", fmax < 1e-12, @sprintf("max |F| = %.1e", fmax))

    # 5. reversibility (φ fixed)
    md_f = make_fermion_md(U0, beta, f; steps=10)
    md_b = make_fermion_md(U0, beta, f; steps=10, tau=-1.0)
    U = copy_configuration(U0)
    p = gauge_momenta(U)
    gaussian_momenta!(p; seed=7, sweep=0)
    l0 = host_links(U, joinpath(workdir, "r0.jld2"))
    rf = md_trajectory!(U, p, md_f)
    rb = md_trajectory!(U, p, md_b)
    dU = maximum(maximum(abs, x - y) for (x, y) in zip(l0, host_links(U, joinpath(workdir, "r1.jld2"))))
    dHs = abs(rf.delta_hamiltonian + rb.delta_hamiltonian)
    # With a solver inside the MD, reversibility holds to the solver
    # tolerance (residual ≈ √eps_CG = 1e-7), not to rounding; a non-symmetric
    # integrator breaks it at O(δτ) ≈ 1e-2.
    record("reversibility (to the solver tolerance)", dU < 1e-7 && dHs < 1e-8 * abs(rf.initial_hamiltonian),
        @sprintf("max|ΔU| = %.1e, |ΔH(+τ) + ΔH(-τ)| = %.1e", dU, dHs))

    # 6. ΔH scaling
    stepslist = (4, 8, 16, 32)
    rms = Float64[]
    for s in stepslist
        md = make_fermion_md(U0, beta, f; steps=s)
        acc = 0.0
        for m in 1:4
            U = copy_configuration(U0)
            gaussian_momenta!(p; seed=7, sweep=m)
            acc += md_trajectory!(U, p, md).delta_hamiltonian^2
        end
        push!(rms, sqrt(acc / 4))
    end
    x = log.(1.0 ./ collect(stepslist))[end-2:end]
    y = log.(rms)[end-2:end]
    slope = sum((x .- sum(x) / 3) .* (y .- sum(y) / 3)) / sum(abs2, x .- sum(x) / 3)
    record("rms ΔH ∝ δτ² with the fermion force", 1.8 < slope < 2.2,
        @sprintf("slope %.3f from rms ΔH = %s", slope, join((@sprintf("%.2e", v) for v in rms), ", ")))

    # 7. short chain
    U = copy_configuration(U0)
    md = make_fermion_md(U, beta, f; steps=10)
    old = copy_configuration(U)
    emdH = Float64[]
    nacc = 0
    t = @elapsed for k in 1:ntraj
        xi = refresh!(f, U, seed, 100 + k)
        r = hmc_trajectory!(U, p, old, md, seed, 100 + k)
        if k > therm
            push!(emdH, exp(-r.dH)); nacc += r.accepted
        end
    end
    e = gamma_method(emdH)
    record("<exp(-ΔH)> = 1", abs(e.mean - 1) < 4e.error,
        @sprintf("%.4f ± %.4f, acceptance %.2f, %.2f s per trajectory", e.mean, e.error, nacc / (ntraj - therm), t / ntraj))
    links = host_links(U, joinpath(workdir, "chain.jld2"))
    worst = 0.0
    for l in links, idx in CartesianIndices(size(l)[3:end])
        r = ingroup_residual(SU(N), l[:, :, idx])
        worst = max(worst, r.unitarity, r.determinant)
    end
    record("links in SU($N) after $ntraj trajectories", worst < 1e-10, @sprintf("max residual %.1e", worst))

    ok = all(r -> r[2], RESULTS)
    println(ok ? "ALL PASS" : "SOME CHECKS FAILED")
    return ok
end

exit(main(ARGS) ? 0 : 1)
