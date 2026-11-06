"""
    LatticeReference

Reference implementation of pure-gauge lattice observables and the Wilson
gradient flow on plain arrays, used as the oracle when testing production
code. Any dimension, any matrix group in its defining representation.

A field is a vector of `d` arrays, one per direction, each of size `L` with
an `n × n` matrix per site. Boundary conditions are periodic. Only the Julia
standard library is used. Speed is not a goal.

Conventions (the same as Gaugefields and QCDMeasurements v1):
- plaquette: average of Re tr P / n over sites and planes μ < ν;
- Wilson loop W(R, T): R steps in a spatial direction μ < d, T steps in the
  last direction d, averaged over sites and μ;
- energy density, plaquette form: E = 2 n (number of planes) (1 − plaquette);
- energy density, clover form: E = −Σ_{μ<ν} tr(F_μν²) averaged over sites,
  with F_μν = TA(clover)/4 and TA the traceless anti-Hermitian part;
- topological charge (4D, clover): Q = −(1/32π²) Σ_x ε_{μνρσ} tr(F_μν F_ρσ);
- flow: Lüscher's Wilson flow, dV/dt = Z(V) V with Z = −P(Ω), where Ω is
  U_μ(x) times the sum of its 2(d − 1) staples and P the projection on the
  Lie algebra (TA for SU(N)); integrated with his third-order Runge–Kutta
  scheme (M. Lüscher, JHEP 08 (2010) 071, arXiv:1006.4518, appendix C).
"""
module LatticeReference

using LinearAlgebra

export from_host, to_host, lattice_size, colors,
    line, plaquette, wilson_loop, wilson_loops,
    traceless_antihermitian, clover_field_strength,
    energy_plaquette, energy_clover, topological_charge_clover,
    staple_sum, flow_force, flow_step, flow,
    gauge_transform

const Field = Vector{<:AbstractArray{<:AbstractMatrix}}

"Convert host link arrays (n × n × L₁ × … × L_d, one per direction) to a field."
function from_host(links)
    L = size(links[1])[3:end]
    return [[Matrix{ComplexF64}(links[μ][:, :, I]) for I in CartesianIndices(L)]
            for μ in eachindex(links)]
end

"Convert a field back to host link arrays."
function to_host(U)
    L = size(U[1])
    n = size(first(U[1]), 1)
    out = Array{ComplexF64}[]
    for μ in eachindex(U)
        A = zeros(ComplexF64, n, n, L...)
        for I in CartesianIndices(L)
            A[:, :, I] = U[μ][I]
        end
        push!(out, A)
    end
    return out
end

lattice_size(U) = size(U[1])
colors(U) = size(first(U[1]), 1)

"Site `x` moved by `s` steps in direction `μ`, periodic."
function shift(x::CartesianIndex{D}, μ, s, L) where {D}
    return CartesianIndex(ntuple(k -> k == μ ? mod1(x[k] + s, L[k]) : x[k], D))
end

"""
    line(U, x, steps)

Product of links along a path from site `x`. `steps` is a list of
`(direction, count)`: a positive count goes forward with U_μ, a negative
count goes backward with U_μ†. The same convention as `Wilsonline`.
"""
function line(U, x, steps)
    L = lattice_size(U)
    n = colors(U)
    M = Matrix{ComplexF64}(I, n, n)
    for (μ, c) in steps
        for _ in 1:abs(c)
            if c > 0
                M = M * U[μ][x]
                x = shift(x, μ, 1, L)
            else
                x = shift(x, μ, -1, L)
                M = M * U[μ][x]'
            end
        end
    end
    return M
end

sites(U) = CartesianIndices(lattice_size(U))

function plaquette(U)
    d = length(U)
    n = colors(U)
    s = 0.0
    for x in sites(U), μ in 1:d, ν in μ+1:d
        s += real(tr(line(U, x, ((μ, 1), (ν, 1), (μ, -1), (ν, -1)))))
    end
    return s / (n * length(sites(U)) * (d * (d - 1) ÷ 2))
end

function wilson_loop(U, R, T)
    d = length(U)
    n = colors(U)
    s = 0.0
    for x in sites(U), μ in 1:d-1
        s += real(tr(line(U, x, ((μ, R), (d, T), (μ, -R), (d, -T)))))
    end
    return s / (n * length(sites(U)) * (d - 1))
end

"Matrix of W(R, T) for R = 1:Rmax (rows) and T = 1:Tmax (columns)."
wilson_loops(U, Rmax, Tmax) = [wilson_loop(U, R, T) for R in 1:Rmax, T in 1:Tmax]

function traceless_antihermitian(A)
    n = size(A, 1)
    B = (A - A') / 2
    return B - (tr(B) / n) * I
end

function clover_field_strength(U, x, μ, ν)
    C = line(U, x, ((μ, 1), (ν, 1), (μ, -1), (ν, -1))) +
        line(U, x, ((ν, 1), (μ, -1), (ν, -1), (μ, 1))) +
        line(U, x, ((ν, -1), (μ, 1), (ν, 1), (μ, -1))) +
        line(U, x, ((μ, -1), (ν, -1), (μ, 1), (ν, 1)))
    return traceless_antihermitian(C) / 4
end

function energy_plaquette(U)
    d = length(U)
    return 2 * colors(U) * (d * (d - 1) ÷ 2) * (1 - plaquette(U))
end

function energy_clover(U)
    d = length(U)
    s = 0.0
    for x in sites(U), μ in 1:d, ν in μ+1:d
        F = clover_field_strength(U, x, μ, ν)
        s -= real(tr(F * F))
    end
    return s / length(sites(U))
end

function levicivita(p)
    s = 1
    p = collect(p)
    for i in eachindex(p), j in i+1:length(p)
        p[i] > p[j] && (s = -s)
    end
    return s
end

function topological_charge_clover(U)
    length(U) == 4 || throw(ArgumentError("topological charge needs four dimensions"))
    q = 0.0
    for x in sites(U)
        F = [μ == ν ? zeros(ComplexF64, 1, 1) : clover_field_strength(U, x, μ, ν)
             for μ in 1:4, ν in 1:4]
        for μ in 1:4, ν in 1:4, ρ in 1:4, σ in 1:4
            length(unique((μ, ν, ρ, σ))) == 4 || continue
            q += levicivita((μ, ν, ρ, σ)) * real(tr(F[μ, ν] * F[ρ, σ]))
        end
    end
    return -q / (32 * π^2)
end

"Ω = U_μ(x) times the sum of the 2(d − 1) staples of the link."
function staple_sum(U, x, μ)
    d = length(U)
    n = colors(U)
    Ω = zeros(ComplexF64, n, n)
    for ν in 1:d
        ν == μ && continue
        Ω += line(U, x, ((μ, 1), (ν, 1), (μ, -1), (ν, -1)))
        Ω += line(U, x, ((μ, 1), (ν, -1), (μ, -1), (ν, 1)))
    end
    return Ω
end

"Z_μ(x) = −P(Ω), the flow generator; `project` is the projection on the algebra."
function flow_force(U; project=traceless_antihermitian)
    return [[-project(staple_sum(U, x, μ)) for x in sites(U)] for μ in eachindex(U)]
end

apply(Z, U) = [[exp(Z[μ][x]) * U[μ][x] for x in CartesianIndices(U[μ])] for μ in eachindex(U)]
combine(cs, Zs) = [[sum(c * Z[μ][x] for (c, Z) in zip(cs, Zs)) for x in CartesianIndices(Zs[1][μ])]
                   for μ in eachindex(Zs[1])]

"One Lüscher RK3 step of size ε."
function flow_step(U, ε; project=traceless_antihermitian)
    Z0 = flow_force(U; project)
    W1 = apply(combine((ε / 4,), (Z0,)), U)
    Z1 = flow_force(W1; project)
    W2 = apply(combine((8ε / 9, -17ε / 36), (Z1, Z0)), W1)
    Z2 = flow_force(W2; project)
    return apply(combine((3ε / 4, -8ε / 9, 17ε / 36), (Z2, Z1, Z0)), W2)
end

function flow(U, ε, nsteps; project=traceless_antihermitian)
    for _ in 1:nsteps
        U = flow_step(U, ε; project)
    end
    return U
end

"U_μ(x) → g(x) U_μ(x) g(x + μ)†, with `g` an array of matrices of size L."
function gauge_transform(U, g)
    L = lattice_size(U)
    return [[g[x] * U[μ][x] * g[shift(x, μ, 1, L)]' for x in sites(U)] for μ in eachindex(U)]
end

end # module
