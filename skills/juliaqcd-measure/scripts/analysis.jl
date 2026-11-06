# Analysis of gradient-flow and Wilson-loop data. Julia standard library only.

include(joinpath(@__DIR__, "..", "..", "juliaqcd-generate", "scripts", "stats.jl"))

"""
    flow_scales(t, E; c=0.3)

Scales from the ensemble mean of the energy density E(t) on the flow-time
grid `t` (in lattice units). `t0` solves t² E(t) = c (Lüscher,
arXiv:1006.4518); `w0` solves t d/dt(t² E) = c at t = w0² (BMW,
arXiv:1203.4469). The derivative uses central differences (one-sided at the
ends) and the crossings linear interpolation, the same as
`QCDMeasurements.estimate_flow_scales`. A scale that the flow range does not
reach is NaN.
"""
function flow_scales(t, E; c=0.3)
    t2E = t .^ 2 .* E
    w = t .* derivative(t, t2E)
    t0 = first_crossing(t, t2E, c)
    w0sq = first_crossing(t, w, c)
    return (t0=t0, w0=isnan(w0sq) ? NaN : sqrt(w0sq))
end

function derivative(t, y)
    n = length(t)
    d = similar(y, Float64)
    d[1] = (y[2] - y[1]) / (t[2] - t[1])
    for i in 2:n-1
        d[i] = (y[i+1] - y[i-1]) / (t[i+1] - t[i-1])
    end
    d[n] = (y[n] - y[n-1]) / (t[n] - t[n-1])
    return d
end

function first_crossing(t, y, c)
    y[1] == c && return Float64(t[1])
    for i in 2:length(t)
        if y[i-1] < c <= y[i]
            return t[i-1] + (c - y[i-1]) / (y[i] - y[i-1]) * (t[i] - t[i-1])
        end
    end
    return NaN
end

"""
    jackknife(f, samples; bin=1)

Jackknife estimate of `f(mean)` from `samples`, a vector of observation
vectors in Monte Carlo order. Consecutive blocks of `bin` samples are
averaged first, so that the blocks are nearly independent when `bin` is
several times the integrated autocorrelation time; leftover samples at the
start are dropped. Returns `(value, error, nbins)`; `value` is `f` of the
mean of the samples used. NaN in any jackknife sample gives a NaN error.
"""
function jackknife(f, samples; bin=1)
    n = length(samples)
    nb = n ÷ bin
    nb >= 2 || throw(ArgumentError("need at least two bins: $n samples, bin = $bin"))
    used = samples[n-nb*bin+1:end]
    blocks = [sum(used[(b-1)*bin+1:b*bin]) / bin for b in 1:nb]
    total = sum(blocks)
    value = f(total / nb)
    jk = [f((total - blocks[b]) / (nb - 1)) for b in 1:nb]
    mean_jk = sum(jk) / nb
    err = sqrt.((nb - 1) / nb .* sum(map(j -> (j .- mean_jk) .^ 2, jk)))
    return (value=value, error=err, nbins=nb)
end

"""
    effective_potential(W)

a V(R) at each T from the matrix W[R, T]: log(W(R, T) / W(R, T + 1)).
Returns a matrix with one column fewer than `W`. It approaches the static
potential as T grows; a non-positive W gives NaN.
"""
function effective_potential(W)
    R, T = size(W)
    return [W[r, t] > 0 && W[r, t+1] > 0 ? log(W[r, t] / W[r, t+1]) : NaN
            for r in 1:R, t in 1:T-1]
end

"""
    creutz_ratios(W)

χ(R, T) = −log(W(R, T) W(R−1, T−1) / (W(R, T−1) W(R−1, T))) for R, T ≥ 2.
At large R = T it approaches the string tension σa² (M. Creutz, Phys. Rev.
D 21 (1980) 2308). Entry [R−1, T−1] holds χ(R, T).
"""
function creutz_ratios(W)
    R, T = size(W)
    return [begin
        num = W[r, t] * W[r-1, t-1]
        den = W[r, t-1] * W[r-1, t]
        num > 0 && den > 0 ? -log(num / den) : NaN
    end for r in 2:R, t in 2:T]
end

"""
    fold_correlator(C)

(C(Δ) + C(T − Δ))/2 for Δ = 0, …, T/2 from C indexed by Δ = 0, …, T − 1
(entry Δ + 1). Correct for correlators that are even under time reflection,
as the local meson correlators with the same operator at source and sink are.
"""
function fold_correlator(C)
    T = length(C)
    return [(C[1+Δ] + C[1+mod(T - Δ, T)]) / 2 for Δ in 0:T÷2]
end

"""
    effective_mass_cosh(C, T)

Effective mass m(Δ), Δ = 0, …, length(C) − 2, from a correlator
C(Δ) ∝ cosh(m (Δ − T/2)) on a lattice of time extent T: the solution of
C(Δ)/C(Δ+1) = cosh(m(Δ − T/2))/cosh(m(Δ + 1 − T/2)). NaN where the ratio
admits no positive solution (noise, or Δ + 1 > T/2).
"""
function effective_mass_cosh(C, T)
    m = fill(NaN, length(C) - 1)
    for Δ in 0:length(C)-2
        r = C[Δ+1] / C[Δ+2]
        (isfinite(r) && r > 1 && Δ + 1 <= T / 2) || continue
        g(x) = cosh(x * (Δ - T / 2)) / cosh(x * (Δ + 1 - T / 2)) - r
        lo, hi = 0.0, 1.0
        while g(hi) < 0 && hi < 50
            hi *= 2
        end
        g(hi) < 0 && continue
        for _ in 1:200
            mid = (lo + hi) / 2
            g(mid) < 0 ? (lo = mid) : (hi = mid)
        end
        m[Δ+1] = (lo + hi) / 2
    end
    return m
end

"""
    auto_bin(series)

Bin size for `jackknife`: four times the integrated autocorrelation time of
`series` (in units of its spacing), rounded up, at least 1.
"""
auto_bin(series) = max(1, ceil(Int, 4 * gamma_method(series).tau_int))

"""
    choose_bin(series; minbins=20)

`auto_bin(series)`, capped so that at least `minbins` bins remain. Returns
`(bin, capped)`; when `capped` is true the ensemble is too short for its
autocorrelation time and the errors are underestimated.
"""
function choose_bin(series; minbins=20)
    b = auto_bin(series)
    cap = max(1, length(series) ÷ minbins)
    return b > cap ? (cap, true) : (b, false)
end

"Read a CSV with a header into a Dict of column name to Vector{Float64}."
function read_csv(path)
    lines = filter(!isempty ∘ strip, readlines(path))
    header = split(lines[1], ',')
    cols = Dict(String(h) => Float64[] for h in header)
    for line in lines[2:end]
        for (h, v) in zip(header, split(line, ','))
            push!(cols[h], parse(Float64, v))
        end
    end
    return cols
end
