# End-to-end known value: in two dimensions the Wilson action gives
# W(R, T) = u(β)^(R T) exactly, with u(β) the one-link expectation value
# (the plaquettes are independent after gauge fixing). This script generates
# configurations with the HMC of juliaqcd-generate, measures W(R, T) with this
# skill, and compares. It tests generation and measurement together,
# including the normalization of the coupling.
#
#   julia --project=ENV check_area_law.jl colors=2 beta=4.0
#
# Optional: lattice=16,16 ntraj=20000 every=5 rmax=3 seed=12. About a minute
# for SU(2) on 16×16, most of it compilation. Exit code 1 on FAIL.
#
# u(β) is computed twice: from the Bessel-determinant formula for the SU(N)
# one-link integral, z(β) = Σ_l det[I_{l+i-j}(β/N)], u = d log z / dβ, and
# by Haar Monte Carlo; the two must agree.

import JACC
JACC.@init_backend
using Gaugefields
using Printf
using Random
include(joinpath(@__DIR__, "measure_common.jl"))
include(joinpath(@__DIR__, "analysis.jl"))
include(joinpath(@__DIR__, "..", "..", "juliaqcd-extend", "scripts", "GaugeGroups.jl"))
using .GaugeGroups
include(joinpath(@__DIR__, "..", "..", "juliaqcd-generate", "scripts", "known_values.jl"))

besseli(n, x::BigFloat) = (n = abs(n); sum((x / 2)^(2k + n) / (factorial(big(k)) * factorial(big(k + n))) for k in 0:200))

function one_link_z(N, beta::BigFloat)
    x = beta / N
    return sum(det([besseli(l + i - j, x) for i in 1:N, j in 1:N]) for l in -12:12)
end

function one_link_u_exact(N, beta)
    setprecision(BigFloat, 256) do
        b = BigFloat(beta)
        h = big"1e-20"
        return Float64((log(one_link_z(N, b + h)) - log(one_link_z(N, b - h))) / (2h))
    end
end

function main(args)
    a = parse_args(args)
    check_keys(a, ("beta", "colors", "every", "lattice", "ntraj", "rmax", "seed"))
    N = getarg(a, "colors", 2)
    haskey(a, "beta") || error("beta=... is required")
    beta = getarg(a, "beta", 4.0)
    L = getarg(a, "lattice", (16, 16))
    length(L) == 2 || error("the area law is exact in two dimensions only")
    ntraj = getarg(a, "ntraj", 20000)
    every = getarg(a, "every", 5)
    rmax = getarg(a, "rmax", 3)
    seed = getarg(a, "seed", 12)
    therm = 200

    u = one_link_u_exact(N, beta)
    umc, umc_err = one_link_u(N, beta)
    println("== check_area_law: SU($N), lattice ", join(L, "x"), ", β = $beta")
    ok_u = abs(u - umc) < 4umc_err
    println("  ", ok_u ? "PASS" : "FAIL", @sprintf("  u(β) = %.6f (Bessel determinant), %.6f ± %.6f (Haar Monte Carlo)", u, umc, umc_err))

    U = gauge_configuration(L; colors=N, start=:hot, seed, process_grid=(1, 1))
    md = md_driver(U, wilson_action(U, beta); steps=10, trajectory_length=1.0, integrator=QPQ())
    p = gauge_momenta(U)
    old = copy_configuration(U)
    wm = WilsonLoops(U, rmax, rmax)
    samples = Vector{Float64}[]
    acc = 0
    for k in 1:ntraj
        r = hmc_trajectory!(U, p, old, md, seed, k)
        acc += r.accepted
        k > therm && k % every == 0 && push!(samples, vec(measure_wilson_loops(wm, U)))
    end
    bin = auto_bin([s[1] for s in samples])
    jk = jackknife(identity, samples; bin)
    W = reshape(jk.value, rmax, rmax)
    We = reshape(jk.error, rmax, rmax)
    @printf("  acceptance %.3f, %d measurements, bin %d\n", acc / ntraj, length(samples), bin)
    worst = 0.0
    for R in 1:rmax, T in 1:rmax
        exact = u^(R * T)
        dev = abs(W[R, T] - exact) / We[R, T]
        worst = max(worst, dev)
        @printf("    W(%d,%d) = %.6f ± %.6f   u^%d = %.6f   (%.1fσ)\n", R, T, W[R, T], We[R, T], R * T, exact, dev)
    end
    ok_w = worst < 3.5
    println("  ", ok_w ? "PASS" : "FAIL", @sprintf("  W(R,T) = u^(RT), largest deviation %.1fσ", worst))
    ok = ok_u && ok_w
    println(ok ? "ALL PASS" : "SOME CHECKS FAILED")
    return ok
end

exit(main(ARGS) ? 0 : 1)
