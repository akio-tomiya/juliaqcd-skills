# Statistics for Monte Carlo time series. Julia standard library only.

"""
    gamma_method(a; S=1.5)

Mean, error, and integrated autocorrelation time of the series `a` by the
Γ method with automatic windowing (U. Wolff, Comput. Phys. Commun. 156 (2004)
143, hep-lat/0306017). Returns a named tuple
`(mean, error, tau_int, tau_int_error, window, n)`.
For a constant series the error is zero and `tau_int = 0.5`.
"""
function gamma_method(a::AbstractVector{<:Real}; S=1.5)
    n = length(a)
    n >= 2 || return (mean=n == 1 ? float(a[1]) : NaN, error=NaN, tau_int=NaN,
        tau_int_error=NaN, window=0, n=n)
    m = sum(a) / n
    d = a .- m
    gamma0 = sum(abs2, d) / n
    if gamma0 <= eps(Float64) * max(abs(m), 1.0)^2
        return (mean=m, error=0.0, tau_int=0.5, tau_int_error=0.0, window=0, n=n)
    end
    tau = 0.5
    window = 0
    for W in 1:(n÷2)
        gW = sum(d[i] * d[i+W] for i in 1:(n-W)) / (n - W)
        tau += gW / gamma0
        t = tau <= 0.5 ? 1e-9 : S / log((2tau + 1) / (2tau - 1))
        g = exp(-W / t) - t / sqrt(W * n)
        window = W
        g < 0 && break
    end
    tau = max(tau, 0.5)
    err = sqrt(2tau * gamma0 / n)
    tau_err = tau * sqrt((4window + 2) / n)
    return (mean=m, error=err, tau_int=tau, tau_int_error=tau_err, window=window, n=n)
end

"""
    thermalization_cut(a)

Number of leading entries to drop. The reference is the mean of the second
half of the series. The cut is the first time the series crosses the
reference, plus twice the integrated autocorrelation time of the second
half. Returns `(cut, stable)`, where `stable` says whether the first and
second halves of the remainder agree within 3σ. A drifting start (hot or
cold) inflates the Γ-method error, so comparing halves alone would accept a
cut of zero; the crossing rule avoids that.
"""
function thermalization_cut(a)
    n = length(a)
    tail = a[n÷2+1:end]
    ref = sum(tail) / length(tail)
    s0 = sign(a[1] - ref)
    crossing = something(findfirst(x -> sign(x - ref) != s0, a), n)
    cut = min(crossing + 2 * ceil(Int, gamma_method(tail).tau_int), n ÷ 2)
    rest = a[cut+1:end]
    h = length(rest) ÷ 2
    h >= 10 || return (cut, false)
    r1 = gamma_method(rest[1:h])
    r2 = gamma_method(rest[h+1:end])
    sigma = sqrt(r1.error^2 + r2.error^2)
    return (cut, abs(r1.mean - r2.mean) <= 3 * max(sigma, eps()))
end

"Read a CSV written by `hmc_puregauge.jl` into a Dict of column name to Vector{Float64}."
function read_history(path)
    lines = readlines(path)
    header = split(lines[1], ',')
    cols = Dict(h => Float64[] for h in header)
    for line in lines[2:end]
        isempty(strip(line)) && continue
        for (h, v) in zip(header, split(line, ','))
            push!(cols[h], parse(Float64, v))
        end
    end
    return cols
end
