# Measure Wilson loops and the gradient flow on every checkpoint of a run
# written by juliaqcd-generate/scripts/hmc_puregauge.jl.
#
#   julia --project=ENV measure_ensemble.jl run=runs/su3_b6.0_8x8x8x8
#
# Optional:
#   rmax=, tmax=     largest R (spatial) and T (last direction) of W(R,T);
#                    default half the extent
#   flow_step=0.01   flow step ε
#   flow_tmax=       largest flow time t/a²; default L²/32 (√(8t) = L/2) with
#                    L the smallest extent
#   flow_every=4     measure every this many flow steps
#   stride=1         measure every stride-th checkpoint
#   wilson=true, flow=true   turn either part off
#
# Writes RUN/measure/:
#   meta.toml          the parameters above; a later call must use the same
#   wilson_loops.csv   traj,R,T,W
#   flow.csv           traj,t,E_plaq[,E_clover,Q_clover,Q_improved]  (the last
#                      three in four dimensions only)
# Checkpoints already in the files are skipped, so the script can be run again
# while the chain continues. Run check_measure.jl first, with the same group and
# dimension.

import JACC
JACC.@init_backend
using Gaugefields
using Printf
import TOML
include(joinpath(@__DIR__, "measure_common.jl"))

function checkpoints(run)
    dir = joinpath(run, "checkpoints")
    files = filter(f -> occursin(r"^conf_\d+\.jld2$", f), readdir(dir))
    trajs = [parse(Int, match(r"\d+", f).match) for f in files]
    p = sortperm(trajs)
    return trajs[p], joinpath.(dir, files[p])
end

measured(path) = isfile(path) ?
    Set(parse(Int, split(l, ',')[1]) for l in readlines(path)[2:end] if !isempty(strip(l))) : Set{Int}()

function main(args)
    a = parse_args(args)
    check_keys(a, ("run", "rmax", "tmax", "flow_step", "flow_tmax", "flow_every", "wilson", "flow", "stride"))
    haskey(a, "run") || error("run=RUN_DIR is required")
    run = a["run"]
    meta = TOML.parsefile(joinpath(run, "meta.toml"))
    N = meta["colors"]
    L = Tuple(meta["lattice"])
    d = length(L)
    params = Dict(
        "rmax" => getarg(a, "rmax", minimum(L[1:d-1]) ÷ 2),
        "tmax" => getarg(a, "tmax", L[d] ÷ 2),
        "flow_step" => getarg(a, "flow_step", 0.01),
        "flow_tmax" => getarg(a, "flow_tmax", minimum(L)^2 / 32),
        "flow_every" => getarg(a, "flow_every", 4),
        "wilson" => getarg(a, "wilson", true),
        "flow" => getarg(a, "flow", true))
    stride = getarg(a, "stride", 1)
    steps = params["flow_every"] * ceil(Int, params["flow_tmax"] / (params["flow_step"] * params["flow_every"]))

    out = joinpath(run, "measure")
    mkpath(out)
    metafile = joinpath(out, "meta.toml")
    if isfile(metafile)
        old = TOML.parsefile(metafile)
        for (k, v) in params
            old[k] == v || error("measure/meta.toml has $k = $(old[k]) but this call uses $v; " *
                                 "use the same parameters or a new run directory")
        end
    else
        open(io -> TOML.print(io, params), metafile, "w")
    end

    U = gauge_configuration(L; colors=N, start=:cold, process_grid=ntuple(_ -> 1, d))
    wm = WilsonLoops(U, params["rmax"], params["tmax"])
    fm = FlowMeasurement(U; step_size=params["flow_step"], steps, every=params["flow_every"])

    wfile = joinpath(out, "wilson_loops.csv")
    ffile = joinpath(out, "flow.csv")
    params["wilson"] && !isfile(wfile) && write(wfile, "traj,R,T,W\n")
    params["flow"] && !isfile(ffile) &&
        write(ffile, d == 4 ? "traj,t,E_plaq,E_clover,Q_clover,Q_improved\n" : "traj,t,E_plaq\n")
    done_w = measured(wfile)
    done_f = measured(ffile)

    trajs, files = checkpoints(run)
    sel = 1:stride:length(trajs)
    println("== measure_ensemble: ", run, ", SU($N) ", join(L, "x"), ", ", length(sel),
        " checkpoints, flow to t = ", steps * params["flow_step"])
    for i in sel
        k = trajs[i]
        need_w = params["wilson"] && !(k in done_w)
        need_f = params["flow"] && !(k in done_f)
        (need_w || need_f) || continue
        t = @elapsed begin
            load_configuration!(U, files[i])
            if need_w
                W = measure_wilson_loops(wm, U)
                open(wfile, "a") do io
                    for R in axes(W, 1), T in axes(W, 2)
                        println(io, k, ',', R, ',', T, ',', repr(W[R, T]))
                    end
                end
            end
            if need_f
                r = measure_flow(fm, U)
                open(ffile, "a") do io
                    for j in eachindex(r.t)
                        cols = d == 4 ? (r.t[j], r.E_plaq[j], r.E_clover[j], r.Q_clover[j], r.Q_improved[j]) :
                               (r.t[j], r.E_plaq[j])
                        println(io, k, ',', join(repr.(cols), ','))
                    end
                end
            end
        end
        @printf("  traj %6d  %.1f s\n", k, t)
        flush(stdout)
    end
    println("done")
end

main(ARGS)
