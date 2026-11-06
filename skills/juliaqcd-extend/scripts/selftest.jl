# Self-test of the group checks.
#
#   julia selftest.jl
#
# Every built-in group must pass every check, and every deliberately broken
# group below must fail the check named next to it. A check that cannot fail
# proves nothing, so the second half matters as much as the first.

include(joinpath(@__DIR__, "GaugeGroups.jl"))
using .GaugeGroups
using LinearAlgebra
using Random

const GG = GaugeGroups

# A wrapper that behaves like `base` except for the methods overridden below.
struct Mutant{Tag,G<:GaugeGroup} <: GaugeGroup
    base::G
end
Mutant{Tag}(base::G) where {Tag,G} = Mutant{Tag,G}(base)
Base.show(io::IO, m::Mutant{Tag}) where {Tag} = print(io, "Mutant{:", Tag, "}(", m.base, ")")

for f in (:matrix_size, :field_type, :algebra_dimension, :repkind, :invariant_tensors)
    @eval GG.$f(m::Mutant) = GG.$f(m.base)
end
GG.initial_guess(m::Mutant, W) = GG.initial_guess(m.base, W)

# 1. SU(2) declared as complex instead of pseudo-real.
GG.repkind(::Mutant{:wrong_kind}) = ComplexRep()

# 2. G₂ with one sign of the 3-form flipped: the stabilizer is no longer G₂.
GG.invariant_tensors(::Mutant{:bad_phi}) =
    (phi=GG.g2_phi(((1, 2, 3, 1), (1, 4, 5, 1), (1, 6, 7, 1), (2, 4, 6, 1),
        (2, 5, 7, 1), (3, 4, 7, -1), (3, 5, 6, -1))),)

# 3. SU(3) projection by the unitary polar factor alone (no determinant fix).
GG.project_group(::Mutant{:polar_only}, M; kwargs...) = GG.polar(M)

# 4. SU(3) projection that drops the trace of log U and never kicks the iterate
#    off a stationary point (the center-element trap).
GG.initial_guess(m::Mutant{:log_trap}, W) = GG.expmap(m, GG.project_algebra(m, log(W)))
GG.project_group(m::Mutant{:log_trap}, M; kwargs...) =
    invoke(GG.project_group, Tuple{GaugeGroup,Any}, m, M; kicks=0)

# 5. G₂ random elements from a walk that is far too short to reach Haar measure.
GG.random_element(rng::AbstractRNG, m::Mutant{:short_walk}) =
    GG.random_walk(rng, m; steps=1, width=0.3)

# 6. SO(3) random elements that are uniform on O(3), half of them with det = -1.
#    (The bare Q of a QR decomposition always has det = +1 here, so the sign
#    fix is what spreads it over O(3).)
function GG.random_element(rng::AbstractRNG, ::Mutant{:orthogonal_not_special})
    F = qr(randn(rng, 3, 3))
    return Matrix(F.Q) * Diagonal(sign.(diag(F.R)))
end

const MUST_PASS = [SU(2), SU(3), SU(4), SO(3), SO(4), SO(5), Sp(4), Sp(6), G2()]

const MUST_FAIL = [
    (Mutant{:wrong_kind}(SU(2)), "Haar: E[tr U^2]"),
    (Mutant{:bad_phi}(G2()), "algebra dimension"),
    (Mutant{:polar_only}(SU(3)), "projection of a perturbed element lands in group"),
    (Mutant{:log_trap}(SU(3)), "projection idempotent"),
    (Mutant{:short_walk}(G2()), "Haar: Re E[tr U]"),
    (Mutant{:orthogonal_not_special}(SO(3)), "random elements in group"),
]

function main()
    ok = true
    println("--- groups that must pass every check")
    for G in MUST_PASS
        passed = print_checks(G, run_checks(G))
        ok &= passed
    end
    println("\n--- broken groups that must fail the named check")
    for (G, name) in MUST_FAIL
        results = run_checks(G; nsamples=5000)
        hit = filter(r -> startswith(r.name, name), results)
        caught = !isempty(hit) && any(r -> !r.passed, hit)
        println("  ", caught ? "CAUGHT " : "MISSED ", rpad(string(G), 44), " by \"", name, "\"")
        ok &= caught
    end
    println(ok ? "\nSELFTEST PASS" : "\nSELFTEST FAIL")
    return ok
end

exit(main() ? 0 : 1)
