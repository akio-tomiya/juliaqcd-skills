# Helpers shared by the generation scripts. Load after Gaugefields.

using Gaugefields
using StableRNGs
import JLD2

"Parse `key=value` command-line arguments into a Dict."
function parse_args(args)
    d = Dict{String,String}()
    for a in args
        k, v = split(a, '='; limit=2)
        d[k] = v
    end
    return d
end

getarg(d, key, default) = haskey(d, key) ? convert_arg(default, d[key]) : default
convert_arg(::Int, s) = parse(Int, s)
convert_arg(::Float64, s) = parse(Float64, s)
convert_arg(::Bool, s) = parse(Bool, s)
convert_arg(::String, s) = String(s)
convert_arg(::Symbol, s) = Symbol(s)
convert_arg(::NTuple{N,Int}, s) where {N} = Tuple(parse.(Int, split(s, ',')))
convert_arg(::Tuple{}, s) = Tuple(parse.(Int, split(s, ',')))

"""
    wilson_action(U, beta)

Wilson plaquette action S = β Σ_P (1 - Re tr P / N), up to a constant.
In Gaugefields the plaquettes and their adjoints are pushed with coefficient
β/2 and the MD potential is -Re(evaluate_GaugeAction)/N.
"""
function wilson_action(U, beta)
    action = GaugeAction(U)
    loops = make_loops_fromname("plaquette", Dim=length(U))
    append!(loops, loops')
    push!(action, beta / 2, loops)
    return action
end

"""
    metropolis_uniform(seed, trajectory)

Uniform random number for the accept/reject step of `trajectory`. It depends
only on (seed, trajectory), so a restarted run draws the same numbers without
saving any random-number state.
"""
metropolis_uniform(seed, trajectory) = rand(StableRNG(UInt64(seed) * 0x0000_0000_000f_4243 + UInt64(trajectory)))

"Momentum seed derived from the run seed, distinct from the hot-start seed."
momentum_seed(seed) = seed + 1

"""
    hmc_trajectory!(U, p, old_U, md, seed, trajectory; sigma=1.0)

One HMC trajectory: refresh momenta, integrate, accept or reject.
`sigma` must match the driver's `momentum_denominator` (1 ↔ 1, √2 ↔ 2).
"""
function hmc_trajectory!(U, p, old_U, md, seed, trajectory; sigma=1.0)
    gaussian_momenta!(p; sigma, seed=momentum_seed(seed), sweep=trajectory)
    copy_configuration!(old_U, U)
    result = md_trajectory!(U, p, md)
    dH = result.delta_hamiltonian
    accepted = log(metropolis_uniform(seed, trajectory)) < min(0, -dH)
    accepted || copy_configuration!(U, old_U)
    return (; dH, accepted)
end

"Gauge links as plain host arrays, through the portable JLD2 checkpoint."
function host_links(U, path)
    save_configuration(path, U)
    return JLD2.load(path, "links")
end
