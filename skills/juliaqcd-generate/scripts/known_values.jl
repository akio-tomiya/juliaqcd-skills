# Known values used by the checks. Load after GaugeGroups.jl.

"""
    one_link_u(colors, beta; samples=400_000, rng=Xoshiro(42))

One-link expectation value u(β) = <Re tr U / N> with weight
exp((β/N) Re tr U), by Haar Monte Carlo. Returns `(u, error)`. For the
Wilson action it is the leading strong-coupling plaquette in any dimension,
and in two dimensions W(R, T) = u^(RT) exactly (up to finite-volume terms
that are negligible on a torus much larger than the loop).
"""
function one_link_u(colors, beta; samples=400_000, rng=Xoshiro(42))
    G = SU(colors)
    x = Vector{Float64}(undef, samples)
    w = similar(x)
    for i in 1:samples
        t = real(tr(random_element(rng, G))) / colors
        x[i] = t
        w[i] = exp(beta * t)
    end
    W = sum(w) / samples
    u = sum(x .* w) / sum(w)
    # delta-method error of a ratio estimator
    err = sqrt(sum(abs2, w .* (x .- u)) / samples / samples) / W
    return u, err
end
