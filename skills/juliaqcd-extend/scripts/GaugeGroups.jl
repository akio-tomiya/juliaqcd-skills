"""
    GaugeGroups

Reference implementation of compact gauge groups in their defining
representation, used as the oracle when testing production code.

A group is described by data: matrix size, field (real or complex), and the
invariant tensors it preserves. Generators, projection onto the group, Haar
random elements, and the membership test are derived from that data by
generic code, so a new group needs only a few methods (see `run_checks`).

Only the Julia standard library is used. Speed is not a goal.
"""
module GaugeGroups

using LinearAlgebra
using Random

export GaugeGroup, SU, SO, Sp, G2,
    RepKind, ComplexRep, RealRep, PseudoRealRep,
    repkind, frobenius_schur_indicator,
    matrix_size, field_type, algebra_dimension, invariant_tensors,
    generators, constraints, project_algebra, expmap, invariant_bilinear_forms,
    ingroup_residual, project_group, random_element,
    run_checks, print_checks

# ---------------------------------------------------------------------------
# Kinds of representation

abstract type RepKind end
"Complex: the representation is not equivalent to its conjugate. SU(N), N ≥ 3."
struct ComplexRep <: RepKind end
"Real: equivalent to its conjugate through a symmetric form. SO(N), G₂."
struct RealRep <: RepKind end
"Pseudo-real: equivalent to its conjugate through an antisymmetric form. SU(2), Sp(2N)."
struct PseudoRealRep <: RepKind end

"""
    frobenius_schur_indicator(kind)

Haar average of tr(U²) in an irreducible representation: 0 for complex,
+1 for real, -1 for pseudo-real.
"""
frobenius_schur_indicator(::ComplexRep) = 0
frobenius_schur_indicator(::RealRep) = 1
frobenius_schur_indicator(::PseudoRealRep) = -1

# ---------------------------------------------------------------------------
# Groups

abstract type GaugeGroup end

"SU(N) in the fundamental representation, N ≥ 2."
struct SU <: GaugeGroup
    N::Int
    SU(N) = N >= 2 ? new(N) : throw(ArgumentError("SU(N) needs N ≥ 2"))
end

"SO(N) in the vector representation, N ≥ 3."
struct SO <: GaugeGroup
    N::Int
    SO(N) = N >= 3 ? new(N) : throw(ArgumentError("SO(N) needs N ≥ 3"))
end

"""
    Sp(n)

Compact symplectic group USp(n) = Sp(n/2) in its n-dimensional defining
representation. The argument is the matrix size n = 2N, so `Sp(4)` is
USp(4). `Sp(2)` is SU(2).
"""
struct Sp <: GaugeGroup
    n::Int
    Sp(n) = (n >= 2 && iseven(n)) ? new(n) : throw(ArgumentError("Sp(n) needs even n ≥ 2"))
end

"G₂ in its 7-dimensional representation, as the subgroup of SO(7) that fixes a 3-form."
struct G2 <: GaugeGroup end

matrix_size(G::SU) = G.N
matrix_size(G::SO) = G.N
matrix_size(G::Sp) = G.n
matrix_size(::G2) = 7

field_type(::SU) = ComplexF64
field_type(::SO) = Float64
field_type(::Sp) = ComplexF64
field_type(::G2) = Float64

algebra_dimension(G::SU) = G.N^2 - 1
algebra_dimension(G::SO) = G.N * (G.N - 1) ÷ 2
algebra_dimension(G::Sp) = (G.n ÷ 2) * (G.n + 1)
algebra_dimension(::G2) = 14

repkind(G::SU) = G.N == 2 ? PseudoRealRep() : ComplexRep()
repkind(::SO) = RealRep()
repkind(::Sp) = PseudoRealRep()
repkind(::G2) = RealRep()

"""
    invariant_tensors(G)

Named tuple of the tensors that define `G` inside U(n) or O(n).
Recognized keys: `epsilon` (unit determinant), `J` (antisymmetric bilinear
form, Uᵀ J U = J), `phi` (3-form, U ⊗ U ⊗ U φ = φ).
"""
invariant_tensors(::SU) = (epsilon=true,)
invariant_tensors(::SO) = (epsilon=true,)
invariant_tensors(G::Sp) = (J=symplectic_form(G.n),)
invariant_tensors(::G2) = (phi=g2_phi(),)

function symplectic_form(n)
    N = n ÷ 2
    J = zeros(n, n)
    J[1:N, N+1:n] = I(N)
    J[N+1:n, 1:N] = -I(N)
    return J
end

# The 3-form whose stabilizer in SO(7) is G₂, from the multiplication table of
# the imaginary octonions: φ = e¹²³ + e¹⁴⁵ + e¹⁶⁷ + e²⁴⁶ − e²⁵⁷ − e³⁴⁷ − e³⁵⁶.
const G2_TERMS = ((1, 2, 3, 1), (1, 4, 5, 1), (1, 6, 7, 1), (2, 4, 6, 1),
    (2, 5, 7, -1), (3, 4, 7, -1), (3, 5, 6, -1))

function g2_phi(terms=G2_TERMS)
    φ = zeros(7, 7, 7)
    for (i, j, k, s) in terms
        for (a, b, c, p) in ((i, j, k, 1), (j, k, i, 1), (k, i, j, 1),
            (j, i, k, -1), (i, k, j, -1), (k, j, i, -1))
            φ[a, b, c] = s * p
        end
    end
    return φ
end

# (U ⊗ U ⊗ U) φ
function transform3(U, φ)
    n = size(U, 1)
    t1 = similar(φ, promote_type(eltype(U), eltype(φ)))
    t2 = similar(t1)
    t3 = similar(t1)
    for c in 1:n, b in 1:n
        t1[:, b, c] = U * φ[:, b, c]
    end
    for c in 1:n, a in 1:n
        t2[a, :, c] = U * t1[a, :, c]
    end
    for b in 1:n, a in 1:n
        t3[a, b, :] = U * t2[a, b, :]
    end
    return t3
end

# Infinitesimal version: d/dε (e^{εX} ⊗ e^{εX} ⊗ e^{εX}) φ at ε = 0
function act3(X, φ)
    n = size(X, 1)
    R = zeros(promote_type(eltype(X), eltype(φ)), n, n, n)
    for k in 1:n, j in 1:n, i in 1:n
        s = zero(eltype(R))
        for a in 1:n
            s += X[i, a] * φ[a, j, k] + X[j, a] * φ[i, a, k] + X[k, a] * φ[i, j, a]
        end
        R[i, j, k] = s
    end
    return R
end

# ---------------------------------------------------------------------------
# Lie algebra

"""
    constraints(G, X)

Real numbers that all vanish exactly when the anti-Hermitian (or real
antisymmetric) matrix `X` lies in the Lie algebra of `G`.
"""
function constraints(G::GaugeGroup, X)
    inv = invariant_tensors(G)
    c = Float64[]
    if haskey(inv, :epsilon)
        push!(c, imag(tr(X)))
    end
    if haskey(inv, :J)
        J = inv.J
        A = transpose(X) * J + J * X
        append!(c, real.(vec(A)), imag.(vec(A)))
    end
    if haskey(inv, :phi)
        R = act3(X, inv.phi)
        append!(c, real.(vec(R)), imag.(vec(R)))
    end
    return c
end

# Real basis of anti-Hermitian (complex) or antisymmetric (real) n×n matrices
function skew_basis(::Type{T}, n) where {T}
    B = Matrix{T}[]
    for i in 1:n, j in i+1:n
        E = zeros(T, n, n)
        E[i, j] = 1
        E[j, i] = -1
        push!(B, E)
        if T <: Complex
            E = zeros(T, n, n)
            E[i, j] = im
            E[j, i] = im
            push!(B, E)
        end
    end
    if T <: Complex
        for i in 1:n
            E = zeros(T, n, n)
            E[i, i] = im
            push!(B, E)
        end
    end
    return B
end

inner(A, B) = real(tr(A' * B))

const GENERATOR_CACHE = Dict{Any,Any}()

"""
    generators(G)

Basis T_a of the Lie algebra of `G` as anti-Hermitian matrices, normalized
as Re tr(T_a† T_b) = δ_ab / 2. Computed as the null space of `constraints`,
so it is correct whenever `invariant_tensors` is.
"""
generators(G::GaugeGroup) = get!(() -> compute_generators(G), GENERATOR_CACHE, G)

function compute_generators(G::GaugeGroup)
    T = field_type(G)
    n = matrix_size(G)
    B = skew_basis(T, n)
    C = reduce(hcat, [constraints(G, b) for b in B])
    coeffs = size(C, 1) == 0 ? Matrix{Float64}(I, length(B), length(B)) : nullspace(C)
    raw = [sum(coeffs[i, a] * B[i] for i in eachindex(B)) for a in axes(coeffs, 2)]
    gens = Matrix{T}[]
    for A in raw                      # Gram–Schmidt for Re tr(A†B)
        for Q in gens
            A = A - 2 * inner(Q, A) * Q
        end
        nrm = sqrt(inner(A, A))
        nrm > 1e-10 && push!(gens, A / (sqrt(2) * nrm))
    end
    return gens
end

"Orthogonal projection of any n×n matrix onto the Lie algebra."
function project_algebra(G::GaugeGroup, X)
    gens = generators(G)
    return sum(2 * inner(Ta, X) * Ta for Ta in gens)
end

"Exponential map from the Lie algebra to the group."
expmap(::GaugeGroup, X) = exp(X)

"""
    invariant_bilinear_forms(G)

Basis of the bilinear forms B with Uᵀ B U = B for all U in `G`, found as the
null space of Tₐᵀ B + B Tₐ = 0 over the generators, and the symmetry of each
(`:symmetric`, `:antisymmetric`, or `:mixed`). For an irreducible
representation this decides the kind exactly, independently of `repkind`:
no form for complex, one symmetric form for real, one antisymmetric form for
pseudo-real.
"""
function invariant_bilinear_forms(G::GaugeGroup)
    n = matrix_size(G)
    Id = Matrix{ComplexF64}(I, n, n)
    A = reduce(vcat, [kron(Id, transpose(T)) + kron(transpose(T), Id) for T in generators(G)])
    basis = nullspace(A)
    forms = [reshape(basis[:, k], n, n) for k in axes(basis, 2)]
    kind(B) = norm(B - transpose(B)) < 1e-8 * norm(B) ? :symmetric :
              norm(B + transpose(B)) < 1e-8 * norm(B) ? :antisymmetric : :mixed
    return [(form=B, symmetry=kind(B)) for B in forms]
end

expected_forms(::ComplexRep) = Symbol[]
expected_forms(::RealRep) = [:symmetric]
expected_forms(::PseudoRealRep) = [:antisymmetric]

# ---------------------------------------------------------------------------
# Group membership and projection

"""
    ingroup_residual(G, U)

Named tuple of residuals, each zero for an exact element of `G`:
unitarity, determinant, realness, and each invariant tensor.
"""
function ingroup_residual(G::GaugeGroup, U)
    n = matrix_size(G)
    inv = invariant_tensors(G)
    unitarity = opnorm(U' * U - I)
    determinant = haskey(inv, :epsilon) ? abs(det(U) - 1) : 0.0
    realness = field_type(G) <: Real ? maximum(abs, imag.(U)) : 0.0
    symplectic = haskey(inv, :J) ? opnorm(transpose(U) * inv.J * U - inv.J) : 0.0
    threeform = haskey(inv, :phi) ? maximum(abs, transform3(U, inv.phi) - inv.phi) : 0.0
    return (; unitarity, determinant, realness, symplectic, threeform)
end

polar(M) = (F = svd(M); F.U * F.Vt)

"""
    initial_guess(G, W)

Element of `G` near the unitary matrix `W`, used to start `project_group`.
The default is exp of the projected principal logarithm. This is exact when
the principal logarithm of a group element lies in the Lie algebra, which
holds for groups cut out by real or symplectic structure (SO, Sp, G₂) but not
for SU(N), N ≥ 3: there tr log U = 2πi m can be nonzero, and dropping the
trace lands on U times a center element, a stationary point of the Newton
iteration.
"""
initial_guess(G::GaugeGroup, W) = expmap(G, project_algebra(G, log(W)))

# SU(N): divide out the determinant, choosing the N-th root that keeps g
# closest to W.
function initial_guess(G::SU, W)
    N = G.N
    r = det(W)^(1 / N)
    roots = (r * cis(2π * k / N) for k in 0:N-1)
    best = argmax(z -> real(tr(W' * (W / z))), collect(roots))
    return W / best
end

"""
    project_group(G, M)

Element of `G` nearest to `M` in the Frobenius norm, for `M` near the group.
Starts from `initial_guess` at the unitary polar factor, then maximizes
Re tr(g† M) by steps g ← g exp(η P(g† M)). The step η starts at 1 (a Newton
step near the maximum) and is halved until Re tr(g† M) does not decrease.

A poor starting point can sit exactly on a saddle, where the gradient
vanishes. This happens for real groups when U has a pair of eigenvalues -1:
the principal logarithm is complex, and the start g satisfies g†U = an
involution. After convergence the iterate is therefore kicked in a few
random directions, and the ascent restarts whenever a kick finds a higher
value.
"""
function project_group(G::GaugeGroup, M; maxiter=500, tol=1e-14, kicks=4)
    n = matrix_size(G)
    T = field_type(G)
    Mn = M * (sqrt(n) / norm(M))
    f(g) = real(tr(g' * Mn))
    # `local`: without it, assigning here would overwrite the outer `fg`
    # captured by this closure, and the kick test below would never see an
    # improvement.
    function ascend(g)
        local fcur = f(g)
        for _ in 1:maxiter
            Y = project_algebra(G, g' * Mn)
            norm(Y) < tol && break
            η = 1.0
            while true
                gn = g * expmap(G, η * Y)
                fn = f(gn)
                if fn >= fcur - 1e-14 || η < 1e-6
                    g, fcur = gn, fn
                    break
                end
                η /= 2
            end
        end
        return g, fcur
    end
    rng = Xoshiro(0)
    gens = generators(G)
    g, fg = ascend(initial_guess(G, polar(Mn)))
    improved = true
    while improved
        improved = false
        for _ in 1:kicks
            kick = expmap(G, sum(1e-2 * randn(rng) * Ta for Ta in gens))
            gk, fk = ascend(g * kick)
            if fk > fg + 1e-12
                g, fg = gk, fk
                improved = true
                break
            end
        end
    end
    return T <: Real ? real.(g) : Matrix{T}(g)
end

# ---------------------------------------------------------------------------
# Haar random elements

"""
    random_element(rng, G)

Haar-distributed element of `G`. SU(N) and SO(N) use the QR decomposition of
a Gaussian matrix, which is exactly Haar. Other groups use a random walk
exp(X₁)⋯exp(X_K) with Gaussian X_k in the Lie algebra. The walk converges to
Haar measure exponentially in K on a compact connected group, but the number
of steps (40 at width 1.5) is a choice, validated only by the moment checks
in `run_checks` (⟨tr U⟩, ⟨|tr U|²⟩, ⟨tr U²⟩). Use more steps if a result
depends on higher moments.
"""
random_element(rng::AbstractRNG, G::GaugeGroup) = random_walk(rng, G)

function random_walk(rng, G; steps=40, width=1.5)
    T = field_type(G)
    gens = generators(G)
    U = Matrix{T}(I, matrix_size(G), matrix_size(G))
    for _ in 1:steps
        X = sum(width * randn(rng) * Ta for Ta in gens)
        U = U * expmap(G, X)
    end
    return U
end

function random_element(rng::AbstractRNG, G::SU)
    N = G.N
    Z = randn(rng, ComplexF64, N, N)
    F = qr(Z)
    Q = Matrix(F.Q) * Diagonal(sign.(diag(F.R)))
    return Q / det(Q)^(1 / N)
end

function random_element(rng::AbstractRNG, G::SO)
    N = G.N
    Z = randn(rng, N, N)
    F = qr(Z)
    Q = Matrix(F.Q) * Diagonal(sign.(diag(F.R)))
    if det(Q) < 0
        Q[:, 1] .*= -1
    end
    return Q
end

# ---------------------------------------------------------------------------
# Checks

struct CheckResult
    name::String
    value::Float64
    tolerance::Float64
    passed::Bool
end

check(name, value, tol) = CheckResult(name, value, tol, abs(value) <= tol)

maxres(r::NamedTuple) = maximum(values(r))

"""
    run_checks(G; rng=Xoshiro(1234), nsamples=20000)

Run every check on `G` and return a vector of results. A new group type must
define `matrix_size`, `field_type`, `algebra_dimension`, `repkind`, and
`invariant_tensors`; the rest is generic. The checks are:

- generators: count, normalization, anti-Hermiticity, constraints, closure
  under the commutator;
- exponential map, products, and inverses stay in the group;
- projection: in the group, idempotent, nearest point, stable under
  perturbation;
- invariant bilinear forms: found exactly from the generators and compared
  with `repkind(G)` (none, one symmetric, or one antisymmetric);
- Haar random elements: in the group, E[tr U] = 0, E[|tr U|²] = 1, and
  E[tr U²] equal to the Frobenius–Schur indicator of `repkind(G)`.

The two kind checks are independent: the forms come from the Lie algebra
alone, the indicator from Monte Carlo over the group. To determine the kind
of a group without trusting the declaration, read the forms line and the
measured mean on the indicator line, not only PASS.
"""
function run_checks(G::GaugeGroup; rng=Xoshiro(1234), nsamples=20000)
    T = field_type(G)
    n = matrix_size(G)
    gens = generators(G)
    results = CheckResult[]
    tol = 1e-10

    push!(results, CheckResult("algebra dimension = $(algebra_dimension(G))",
        length(gens), algebra_dimension(G), length(gens) == algebra_dimension(G)))
    gram = [inner(A, B) for A in gens, B in gens]
    push!(results, check("generators orthonormal, Re tr(Ta† Tb) = δab/2",
        isempty(gens) ? 1.0 : maximum(abs, gram - I / 2), tol))
    push!(results, check("generators anti-Hermitian",
        maximum(opnorm(A + A') for A in gens), tol))
    push!(results, check("generators satisfy the constraints",
        maximum(maximum(abs, constraints(G, A); init=0.0) for A in gens), tol))
    push!(results, check("algebra closed under [Ta, Tb]",
        maximum(norm((A * B - B * A) - project_algebra(G, A * B - B * A)) for A in gens, B in gens), tol))

    forms = invariant_bilinear_forms(G)
    found = sort([f.symmetry for f in forms])
    push!(results, CheckResult("invariant bilinear forms: $(isempty(found) ? "none" : join(found, ", ")) " *
                               "(declared $(nameof(typeof(repkind(G)))))",
        length(found), length(expected_forms(repkind(G))), found == expected_forms(repkind(G))))

    rand_alg(scale) = sum(scale * randn(rng) * Ta for Ta in gens)
    push!(results, check("exp(algebra) in group",
        maximum(maxres(ingroup_residual(G, expmap(G, rand_alg(2.0)))) for _ in 1:20), tol))

    samples = [random_element(rng, G) for _ in 1:nsamples]
    push!(results, check("random elements in group",
        maximum(maxres(ingroup_residual(G, U)) for U in samples[1:min(200, end)]), tol))
    push!(results, check("products and inverses in group",
        maximum(max(maxres(ingroup_residual(G, samples[i] * samples[i+1])),
            maxres(ingroup_residual(G, inv(samples[i])))) for i in 1:20), tol))

    # Haar samples rarely have clustered eigenvalues (they repel), so the
    # projection is also tested on exp(X) with large X, where eigenvalues can
    # sit anywhere, including near -1 or near a center element.
    hard = vcat(samples[1:20], [expmap(G, rand_alg(s)) for s in (1.0, 2.0, 3.0, 4.0, 6.0) for _ in 1:12])
    push!(results, check("projection idempotent on group elements",
        maximum(norm(project_group(G, U) - U) for U in hard), 1e-9))
    eps = 1e-4
    perturbed = [(U, U + eps * randn(rng, T, n, n)) for U in hard]
    projected = [(U, M, project_group(G, M)) for (U, M) in perturbed]
    push!(results, check("projection of a perturbed element lands in group",
        maximum(maxres(ingroup_residual(G, P)) for (_, _, P) in projected), tol))
    push!(results, check("projection is nearest (|P(M) - M| <= |U - M|)",
        maximum(max(0.0, norm(P - M) - norm(U - M)) for (U, M, P) in projected), 1e-12))
    # The move P(M) - U is the tangent part of M - U, so its norm cannot
    # exceed |M - U| beyond curvature corrections of relative size O(eps).
    push!(results, check("projection: |P(M) - U| / |M - U| <= 1 + O(eps)",
        maximum(max(0.0, norm(P - U) / norm(M - U) - 1) for (U, M, P) in projected), 1e-2))

    t1 = [tr(U) for U in samples]
    t2 = [tr(U * U) for U in samples]
    nu = frobenius_schur_indicator(repkind(G))
    for (name, data, target) in (
        ("Haar: Re E[tr U] = 0", real.(t1), 0.0),
        ("Haar: Im E[tr U] = 0", imag.(t1), 0.0),
        ("Haar: E[|tr U|^2] = 1", abs2.(t1), 1.0),
        ("Haar: E[tr U^2] = $nu ($(nameof(typeof(repkind(G)))))", real.(t2), Float64(nu)))
        m = sum(data) / length(data)
        se = sqrt(max(sum(abs2, data .- m) / (length(data) - 1), 1e-30) / length(data))
        push!(results, CheckResult(name * "  [mean $(round(m; digits=4)) ± $(round(se; digits=4))]",
            abs(m - target) / se, 5.0, abs(m - target) <= 5se))
    end
    return results
end

function print_checks(io::IO, G, results)
    println(io, "== ", G, "  (n = ", matrix_size(G), ", ", field_type(G), ", ",
        nameof(typeof(repkind(G))), ")")
    for r in results
        status = r.passed ? "PASS" : "FAIL"
        println(io, "  ", status, "  ", rpad(r.name, 72), "  ", round(r.value; sigdigits=3),
            "  (tol ", r.tolerance, ")")
    end
    return all(r -> r.passed, results)
end
print_checks(G, results) = print_checks(stdout, G, results)

end # module
