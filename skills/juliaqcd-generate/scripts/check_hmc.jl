# Checks that pure-gauge HMC is correct on a small lattice, before any
# production run. Each check prints PASS or FAIL; exit code 1 on any FAIL.
#
#   julia --project=ENV check_hmc.jl colors=3 lattice=4,4,4,4
#   julia --project=ENV check_hmc.jl colors=2 lattice=4,4,4
#
# Optional: ntraj=300 (per run), therm=50, seed=1234, workdir=<tmp dir>,
# mutation=<name> (deliberately broken variants for selftest_hmc.jl).
# About 2 minutes on one core and 1.5 GB of memory for 4^4 SU(3), most of
# it compilation. On a laptop, ask the user before running it.
#
# Checks:
#  1. reversibility: integrating +τ then -τ returns U and H
#  2. |ΔH| ∝ δτ² at fixed (U, P) for the second-order QPQ integrator; a force
#     that is not the exact gradient of the action breaks this
#  3. every link stays in SU(N) (unitarity, det = 1), checked with the
#     independent reference implementation in juliaqcd-extend
#  4. β = 0: <P> = 0
#  5. strong coupling: <P> = u(β), the one-link expectation value, computed
#     here by Haar Monte Carlo; corrections are O(u⁵)
#  6. weak coupling: 1 - <P> = (N² - 1)/(d β) from equipartition, to 10 %
#  7. <exp(-ΔH)> = 1 and acceptance in an intermediate-β run

import JACC
JACC.@init_backend
using Gaugefields
using LinearAlgebra
using Random
using Printf
include(joinpath(@__DIR__, "common.jl"))
include(joinpath(@__DIR__, "stats.jl"))
include(joinpath(@__DIR__, "..", "..", "juliaqcd-extend", "scripts", "GaugeGroups.jl"))
using .GaugeGroups
include(joinpath(@__DIR__, "known_values.jl"))

const RESULTS = Tuple{String,Bool,String}[]

# Deliberately broken variants, used only by selftest_hmc.jl to show that the
# checks can fail:
#   beta_twice     action built with coefficient β instead of β/2
#   first_order    a non-symmetric first-order integrator
#   sigma_only     momenta drawn with width √2 (Grid/Bridge++) while the driver
#                  keeps the Gaugefields kinetic term p²/2; this samples β/2
#                  and leaves <exp(-ΔH)> ≈ 1, so only the known values see it
const MUTATION = Ref("none")

action_for(U, beta) = wilson_action(U, MUTATION[] == "beta_twice" ? 2beta : beta)

function broken_first_order!(U, P, delta_tau, driver)
    update_gaugefields!(U, P, delta_tau, driver)
    update_momenta!(P, U, delta_tau, driver)
    return nothing
end

integrator_for() = MUTATION[] == "first_order" ? broken_first_order! : QPQ()
sigma_for() = MUTATION[] == "sigma_only" ? sqrt(2.0) : 1.0

make_md(U, beta; steps, tau=1.0) =
    md_driver(U, action_for(U, beta); steps, trajectory_length=tau, integrator=integrator_for())

function record(name, ok, detail)
    push!(RESULTS, (name, ok, detail))
    println("  ", ok ? "PASS" : "FAIL", "  ", rpad(name, 56), detail)
    flush(stdout)
end

function new_field(lattice, colors, start, seed)
    gauge_configuration(lattice; colors, start, seed, process_grid=ntuple(_ -> 1, length(lattice)))
end

"Run an HMC chain and return the plaquette and exp(-ΔH) histories after `therm`."
function chain(lattice, colors, beta; start=:hot, ntraj, therm, steps, tau=1.0, seed)
    U = new_field(lattice, colors, start, seed)
    md = make_md(U, beta; steps, tau)
    p = gauge_momenta(U)
    old_U = copy_configuration(U)
    plaq = Float64[]
    emdH = Float64[]
    acc = 0
    for k in 1:ntraj
        r = hmc_trajectory!(U, p, old_U, md, seed, k; sigma=sigma_for())
        if k > therm
            push!(plaq, measure_plaquette(U))
            push!(emdH, exp(-r.dH))
            acc += r.accepted
        end
    end
    return (; U, plaq, emdH, acceptance=acc / (ntraj - therm))
end

function main(args)
    a = parse_args(args)
    check_keys(a, ("colors", "lattice", "mutation", "ntraj", "seed", "therm", "workdir"))
    colors = getarg(a, "colors", 3)
    lattice = getarg(a, "lattice", (4, 4, 4, 4))
    ntraj = getarg(a, "ntraj", 300)
    therm = getarg(a, "therm", 50)
    seed = getarg(a, "seed", 1234)
    workdir = mkpath(getarg(a, "workdir", mktempdir()))
    MUTATION[] = getarg(a, "mutation", "none")
    MUTATION[] == "none" || println("!! mutation = ", MUTATION[], " (deliberately broken)")
    N = colors
    d = length(lattice)
    G = SU(N)
    beta_mid = 0.63 * N^2
    println("== check_hmc: SU($N), lattice ", join(lattice, "x"), ", β_mid = ", beta_mid)

    # A configuration at intermediate β for the deterministic checks.
    base = chain(lattice, N, beta_mid; ntraj=30, therm=29, steps=20, seed)
    U0 = base.U
    md_f = make_md(U0, beta_mid; steps=20, tau=1.0)
    md_b = make_md(U0, beta_mid; steps=20, tau=-1.0)

    # 1. reversibility
    U = copy_configuration(U0)
    p = gauge_momenta(U)
    gaussian_momenta!(p; sigma=sigma_for(), seed=7, sweep=0)
    links0 = host_links(U, joinpath(workdir, "rev0.jld2"))
    rf = md_trajectory!(U, p, md_f)
    rb = md_trajectory!(U, p, md_b)
    links1 = host_links(U, joinpath(workdir, "rev1.jld2"))
    dU = maximum(maximum(abs, l1 - l0) for (l0, l1) in zip(links0, links1))
    dHsum = abs(rf.delta_hamiltonian + rb.delta_hamiltonian)
    record("reversibility", dU < 1e-10 && dHsum < 1e-8 * abs(rf.initial_hamiltonian),
        @sprintf("max|ΔU| = %.1e, |ΔH(+τ) + ΔH(-τ)| = %.1e", dU, dHsum))

    # 2. ΔH scaling with the step size. A single (U, P) can show |ΔH| that is
    # not monotonic in δτ, because the δτ² and δτ⁴ terms can cancel; the rms
    # over a few momenta, and step sizes small enough for the asymptotic
    # regime, give a clean slope.
    stepslist = (10, 20, 40, 80, 160)
    rms = Float64[]
    for s in stepslist
        md = make_md(U0, beta_mid; steps=s)
        acc2 = 0.0
        for m in 1:4
            U = copy_configuration(U0)
            gaussian_momenta!(p; sigma=sigma_for(), seed=7, sweep=m)
            acc2 += md_trajectory!(U, p, md).delta_hamiltonian^2
        end
        push!(rms, sqrt(acc2 / 4))
    end
    x = log.(1.0 ./ collect(stepslist))[end-2:end]
    y = log.(rms)[end-2:end]
    slope = sum((x .- sum(x) / 3) .* (y .- sum(y) / 3)) / sum(abs2, x .- sum(x) / 3)
    record("rms ΔH ∝ δτ²", 1.8 < slope < 2.2,
        @sprintf("slope %.3f from rms ΔH = %s", slope, join((@sprintf("%.2e", v) for v in rms), ", ")))

    # 3 and 7. intermediate β run
    mid = chain(lattice, N, beta_mid; ntraj, therm, steps=20, seed=seed + 10)
    links = host_links(mid.U, joinpath(workdir, "mid.jld2"))
    worst = 0.0
    for l in links
        for idx in CartesianIndices(size(l)[3:end])
            r = ingroup_residual(G, l[:, :, idx])
            worst = max(worst, r.unitarity, r.determinant)
        end
    end
    record("links in SU($N) after $ntraj trajectories", worst < 1e-10, @sprintf("max residual %.1e", worst))
    e = gamma_method(mid.emdH)
    record("<exp(-ΔH)> = 1 at β = $beta_mid", abs(e.mean - 1) < 4e.error,
        @sprintf("%.4f ± %.4f, acceptance %.2f", e.mean, e.error, mid.acceptance))

    # 4. β = 0
    zero = chain(lattice, N, 0.0; ntraj, therm, steps=10, seed=seed + 20)
    z = gamma_method(zero.plaq)
    record("β = 0: <P> = 0", abs(z.mean) < 4z.error, @sprintf("%.5f ± %.5f", z.mean, z.error))

    # 5. strong coupling
    beta_s = N == 2 ? 0.4 : 0.1 * N^2
    strong = chain(lattice, N, beta_s; ntraj, therm, steps=10, seed=seed + 30)
    s = gamma_method(strong.plaq)
    u, uerr = one_link_u(N, beta_s)
    sig = sqrt(s.error^2 + uerr^2)
    record("strong coupling β = $beta_s: <P> = u(β)", abs(s.mean - u) < 4sig,
        @sprintf("<P> = %.5f ± %.5f, u = %.5f ± %.5f (%.1fσ)", s.mean, s.error, u, uerr, abs(s.mean - u) / sig))

    # 6. weak coupling
    beta_w = (N^2 - 1) / (0.05 * d)
    weak = chain(lattice, N, beta_w; start=:cold, ntraj, therm, steps=ceil(Int, 20 * sqrt(beta_w / beta_mid)), seed=seed + 40)
    w = gamma_method(weak.plaq)
    pred = (N^2 - 1) / (d * beta_w)
    ratio = (1 - w.mean) / pred
    record("weak coupling β = $(round(beta_w; digits=2)): 1-<P> = (N²-1)/(dβ)", abs(ratio - 1) < 0.1,
        @sprintf("1-<P> = %.5f ± %.5f, leading order %.5f, ratio %.3f", 1 - w.mean, w.error, pred, ratio))

    ok = all(r -> r[2], RESULTS)
    println(ok ? "ALL PASS" : "SOME CHECKS FAILED")
    return ok
end

exit(main(ARGS) ? 0 : 1)
