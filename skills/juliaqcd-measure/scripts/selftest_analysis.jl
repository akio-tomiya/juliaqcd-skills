# Self-test of analysis.jl on synthetic data with known answers. Julia
# standard library only; runs in under a minute anywhere.
#
#   julia selftest_analysis.jl
#
# 1. jackknife of the mean of independent data equals s/√n
# 2. effective potential and Creutz ratios of W = c exp(-σRT - μ(R+T))
#    equal μ + σR and σ exactly; the cosh effective mass of a one-state
#    correlator equals its mass exactly, and with an excited state it falls
#    monotonically towards the ground state
# 3. on autocorrelated synthetic flow data (τ_int ≈ 4.5), the error of t0
#    from the binned jackknife (bin from auto_bin) agrees with the spread of
#    t0 over independent replicas, and the unbinned error is too small

using Random
using Printf
include(joinpath(@__DIR__, "analysis.jl"))

function ar1(rng, n, r)
    x = zeros(n)
    x[1] = randn(rng)
    for i in 2:n
        x[i] = r * x[i-1] + sqrt(1 - r^2) * randn(rng)
    end
    return x
end

function main()
    ok = true
    rng = Xoshiro(7)
    say(good, name, detail) = (println(good ? "  PASS  " : "  FAIL  ", rpad(name, 48), detail); ok &= good)

    x = randn(rng, 500)
    jk = jackknife(v -> v[1], [[xi] for xi in x])
    s = sqrt(sum(abs2, x .- sum(x) / 500) / 499 / 500)
    say(abs(jk.error - s) < 1e-12, "jackknife of a mean = s/√n", @sprintf("%.6f vs %.6f", jk.error, s))

    σ, μ, c = 0.2, 0.1, 0.7
    W = [c * exp(-σ * R * T - μ * (R + T)) for R in 1:5, T in 1:5]
    V = effective_potential(W)
    C = creutz_ratios(W)
    dv = maximum(abs(V[R, T] - (μ + σ * R)) for R in 1:5, T in 1:4)
    dc = maximum(abs.(C .- σ))
    say(max(dv, dc) < 1e-12, "effective potential and Creutz ratios", @sprintf("max error %.1e", max(dv, dc)))

    # meson correlator: ground state plus an excited state of 0.8 times its
    # weight at Δ = 0, which makes m_eff fall towards m
    T, mπ, mx = 16, 0.45, 1.3
    Cfull = [cosh(mπ * (Δ - T / 2)) / cosh(mπ * T / 2) + 0.8cosh(mx * (Δ - T / 2)) / cosh(mx * T / 2)
             for Δ in 0:T-1]
    Cf = fold_correlator(Cfull)
    meff = effective_mass_cosh(Cf, T)
    ground = effective_mass_cosh(fold_correlator([cosh(mπ * (Δ - T / 2)) for Δ in 0:T-1]), T)
    single = maximum(abs.(ground .- mπ))
    falls = all(diff(meff) .< 0) && all(meff .> mπ) && abs(meff[end] - mπ) < 0.01
    sym = maximum(abs(Cfull[1+Δ] - Cfull[1+T-Δ]) for Δ in 1:T-1)
    say(single < 1e-12 && falls && sym < 1e-12, "cosh effective mass of a known correlator",
        @sprintf("single state error %.1e; two states: m_eff %.3f → %.4f (m = %.2f)", single, meff[1], meff[end], mπ))

    # synthetic E(t) = a + b t with autocorrelated a and b
    ts = collect(0.0:0.02:3.0)
    A, B, r, n, reps = 0.15, 0.12, 0.8, 400, 300
    t0s = Float64[]
    err_auto = Float64[]
    err_one = Float64[]
    for _ in 1:reps
        da = 0.02 .* ar1(rng, n, r)
        db = 0.01 .* ar1(rng, n, r)
        samples = [(A + da[i]) .+ (B + db[i]) .* ts for i in 1:n]
        f = E -> flow_scales(ts, E).t0
        series = [E[50] for E in samples]
        push!(t0s, jackknife(f, samples; bin=auto_bin(series)).value)
        push!(err_auto, jackknife(f, samples; bin=auto_bin(series)).error)
        push!(err_one, jackknife(f, samples; bin=1).error)
    end
    m = sum(t0s) / reps
    spread = sqrt(sum(abs2, t0s .- m) / (reps - 1))
    ratio_auto = (sum(err_auto) / reps) / spread
    ratio_one = (sum(err_one) / reps) / spread
    say(0.8 < ratio_auto < 1.2, "binned jackknife error matches the true spread",
        @sprintf("mean error / spread = %.2f (spread %.5f)", ratio_auto, spread))
    say(ratio_one < 0.6, "unbinned error is too small (as it must be)", @sprintf("mean error / spread = %.2f", ratio_one))

    println(ok ? "SELFTEST PASS" : "SELFTEST FAIL")
    return ok
end

exit(main() ? 0 : 1)
