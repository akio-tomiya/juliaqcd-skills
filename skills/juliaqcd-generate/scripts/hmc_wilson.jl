# HMC with two degenerate flavors of Wilson or Wilson–clover fermions and the
# Wilson plaquette gauge action, for SU(N) in four dimensions, optionally with
# the fermions on stout-smeared links. Same outputs as hmc_puregauge.jl, so
# monitor.jl and the measurement scripts read the run. One process on the
# CPU (process_grid = 1); no MPI. Run check_hmc_wilson.jl with the same
# kappa, csw, rho, and smear_iterations first.
#
#   julia --project=ENV hmc_wilson.jl out=runs/nf2_b5.3_k0.13 colors=3 \
#       lattice=8,8,8,16 beta=5.3 kappa=0.13 csw=0 ntraj=500 steps=20
#
# Required: out, colors, lattice, beta, kappa, csw (0 = plain Wilson), ntraj.
# Optional: rho=0 (stout parameter; 0 = no smearing), smear_iterations=1,
# steps=20 (outer Sexton–Weingarten steps, fermion force), n_fast=4 (gauge
# steps inside each), tau=1.0, eps_cg=1e-14 (squared relative residual of the
# solver), seed=1234, start=cold|hot, save_every=50, q_every=10,
# flow_time=<t/a²>, restart=true.
#
# Fermion boundary conditions: periodic in space, antiperiodic in time.
# The pseudofermion of trajectory k depends only on (seed, k), like the
# momenta and the Metropolis number, so a restart reproduces the chain.

import JACC
JACC.@init_backend
using Gaugefields
using QCDMeasurements
using Pkg
using Printf
include(joinpath(@__DIR__, "common.jl"))
include(joinpath(@__DIR__, "fermion_hmc.jl"))

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
    check_keys(a, ("beta", "colors", "csw", "eps_cg", "flow_time", "kappa", "lattice", "n_fast", "ntraj", "out",
        "q_every", "restart", "rho", "save_every", "seed", "smear_iterations", "start", "steps", "tau"))
    for key in ("out", "colors", "lattice", "beta", "kappa", "csw", "ntraj")
        haskey(a, key) || error("$key=... is required (physics parameters and the run length are never defaulted)")
    end
    out = getarg(a, "out", "")
    colors = getarg(a, "colors", 3)
    lattice = getarg(a, "lattice", (4, 4, 4, 4))
    length(lattice) == 4 || error("four dimensions only")
    beta = getarg(a, "beta", 6.0)
    kappa = getarg(a, "kappa", 0.12)
    csw = getarg(a, "csw", 0.0)
    rho = getarg(a, "rho", 0.0)
    smear_iterations = getarg(a, "smear_iterations", 1)
    ntraj = getarg(a, "ntraj", 100)
    steps = getarg(a, "steps", 20)
    n_fast = getarg(a, "n_fast", 4)
    tau = getarg(a, "tau", 1.0)
    eps_cg = getarg(a, "eps_cg", 1e-14)
    seed = getarg(a, "seed", 1234)
    start = getarg(a, "start", :cold)
    save_every = getarg(a, "save_every", 50)
    q_every = getarg(a, "q_every", 10)
    flow_time = getarg(a, "flow_time", (0.3 * minimum(lattice))^2 / 8)
    restart = getarg(a, "restart", false)

    params = Dict("colors" => colors, "lattice" => collect(lattice), "beta" => beta,
        "kappa" => kappa, "csw" => csw, "rho" => rho, "smear_iterations" => smear_iterations,
        "nf" => 2, "fermion_bc" => [1, 1, 1, -1], "eps_cg" => eps_cg,
        "ntraj" => ntraj, "steps" => steps, "n_fast" => n_fast, "tau" => tau, "seed" => seed,
        "start" => string(start), "save_every" => save_every, "q_every" => q_every,
        "flow_time" => flow_time, "action" => "Wilson plaquette + Nf=2 " * (csw == 0 ? "Wilson" : "Wilson-clover") *
                                               (rho > 0 ? " on stout links" : ""),
        "integrator" => "Sexton-Weingarten (fermion outer, gauge inner)")

    U = gauge_configuration(lattice; colors, start, seed, process_grid=(1, 1, 1, 1))
    first_traj = 1
    if restart
        isdir(out) || error("restart=true but $out does not exist")
        line = only(filter(startswith("next_trajectory"), readlines(joinpath(out, "state.toml"))))
        first_traj = parse(Int, strip(split(line, '=')[2]))
        load_configuration!(U, joinpath(out, "checkpoints", @sprintf("conf_%06d.jld2", first_traj - 1)))
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

    f = fermion_setup(U; kappa, csw, rho, smear_iterations, eps_cg)
    md = make_fermion_md(U, beta, f; steps, n_fast, tau)
    p = gauge_momenta(U)
    old_U = copy_configuration(U)
    Uflow = copy_configuration(U)
    flow_eps = 0.02
    flow = gradient_flow(Uflow; steps=max(1, round(Int, flow_time / flow_eps)), step_size=flow_eps)
    qmeas = q_every > 0 ? TopologicalChargeMeasurement(Uflow; TC_methods=["clover"], printvalues=false) : nothing

    history = open(joinpath(out, "history.csv"), "a")
    try
        for k in first_traj:ntraj
            t = @elapsed r = fermion_hmc_trajectory!(U, p, old_U, md, f, seed, k)
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
