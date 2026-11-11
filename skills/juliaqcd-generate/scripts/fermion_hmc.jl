# Helpers for HMC with two flavors of Wilson or Wilson–clover fermions,
# optionally on stout-smeared links (JuliaQCD v1: LatticeDiracOperators and
# Gaugefields). Load after common.jl. Four dimensions only.
#
# Conventions (LatticeDiracOperators 1.1):
#   D = 1 − κ H − κ c_SW Σ_{μ<ν} γ_μγ_ν F_μν   (c_SW = 0: plain Wilson)
#   fermion boundary phases (1, 1, 1, −1)
#   S_F = φ† (D[V]† D[V])⁻¹ φ, with V the links the fermions see
#   heat bath: φ = D[V]† ξ, ξ complex Gaussian with ⟨|ξ_i|²⟩ = 1, so S_F = |ξ|²
#   stout: V = n steps of V ← exp(ρ Z) V, Z = −TA(V_μ(x) Σ staples), all
#   links smeared, gauge action on the thin links

using LatticeDiracOperators
using LinearAlgebra

const LM = Gaugefields.LatticeMatrices

"Parameters for `Dirac_operator`: Wilson when `csw == 0`, Wilson–clover otherwise."
wilson_dirac_params(; kappa, csw, eps_cg) = Dict{String,Any}(
    "Dirac_operator" => csw == 0 ? "Wilson" : "WilsonClover",
    "κ" => kappa, "cSW" => csw, "eps_CG" => eps_cg, "MaxCGstep" => 20000,
    "verbose_level" => 0)

"""
    fermion_setup(U; kappa, csw, rho=0.0, smear_iterations=1, eps_cg=1e-14,
                  force_kappa=kappa, force_rho=rho)

The fermion part of the HMC: the action, the pseudofermion φ, and the MD
provider. With `rho > 0` the fermions see stout-smeared links and the force
is pulled back to the thin links (`SmearedFermiAction`). `force_kappa` and
`force_rho` exist only for the deliberately broken variants of the checks.
"""
function fermion_setup(U; kappa, csw, rho=0.0, smear_iterations=1, eps_cg=1e-14,
    force_kappa=kappa, force_rho=rho)
    x = Initialize_pseudofermion_fields(U[1], "Wilson")
    fa = FermiAction(Dirac_operator(U, x, wilson_dirac_params(; kappa, csw, eps_cg)), Dict{String,Any}())
    phi = similar(x)
    noise = similar(x)
    smearing = rho > 0 ? Gaugefields.StoutSmearing(; rho, iterations=smear_iterations) : nothing
    provider = md_provider(fa, phi, smearing)
    if force_kappa != kappa || force_rho != rho
        fa_f = FermiAction(Dirac_operator(U, x, wilson_dirac_params(; kappa=force_kappa, csw, eps_cg)), Dict{String,Any}())
        sm_f = force_rho > 0 ? Gaugefields.StoutSmearing(; rho=force_rho, iterations=smear_iterations) : nothing
        provider = MismatchedForce(provider, md_provider(fa_f, phi, sm_f))
    end
    cache = smearing === nothing ? nothing : Gaugefields.LinkSmearingCache(U, smearing)
    Us = smearing === nothing ? nothing : similar(U)
    return (; fa, phi, noise, smearing, cache, Us, provider, kappa, csw, rho, smear_iterations)
end

md_provider(fa, phi, ::Nothing) = PseudofermionMDAction(fa, phi)
md_provider(fa, phi, smearing) = LatticeDiracOperators.SmearedFermiAction(fa, phi, smearing)

"Potential from one provider, force from another: a broken variant for the self-tests."
struct MismatchedForce{A,B}
    potential::A
    force::B
end
Gaugefields.md_action_workspace(a::MismatchedForce, U) =
    (Gaugefields.md_action_workspace(a.potential, U), Gaugefields.md_action_workspace(a.force, U))
Gaugefields.md_potential(a::MismatchedForce, U, ws) = Gaugefields.md_potential(a.potential, U, ws[1])
Gaugefields.md_force!(F, a::MismatchedForce, U, ws) = Gaugefields.md_force!(F, a.force, U, ws[2])

"The links the fermions see: `U` itself, or its stout smearing."
fermion_links!(f, U) = f.smearing === nothing ? U : (Gaugefields.link_smear!(f.Us, U, f.cache); f.Us)

pseudofermion_seed(seed) = UInt64(seed) + 2

"""
    refresh_phi!(f, U, seed, trajectory)

Heat bath φ = D[V]† ξ. ξ depends only on (seed, trajectory), so a restarted
run draws the same pseudofermions. Returns |ξ|².
"""
function refresh_phi!(f, U, seed, trajectory)
    V = fermion_links!(f, U)
    gauss_sampling_in_action!(f.noise, V, f.fa; seed=pseudofermion_seed(seed), sweep=trajectory, subgroup=1)
    sample_pseudofermions!(f.phi, V, f.fa, f.noise)
    f.provider isa PseudofermionMDAction && reset_trajectory_state!(f.provider)
    return real(dot(f.noise, f.noise))
end

"S_F = φ† (D†D)⁻¹ φ on the current links."
fermion_action_value(f, U) = evaluate_FermiAction(f.fa, fermion_links!(f, U), f.phi)

"MD driver: Sexton–Weingarten, fermion force on the outer steps, gauge force `n_fast` times inside."
make_fermion_md(U, beta, f; steps, n_fast=4, tau=1.0) =
    md_driver(U, MDActionSet(; gauge=wilson_action(U, beta), fermion=f.provider);
        steps, trajectory_length=tau, integrator=SextonWeingarten(; slow=:fermion, fast=:gauge, n_fast))

"One HMC trajectory with a fresh pseudofermion. Returns (dH, accepted, xi2)."
function fermion_hmc_trajectory!(U, p, old_U, md, f, seed, trajectory)
    xi2 = refresh_phi!(f, U, seed, trajectory)
    r = hmc_trajectory!(U, p, old_U, md, seed, trajectory)
    return (; r.dH, r.accepted, xi2)
end

"Interior of a v1 Wilson field as an array ψ[c, α, x, y, z, t]."
function fermion_array(x)
    nw = x.f.nw
    return Array(x.f.A)[:, :, (nw+1:nw+n for n in (x.NX, x.NY, x.NZ, x.NT))...]
end
