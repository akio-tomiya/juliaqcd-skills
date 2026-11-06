# Pure-gauge HMC with the Wilson plaquette action, for SU(N) in 2, 3, or 4
# dimensions, with a history file for monitoring, checkpoints, and restart.
#
#   julia --project=ENV hmc_puregauge.jl out=runs/su3_b5.7_4x4x4x8 \
#       colors=3 lattice=4,4,4,8 beta=5.7 ntraj=500 steps=20 tau=1.0 seed=1234
#
# Optional: start=hot|cold, save_every=50, q_every=10 (4D only, 0 = off),
# flow_time=<t/a²> (default: sqrt(8t) = 0.3 × smallest extent), restart=true.
#
# The output directory must not exist unless restart=true. Files written:
#   meta.toml       parameters, versions, host, start time
#   Manifest.toml   copy of the active environment's manifest
#   history.csv     one line per trajectory
#   checkpoints/    conf_NNNNNN.jld2 (configuration after trajectory NNNNNN)
#   state.toml      next trajectory number, for restart
#
# The Metropolis uniform of trajectory k depends only on (seed, k) and the
# momenta use sweep = k, so a restart from conf_k reproduces the chain.

import JACC
JACC.@init_backend
using Gaugefields
using QCDMeasurements
using Pkg
using Printf
include(joinpath(@__DIR__, "common.jl"))

function write_meta(out, params)
    open(joinpath(out, "meta.toml"), "w") do io
        for (k, v) in sort(collect(params); by=first)
            println(io, k, " = ", repr(v))
        end
        println(io, "julia_version = ", repr(string(VERSION)))
        println(io, "host = ", repr(gethostname()))
        println(io, "threads = ", Threads.nthreads())
        println(io, "started = ", repr(string(Libc.strftime("%Y-%m-%dT%H:%M:%S", time()))))
        println(io, "\n[packages]")
        for (_, info) in Pkg.dependencies()
            info.is_direct_dep && println(io, info.name, " = ", repr(string(info.version)))
        end
    end
    manifest = joinpath(dirname(Base.active_project()), "Manifest.toml")
    isfile(manifest) && cp(manifest, joinpath(out, "Manifest.toml"))
end

function main(args)
    a = parse_args(args)
    # Physics parameters have no defaults: a missing one stops the run.
    for key in ("out", "colors", "lattice", "beta", "ntraj")
        haskey(a, key) || error("$key=... is required (physics parameters and the run length are never defaulted)")
    end
    out = getarg(a, "out", "")
    colors = getarg(a, "colors", 3)
    lattice = getarg(a, "lattice", (4, 4, 4, 4))
    beta = getarg(a, "beta", 6.0)
    ntraj = getarg(a, "ntraj", 100)
    steps = getarg(a, "steps", 20)
    tau = getarg(a, "tau", 1.0)
    seed = getarg(a, "seed", 1234)
    start = getarg(a, "start", :hot)
    save_every = getarg(a, "save_every", 50)
    dim = length(lattice)
    q_every = getarg(a, "q_every", dim == 4 ? 10 : 0)
    q_every > 0 && dim != 4 && error("q_every needs a 4D lattice")
    flow_time = getarg(a, "flow_time", (0.3 * minimum(lattice))^2 / 8)
    restart = getarg(a, "restart", false)

    params = Dict("colors" => colors, "lattice" => collect(lattice), "beta" => beta,
        "ntraj" => ntraj, "steps" => steps, "tau" => tau, "seed" => seed,
        "start" => string(start), "save_every" => save_every, "q_every" => q_every,
        "flow_time" => flow_time, "action" => "Wilson plaquette", "integrator" => "QPQ")

    U = gauge_configuration(lattice; colors, start, seed, process_grid=ntuple(_ -> 1, dim))
    first_traj = 1
    if restart
        isdir(out) || error("restart=true but $out does not exist")
        line = only(filter(startswith("next_trajectory"), readlines(joinpath(out, "state.toml"))))
        first_traj = parse(Int, strip(split(line, '=')[2]))
        load_configuration!(U, joinpath(out, "checkpoints", @sprintf("conf_%06d.jld2", first_traj - 1)))
        # Drop history lines written after the checkpoint.
        hist = readlines(joinpath(out, "history.csv"))
        keep = [hist[1]; filter(l -> parse(Int, split(l, ',')[1]) < first_traj, hist[2:end])]
        write(joinpath(out, "history.csv"), join(keep, '\n') * '\n')
        println("restart from trajectory ", first_traj)
    else
        ispath(out) && error("$out exists; choose a new directory or pass restart=true")
        mkpath(joinpath(out, "checkpoints"))
        write_meta(out, params)
        open(joinpath(out, "history.csv"), "w") do io
            println(io, "traj,dH,exp_minus_dH,accepted,plaquette,polyakov_re,polyakov_im,Q,seconds")
        end
    end

    action = wilson_action(U, beta)
    md = md_driver(U, action; steps, trajectory_length=tau, integrator=QPQ())
    p = gauge_momenta(U)
    old_U = copy_configuration(U)
    Uflow = copy_configuration(U)
    flow_eps = 0.02
    flow = gradient_flow(Uflow; steps=max(1, round(Int, flow_time / flow_eps)), step_size=flow_eps)
    qmeas = q_every > 0 ? TopologicalChargeMeasurement(Uflow; TC_methods=["clover"], printvalues=false) : nothing

    history = open(joinpath(out, "history.csv"), "a")
    try
        for k in first_traj:ntraj
            t = @elapsed r = hmc_trajectory!(U, p, old_U, md, seed, k)
            plaq = measure_plaquette(U)
            poly = measure_polyakov_loop(U)
            Q = NaN
            if q_every > 0 && k % q_every == 0
                copy_configuration!(Uflow, U)
                flow!(Uflow, flow)
                Q = get_value(measure(qmeas, Uflow))["clover improved"]
            end
            @printf(history, "%d,%.12e,%.12e,%d,%.15e,%.15e,%.15e,%.10e,%.4f\n",
                k, r.dH, exp(-r.dH), r.accepted, plaq, real(poly), imag(poly), Q, t)
            flush(history)
            if k % save_every == 0 || k == ntraj
                save_configuration(joinpath(out, "checkpoints", @sprintf("conf_%06d.jld2", k)), U)
                write(joinpath(out, "state.toml"), "next_trajectory = $(k + 1)\n")
            end
        end
    finally
        close(history)
    end
    println("done: ", out)
end

main(ARGS)
