# Quality report for an HMC run written by hmc_puregauge.jl.
#
#   julia monitor.jl runs/su3_b5.7_4x4x4x8            # thermalization cut chosen automatically
#   julia monitor.jl runs/su3_b5.7_4x4x4x8 therm=100  # or given by hand
#
# Julia standard library only; runs anywhere the history file is.
# Each item prints PASS, WARN, or FAIL. Exit code 1 if any FAIL.
# WARN means "look before measuring", not "wrong".

include(joinpath(@__DIR__, "stats.jl"))
using Printf

function report(status, name, detail)
    println("  ", rpad(status, 5), rpad(name, 34), detail)
    return status
end

function main(args)
    isempty(args) && error("usage: julia monitor.jl RUN_DIR [therm=N]")
    dir = args[1]
    opts = Dict(Pair(split(a, '='; limit=2)...) for a in args[2:end])
    unknown = setdiff(keys(opts), ("therm",))
    isempty(unknown) || error("unknown argument(s): $(join(sort(collect(unknown)), ", ")). This script accepts: " * join(("therm",), ", "))
    h = read_history(joinpath(dir, "history.csv"))
    n = length(h["traj"])
    println("== ", dir, "  (", n, " trajectories)")
    statuses = String[]

    plaq = h["plaquette"]
    # A chain that accepts nothing has a constant plaquette, whose two halves
    # agree trivially; judge that first, so that thermalization cannot PASS.
    nacc = Int(sum(h["accepted"][n÷2+1:end]))
    moving = nacc > 0
    push!(statuses, report(moving ? "PASS" : "FAIL", "chain moves",
        moving ? "$nacc of $(n - n ÷ 2) accepted in the second half" :
        "no trajectory accepted in the second half; the chain is stuck (more steps, or start=cold)"))
    if !moving
        report("--", "thermalization", "not judged: the chain does not move")
        cut = n ÷ 2
    elseif haskey(opts, "therm")
        cut = parse(Int, opts["therm"])
        report("--", "thermalization", "drop first $cut trajectories (given)")
    else
        cut, stable = thermalization_cut(plaq)
        push!(statuses, report(stable ? "PASS" : "WARN", "thermalization",
            "drop first $cut trajectories" * (stable ? "" : "; halves of the rest disagree, run longer")))
    end
    sel = cut+1:n
    ns = length(sel)

    acc = sum(h["accepted"][sel]) / ns
    st = acc < 0.6 ? "WARN" : acc > 0.95 ? "WARN" : "PASS"
    hint = acc < 0.6 ? " (lower the step size)" : acc > 0.95 ? " (the step size could be larger)" : ""
    push!(statuses, report(st, "acceptance", @sprintf("%.3f%s", acc, hint)))

    e = gamma_method(h["exp_minus_dH"][sel])
    dev = abs(e.mean - 1) / e.error
    push!(statuses, report(dev < 3 ? "PASS" : dev < 5 ? "WARN" : "FAIL", "<exp(-dH)> = 1",
        @sprintf("%.4f ± %.4f  (%.1fσ)", e.mean, e.error, dev)))

    dH = h["dH"][sel]
    m1 = gamma_method(dH)
    m2 = gamma_method(dH .^ 2)
    # For small dH, <dH> = <dH²>/2 to leading order (Creutz).
    rel = abs(m1.mean - m2.mean / 2) / max(m1.error, 1e-15)
    push!(statuses, report(rel < 3 ? "PASS" : "WARN", "<dH> = <dH²>/2",
        @sprintf("<dH> = %.4f ± %.4f, <dH²>/2 = %.4f", m1.mean, m1.error, m2.mean / 2)))

    p = gamma_method(plaq[sel])
    eff = ns / (2p.tau_int)
    push!(statuses, report(eff >= 50 ? "PASS" : "WARN", "plaquette",
        @sprintf("%.6f ± %.6f, tau_int = %.1f ± %.1f, %.0f independent", p.mean, p.error,
            p.tau_int, p.tau_int_error, eff)))

    q = h["Q"][sel]
    qm = filter(!isnan, q)
    if isempty(qm)
        report("--", "topological charge", "not measured")
    else
        r = gamma_method(qm)
        sectors = length(unique(round.(Int, qm)))
        changes = count(i -> round(Int, qm[i]) != round(Int, qm[i-1]), 2:length(qm))
        neff = length(qm) / (2r.tau_int)
        offint = sum(abs.(qm .- round.(qm))) / length(qm)
        note = changes == 0 ? "frozen: Q never changed; topology-sensitive results are unreliable" :
               neff < 20 ? @sprintf("only %.0f independent measurements; too few to judge freezing", neff) : ""
        offint > 0.2 && (note *= (isempty(note) ? "" : "; ") * @sprintf("Q is far from integers (mean distance %.2f); increase flow_time", offint))
        push!(statuses, report(isempty(note) ? "PASS" : "WARN", "topological charge",
            @sprintf("%d measurements, %d sectors, %d changes, tau_int = %.1f (in measurements)", length(qm),
                sectors, changes, r.tau_int) * (isempty(note) ? "" : "; " * note)))
    end

    t = sum(h["seconds"])
    println(@sprintf("  time: %.1f s total, %.3f s per trajectory", t, t / n))
    nfail = count(==("FAIL"), statuses)
    nwarn = count(==("WARN"), statuses)
    println(nfail > 0 ? "RESULT: FAIL" : nwarn > 0 ? "RESULT: WARN ($nwarn)" : "RESULT: PASS")
    return nfail == 0
end

exit(main(ARGS) ? 0 : 1)
