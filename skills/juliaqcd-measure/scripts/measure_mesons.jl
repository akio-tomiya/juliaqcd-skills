# Measure quenched Wilson or Wilson–clover meson correlators on every
# checkpoint of a four-dimensional run written by
# juliaqcd-generate/scripts/hmc_puregauge.jl.
#
#   julia --project=ENV measure_mesons.jl run=runs/su3_b6.0_8x8x8x16 kappa=0.153 csw=0
#
# Required (physics parameters, never defaults):
#   kappa=      hopping parameter κ = 1/(2 m₀ + 8)
#   csw=        clover coefficient; csw=0 for the unimproved Wilson operator
# Optional:
#   channels=pseudoscalar,vector_1,vector_2,vector_3,axial_4
#               any of scalar, pseudoscalar, vector_μ, axial_μ, tensor_μν
#   momenta=0,0,0         momenta n₁,n₂,n₃ (p = 2πn/L), several separated by ';'
#   move_source=true      point source at a different site on each checkpoint
#                         (fixed rule from the trajectory number), which
#                         lowers the autocorrelation; false keeps (1,1,1,1)
#   eps_CG=1e-20          bound on the squared solver residual
#   stride=1              measure every stride-th checkpoint
#   name=                 output folder name; default kappa<κ>_csw<c_SW>
#
# Boundary phases: periodic in space, antiperiodic in time (the only ones
# QCDMeasurements 1.0.1 accepts). Writes RUN/measure/mesons_NAME/:
#   meta.toml     the parameters above; a later call must use the same
#   mesons.csv    traj,channel,n1,n2,n3,dt,re,im   (dt = 0, …, L₄ − 1 from the source)
#   solver.csv    traj,sx,sy,sz,st,residual,seconds
# Checkpoints already in the files are skipped. Run check_fermion.jl first.

import JACC
JACC.@init_backend
using Gaugefields
using Printf
import TOML
include(joinpath(@__DIR__, "measure_common.jl"))
include(joinpath(@__DIR__, "fermion_common.jl"))

function checkpoints(run)
    dir = joinpath(run, "checkpoints")
    files = filter(f -> occursin(r"^conf_\d+\.jld2$", f), readdir(dir))
    trajs = [parse(Int, match(r"\d+", f).match) for f in files]
    p = sortperm(trajs)
    return trajs[p], joinpath.(dir, files[p])
end

measured(path) = isfile(path) ?
    Set(parse(Int, split(l, ',')[1]) for l in readlines(path)[2:end] if !isempty(strip(l))) : Set{Int}()

"""
Source site for trajectory k: a fixed multiplicative hash of k, so that
checkpoints at regular intervals still get well-spread sources.
"""
function source_for(k, L, move)
    move || return (1, 1, 1, 1)
    s = (UInt64(k) * 0x9E3779B97F4A7C15) >> 20
    site = Int[]
    for n in L
        push!(site, 1 + Int(s % UInt64(n)))
        s ÷= UInt64(n)
    end
    return Tuple(site)
end

parse_momenta(s) = [Tuple(parse.(Int, split(strip(m), ','))) for m in split(s, ';')]

function main(args)
    a = parse_args(args)
    for k in ("run", "kappa", "csw")
        haskey(a, k) || error("$k= is required (kappa and csw are physics parameters: ask the user, never guess)")
    end
    run = a["run"]
    meta = TOML.parsefile(joinpath(run, "meta.toml"))
    N = meta["colors"]
    L = Tuple(meta["lattice"])
    length(L) == 4 || error("meson correlators need a four-dimensional lattice; this run is $(length(L))-dimensional")
    κ = parse(Float64, a["kappa"])
    cSW = parse(Float64, a["csw"])
    channels = split(get(a, "channels", "pseudoscalar,vector_1,vector_2,vector_3,axial_4"), ',')
    momenta = parse_momenta(get(a, "momenta", "0,0,0"))
    move = getarg(a, "move_source", true)
    eps_CG = getarg(a, "eps_CG", 1e-20)
    stride = getarg(a, "stride", 1)
    name = get(a, "name", "kappa$(κ)_csw$(cSW)")
    params = Dict("kappa" => κ, "csw" => cSW, "channels" => String.(channels),
        "momenta" => [collect(p) for p in momenta], "move_source" => move,
        "eps_CG" => eps_CG, "boundary_phases" => [1, 1, 1, -1],
        "operator" => cSW == 0 ? "Wilson" : "Wilson-clover")

    out = joinpath(run, "measure", "mesons_" * name)
    mkpath(out)
    metafile = joinpath(out, "meta.toml")
    if isfile(metafile)
        old = TOML.parsefile(metafile)
        for (k, v) in params
            old[k] == v || error("$metafile has $k = $(old[k]) but this call uses $v; " *
                                 "use the same parameters or another name=")
        end
    else
        open(io -> TOML.print(io, params), metafile, "w")
    end
    cfile = joinpath(out, "mesons.csv")
    sfile = joinpath(out, "solver.csv")
    isfile(cfile) || write(cfile, "traj,channel,n1,n2,n3,dt,re,im\n")
    isfile(sfile) || write(sfile, "traj,sx,sy,sz,st,residual,seconds\n")
    done = measured(sfile)

    U = gauge_configuration(L; colors=N, start=:cold, process_grid=(1, 1, 1, 1))
    trajs, files = checkpoints(run)
    sel = 1:stride:length(trajs)
    println("== measure_mesons: ", run, ", SU($N) ", join(L, "x"), ", ", params["operator"],
        " κ = $κ", cSW == 0 ? "" : ", c_SW = $cSW", ", ", length(sel), " checkpoints → ", out)
    for i in sel
        k = trajs[i]
        k in done && continue
        src = source_for(k, L, move)
        t = @elapsed begin
            load_configuration!(U, files[i])
            m = meson_measurement(U; κ, cSW, channels, momenta, source=src, eps_CG)
            r = get_value(measure(m, U))
            res = solver_residual(m)
        end
        open(cfile, "a") do io
            for ch in channels, (j, p) in enumerate(momenta), dt in 0:L[4]-1
                c = r[Symbol(ch)][dt+1, j]
                println(io, k, ',', ch, ',', p[1], ',', p[2], ',', p[3], ',', dt, ',', repr(real(c)), ',', repr(imag(c)))
            end
        end
        open(io -> println(io, k, ',', join(src, ','), ',', repr(res), ',', round(t, digits=2)), sfile, "a")
        @printf("  traj %6d  source %s  residual %.0e  %.1f s\n", k, src, res, t)
        flush(stdout)
    end
    println("done")
end

main(ARGS)
