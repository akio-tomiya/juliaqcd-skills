"""
    FermionReference

Reference implementation of the Wilson and Wilson–clover Dirac operators,
point-source propagators, and local meson correlators on plain arrays, used
as the oracle when testing JuliaQCD (LatticeDiracOperators and
QCDMeasurements). Four dimensions, any number of colors. Julia standard
library only; speed is not a goal.

A spinor field is an array ψ[c, α, x₁, x₂, x₃, x₄] (color, spin, site), the
order of the interior of a LatticeDiracOperators v1 fermion field. Gauge
fields are as in LatticeReference. A propagator is an array
S[c, α, x₁, x₂, x₃, x₄, c₀, α₀]: the solution for a point source at x₀ with
color c₀ and spin α₀.

Conventions (the same as LatticeDiracOperators 1.1 and QCDMeasurements 1.0):
- Wilson operator, with fermion boundary phases bc[μ] on hops that cross the
  boundary in direction μ (default: periodic in space, antiperiodic in time):
      (Dψ)(x) = ψ(x) − κ Σ_μ [(r − γ_μ) U_μ(x) ψ(x+μ̂) + (r + γ_μ) U_μ(x−μ̂)† ψ(x−μ̂)];
- γ matrices in the chiral basis of LatticeDiracOperators and Bridge++:
  γ_k = [0 −iσ_k; iσ_k 0] (k = 1, 2, 3), γ_4 = [0 −1; −1 0], γ_5 = γ_1γ_2γ_3γ_4;
- clover: D = D_W − κ c_SW Σ_{μ<ν} γ_μγ_ν F_μν, F_μν = (Q_μν − Q_μν†)/8,
  Q_μν the sum of the four plaquettes at x in the μν plane. Since
  γ_μγ_ν = −iσ_μν with σ_μν = (i/2)[γ_μ, γ_ν], this is the
  Sheikholeslami–Wohlert term −(κ c_SW/2) Σ_{μ,ν} σ_μν F̂_μν with the
  Hermitian F̂_μν = −i F_μν;
- connected local meson correlator from a point source at x₀ along the
  last direction (the contraction of QCDMeasurements.MesonCorrelatorMeasurement):
      C(Δ, p) = −Σ_{x: x₄ − x₀₄ = Δ} e^{−ip·(x−x₀)} tr[Γ₂ S(x,x₀) Γ̄₁ S(x₀,x)],
  with Γ̄ = γ₄ Γ† γ₄ and S(x₀,x) = γ₅ S(x,x₀)† γ₅. For Γ₁ = Γ₂ = γ₅ it is
  C_PP(Δ) = Σ tr[S S†] > 0.
"""
module FermionReference

using LinearAlgebra
include(joinpath(@__DIR__, "LatticeReference.jl"))
using .LatticeReference: line, shift, lattice_size, colors

export GAMMA, GAMMA5, apply_dirac, solve_dirac, point_propagator,
    meson_correlator, free_dirac_momentum, free_propagator, free_spectrum,
    dense_matrix, clover_F, clover_fields

const PAULI = (ComplexF64[0 1; 1 0], ComplexF64[0 -im; im 0], ComplexF64[1 0; 0 -1])
const Z2 = zeros(ComplexF64, 2, 2)
const I2 = Matrix{ComplexF64}(I, 2, 2)
const GAMMA = (
    [Z2 -im*PAULI[1]; im*PAULI[1] Z2],
    [Z2 -im*PAULI[2]; im*PAULI[2] Z2],
    [Z2 -im*PAULI[3]; im*PAULI[3] Z2],
    [Z2 -I2; -I2 Z2],
)
const GAMMA5 = GAMMA[1] * GAMMA[2] * GAMMA[3] * GAMMA[4]
const PLANES = ((1, 2), (1, 3), (1, 4), (2, 3), (2, 4), (3, 4))

"Anti-Hermitian clover field strength F_μν(x) = (Q − Q†)/8 (not traceless)."
function clover_F(U, x, μ, ν)
    Q = line(U, x, ((μ, 1), (ν, 1), (μ, -1), (ν, -1))) +
        line(U, x, ((ν, 1), (μ, -1), (ν, -1), (μ, 1))) +
        line(U, x, ((ν, -1), (μ, 1), (ν, 1), (μ, -1))) +
        line(U, x, ((μ, -1), (ν, -1), (μ, 1), (ν, 1)))
    return (Q - Q') / 8
end

"F_μν at every site for the six planes, to pass to `apply_dirac` as `F`."
clover_fields(U) = [[clover_F(U, x, μ, ν) for (μ, ν) in PLANES] for x in CartesianIndices(lattice_size(U))]

"""
    apply_dirac(U, ψ; κ, r=1.0, cSW=0.0, bc=(1, 1, 1, -1), dagger=false, F=nothing)

D ψ (or D† ψ with `dagger=true`) for the Wilson operator, plus the clover
term when `cSW ≠ 0`. D† has the signs of γ_μ in the hops exchanged; the
clover term is Hermitian. `F` may hold `clover_fields(U)` to avoid
recomputing it.
"""
function apply_dirac(U, ψ; κ, r=1.0, cSW=0.0, bc=(1, 1, 1, -1), dagger=false, F=nothing)
    L = lattice_size(U)
    length(L) == 4 || throw(ArgumentError("four dimensions only"))
    cSW != 0 && F === nothing && (F = clover_fields(U))
    s = dagger ? -1 : 1
    Pfwd = [transpose(r * I - s * GAMMA[μ]) for μ in 1:4]
    Pbwd = [transpose(r * I + s * GAMMA[μ]) for μ in 1:4]
    Gclov = [transpose(GAMMA[μ] * GAMMA[ν]) for (μ, ν) in PLANES]
    out = zeros(ComplexF64, size(ψ))
    for x in CartesianIndices(L)
        acc = Matrix{ComplexF64}(ψ[:, :, x])
        for μ in 1:4
            xf = shift(x, μ, 1, L)
            xb = shift(x, μ, -1, L)
            pf = x[μ] == L[μ] ? bc[μ] : 1
            pb = x[μ] == 1 ? conj(bc[μ]) : 1
            acc -= κ * pf * (U[μ][x] * ψ[:, :, xf]) * Pfwd[μ]
            acc -= κ * pb * (U[μ][xb]' * ψ[:, :, xb]) * Pbwd[μ]
        end
        if cSW != 0
            for k in eachindex(PLANES)
                acc -= κ * cSW * (F[x][k] * ψ[:, :, x]) * Gclov[k]
            end
        end
        out[:, :, x] = acc
    end
    return out
end

"""
    solve_dirac(U, b; tol=1e-12, maxiter=20000, kw...)

Solve D x = b by conjugate gradients on D†D x = D† b (CGNR), with the
operator of `apply_dirac(U, ·; kw...)`. Returns `(x, residual)` with the
true relative residual |D x − b| / |b|.
"""
function solve_dirac(U, b; tol=1e-12, maxiter=20000, kw...)
    F = get(kw, :cSW, 0.0) != 0 ? clover_fields(U) : nothing
    A(v) = apply_dirac(U, apply_dirac(U, v; kw..., F); kw..., F, dagger=true)
    rhs = apply_dirac(U, b; kw..., F, dagger=true)
    x = zero(rhs)
    res = copy(rhs)
    p = copy(res)
    rr = real(dot(res, res))
    target = (tol / 10)^2 * rr
    for _ in 1:maxiter
        Ap = A(p)
        α = rr / real(dot(p, Ap))
        x .+= α .* p
        res .-= α .* Ap
        rrnew = real(dot(res, res))
        rrnew < target && break
        p .= res .+ (rrnew / rr) .* p
        rr = rrnew
    end
    return x, norm(apply_dirac(U, x; kw..., F) - b) / norm(b)
end

"""
    point_propagator(U, x0; kw...)

S(x, x₀) for all x by `solve_dirac` on the 4n point sources at `x0` (a tuple
of site indices). Returns `(S, worst_residual)`.
"""
function point_propagator(U, x0; kw...)
    L = lattice_size(U)
    n = colors(U)
    S = zeros(ComplexF64, n, 4, L..., n, 4)
    worst = 0.0
    for c0 in 1:n, α0 in 1:4
        b = zeros(ComplexF64, n, 4, L...)
        b[c0, α0, x0...] = 1
        sol, res = solve_dirac(U, b; kw...)
        S[:, :, :, :, :, :, c0, α0] = sol
        worst = max(worst, res)
    end
    return S, worst
end

"""
    meson_correlator(S, x0, Γ2, Γ1; momenta=((0, 0, 0),))

Connected local meson correlator (see the module docstring), indexed by
Δ = 0, …, L₄ − 1 (rows) and momentum (columns). A momentum (n₁, n₂, n₃)
means p_k = 2π n_k / L_k.
"""
function meson_correlator(S, x0, Γ2, Γ1; momenta=((0, 0, 0),), coefficient=-1)
    n = size(S, 1)
    L = size(S)[3:6]
    Idn = Matrix{ComplexF64}(I, n, n)
    G2 = kron(Γ2, Idn)
    G1bar = kron(GAMMA[4] * Γ1' * GAMMA[4], Idn)
    G5 = kron(GAMMA5, Idn)
    C = zeros(ComplexF64, L[4], length(momenta))
    for x in CartesianIndices(L)
        Sx = reshape(S[:, :, x, :, :], 4n, 4n)
        Sback = G5 * Sx' * G5
        val = coefficient * tr(G2 * Sx * G1bar * Sback)
        Δ = mod(x[4] - x0[4], L[4]) + 1
        for (m, p) in enumerate(momenta)
            phase = exp(-im * sum(2π * p[k] * (x[k] - x0[k]) / L[k] for k in 1:3))
            C[Δ, m] += phase * val
        end
    end
    return C
end

"Momenta allowed by the boundary phases: p_μ = (2πk + θ_μ)/L_μ, θ = π for bc = −1."
function allowed_momenta(L, bc)
    θ = [bc[μ] == -1 ? π : 0.0 for μ in 1:4]
    return [ntuple(μ -> (2π * (k[μ] - 1) + θ[μ]) / L[μ], 4) for k in CartesianIndices(L)]
end

"Free Wilson operator in momentum space: D(p) = 1 − 2κr Σ cos p_μ + 2iκ Σ γ_μ sin p_μ."
free_dirac_momentum(p, κ; r=1.0) =
    (1 - 2κ * r * sum(cos, p)) * I + 2im * κ * sum(GAMMA[μ] * sin(p[μ]) for μ in 1:4)

"""
    free_spectrum(L, κ; r=1.0, bc=(1, 1, 1, -1), n=3)

Eigenvalues of the free Wilson operator from the momentum-space formula:
1 − 2κr Σ cos p ± 2iκ (Σ sin² p)^{1/2}, each with multiplicity 2n.
"""
function free_spectrum(L, κ; r=1.0, bc=(1, 1, 1, -1), n=3)
    λ = ComplexF64[]
    for p in allowed_momenta(L, bc)
        a = 1 - 2κ * r * sum(cos, p)
        b = 2κ * sqrt(sum(abs2 ∘ sin, p))
        append!(λ, fill(a + im * b, 2n))
        append!(λ, fill(a - im * b, 2n))
    end
    return λ
end

"""
    free_propagator(L, κ, x0; r=1.0, bc=(1, 1, 1, -1), n=3)

S(x, x₀) on unit links by the Fourier sum (1/V) Σ_p e^{ip(x−x₀)} D(p)⁻¹,
an algorithm independent of the position-space solver.
"""
function free_propagator(L, κ, x0; r=1.0, bc=(1, 1, 1, -1), n=3)
    ps = allowed_momenta(L, bc)
    Dinv = [inv(free_dirac_momentum(p, κ; r)) for p in ps]
    V = prod(L)
    S = zeros(ComplexF64, n, 4, L..., n, 4)
    for x in CartesianIndices(L)
        s = zeros(ComplexF64, 4, 4)
        for (p, Di) in zip(ps, Dinv)
            s .+= exp(im * sum(p[μ] * (x[μ] - x0[μ]) for μ in 1:4)) .* Di
        end
        s ./= V
        for c in 1:n
            S[c, :, x, c, :] = s
        end
    end
    return S
end

"Dense matrix of the linear map `f` on arrays of size `sz` (column j = f(e_j))."
function dense_matrix(f, sz)
    N = prod(sz)
    M = zeros(ComplexF64, N, N)
    e = zeros(ComplexF64, sz)
    for j in 1:N
        e[j] = 1
        M[:, j] = vec(f(e))
        e[j] = 0
    end
    return M
end

end # module
