# Flow scales, topology, and the static potential from the files written by
# measure_ensemble.jl. Julia standard library only; runs anywhere the files are.
#
#   julia analyze_ensemble.jl runs/NAME
#
# Optional:
#   therm=N        drop trajectories ≤ N (default: the cut of monitor.jl)
#   bin=N          jackknife bin size in measured configurations (default:
#                  4 τ_int of t²E near t0, or of the plaquette-size loop)
#   c=0.3          reference value for t0 and w0
#   sqrt_t0_fm=X   physical value of √t0 in fm, with its source, to convert
#                  the lattice spacing; there is no default
#
# Prints tables and writes RUN/measure/results.toml (results_binN.toml when
# bin=N is given, so the default results are not overwritten). Lines start
# with WARN when the result needs care before it is used.

include(joinpath(@__DIR__, "analysis.jl"))
using Printf
import TOML

warn(msg) = println("  WARN  ", msg)

"Group rows of a CSV by trajectory: sorted trajectories and one Dict of columns per trajectory."
function by_traj(cols)
    trajs = sort(unique(Int.(cols["traj"])))
    groups = Dict(k => findall(==(k), Int.(cols["traj"])) for k in trajs)
    return trajs, groups
end

fmt(x, e) = isnan(x) ? "not reached" : isnan(e) ? @sprintf("%.5g", x) : @sprintf("%.5g ± %.2g", x, e)

function analyze_flow(dir, trajs_keep, L, c, bin_opt, sqrt_t0_fm, results)
    cols = read_csv(joinpath(dir, "flow.csv"))
    trajs, groups = by_traj(cols)
    trajs = filter(in(trajs_keep), trajs)
    n = length(trajs)
    d = length(L)
    t = cols["t"][groups[trajs[1]]]
    methods = d == 4 ? ["E_clover", "E_plaq"] : ["E_plaq"]
    println("\n-- gradient flow: $n configurations, t ≤ $(t[end])")
    n >= 2 || (warn("fewer than two configurations"); return)
    samples = Dict(m => [cols[m][groups[k]] for k in trajs] for m in methods)

    main_method = methods[1]
    mean_E = sum(samples[main_method]) / n
    s0 = flow_scales(t, mean_E; c)
    it = isnan(s0.t0) ? length(t) : argmin(abs.(t .- s0.t0))
    series = [E[it] * t[it]^2 for E in samples[main_method]]
    bin, capped = bin_opt === nothing ? choose_bin(series) : (bin_opt, false)
    tau = gamma_method(series).tau_int
    @printf("  τ_int of t²E at t = %.2f: %.1f configurations; bin = %d (%d bins)\n", t[it], tau, bin, n ÷ bin)
    capped && warn(@sprintf("4 τ_int = %d configurations leaves fewer than 20 bins; bin capped at %d, so the errors are too small. Measure more configurations.", auto_bin(series), bin))
    n ÷ bin < 20 && warn("only $(n ÷ bin) bins; errors are rough. Measure more configurations.")
    results["bin_flow"] = bin
    results["bin_flow_capped"] = capped

    if d != 4
        println("  t0 and w0 are defined in four dimensions; showing t²E only.")
        for j in unique(round.(Int, range(1, length(t), length=6)))
            r = jackknife(E -> E[j] * t[j]^2, samples[main_method]; bin)
            @printf("    t = %6.3f   t²E = %s\n", t[j], fmt(r.value, r.error))
        end
        return
    end

    println("  t0/a² and w0/a (", main_method, " is the main definition):")
    for m in methods
        r = jackknife(E -> [flow_scales(t, E; c)...], samples[m]; bin)
        t0, w0 = r.value
        @printf("    %-9s t0/a² = %-22s w0/a = %s\n", m, fmt(t0, r.error[1]), fmt(w0, r.error[2]))
        results["flow_$m"] = Dict("t0" => t0, "t0_error" => r.error[1], "w0" => w0, "w0_error" => r.error[2])
    end
    println("  stability with the bin size (", main_method, "):")
    for b in unique(filter(b -> n ÷ b >= 2, [1, 2, 4, 8, 16, bin]))
        r = jackknife(E -> [flow_scales(t, E; c)...], samples[main_method]; bin=b)
        @printf("    bin %3d  t0/a² = %-22s w0/a = %s\n", b, fmt(r.value[1], r.error[1]), fmt(r.value[2], r.error[2]))
    end

    t0 = results["flow_$main_method"]["t0"]
    if isnan(t0)
        warn("t²E does not reach $c by t = $(t[end]); flow longer (flow_tmax=) or the lattice is too coarse/small.")
    else
        r8 = sqrt(8t0)
        @printf("  √(8 t0)/a = %.3f; smallest extent L/a = %d\n", r8, minimum(L))
        r8 > minimum(L) / 4 && warn(@sprintf("√(8 t0) = %.2f a is more than a quarter of the smallest extent; finite-volume effects on t0 can be large (rule of thumb)", r8))
        t0 < 1 && warn("t0/a² < 1: the flow radius is about a lattice spacing; discretization effects are large")
        if haskey(results, "flow_E_plaq")
            tp = results["flow_E_plaq"]["t0"]
            gap = isnan(tp) ? NaN : abs(t0 - tp) / t0
            gap > 0.1 && warn(@sprintf("the clover and plaquette forms of E give t0/a² differing by %.0f%%; discretization effects are large at this lattice spacing", 100gap))
        end
        if sqrt_t0_fm !== nothing
            e = results["flow_$main_method"]["t0_error"]
            afm = sqrt_t0_fm / sqrt(t0)
            @printf("  a = %.5f ± %.5f fm from √t0 = %g fm (statistical error of t0 only)\n",
                afm, afm * e / (2t0), sqrt_t0_fm)
            results["lattice_spacing_fm"] = afm
        end
    end

    # topology at the largest flow time
    for key in ("Q_improved", "Q_clover")
        haskey(cols, key) || continue
        Q = [cols[key][groups[k]][end] for k in trajs]
        g = gamma_method(Q)
        g2 = gamma_method(Q .^ 2)
        frac = sum(abs.(Q .- round.(Q)) .< 0.2) / n
        changes = sum(Base.diff(round.(Q)) .!= 0)
        @printf("  %-10s at t = %.2f: <Q> = %s, <Q²> = %s, τ_int = %.1f, %.0f%% within 0.2 of an integer, %d changes\n",
            key, t[end], fmt(g.mean, g.error), fmt(g2.mean, g2.error), g.tau_int, 100frac, changes)
        results[key] = Dict("mean" => g.mean, "error" => g.error, "Q2" => g2.mean, "Q2_error" => g2.error,
            "tau_int" => g.tau_int, "changes" => changes)
        changes == 0 && warn("$key never changes: topology is frozen; results that depend on it are unreliable")
    end
end

function analyze_wilson(dir, trajs_keep, bin_opt, results)
    cols = read_csv(joinpath(dir, "wilson_loops.csv"))
    trajs, groups = by_traj(cols)
    trajs = filter(in(trajs_keep), trajs)
    n = length(trajs)
    g1 = groups[trajs[1]]
    Rmax = Int(maximum(cols["R"][g1]))
    Tmax = Int(maximum(cols["T"][g1]))
    order = [findfirst(i -> cols["R"][i] == R && cols["T"][i] == T, g1) for R in 1:Rmax, T in 1:Tmax]
    samples = [cols["W"][groups[k]][vec(order)] for k in trajs]
    println("\n-- Wilson loops: $n configurations, R ≤ $Rmax, T ≤ $Tmax")
    n >= 2 || (warn("fewer than two configurations"); return)
    w11 = [s[1] for s in samples]
    bin, capped = bin_opt === nothing ? choose_bin(w11) : (bin_opt, false)
    @printf("  bin = %d (%d bins), from τ_int of W(1,1)\n", bin, n ÷ bin)
    capped && warn(@sprintf("4 τ_int = %d configurations leaves fewer than 20 bins; bin capped at %d, so the errors are too small. Measure more configurations.", auto_bin(w11), bin))
    results["bin_wilson"] = bin
    results["bin_wilson_capped"] = capped

    Wm = jackknife(identity, samples; bin)
    W = reshape(Wm.value, Rmax, Tmax)
    We = reshape(Wm.error, Rmax, Tmax)
    V = jackknife(w -> vec(effective_potential(reshape(w, Rmax, Tmax))), samples; bin)
    Vv = reshape(V.value, Rmax, Tmax - 1)
    Ve = reshape(V.error, Rmax, Tmax - 1)
    println("  W(R,T):")
    for R in 1:Rmax
        println("    R = $R  ", join((fmt(W[R, T], We[R, T]) for T in 1:Tmax), "   "))
    end
    println("  a V(R) = log W(R,T)/W(R,T+1), by T (should become flat in T):")
    for R in 1:Rmax
        println("    R = $R  ", join((fmt(Vv[R, T], Ve[R, T]) for T in 1:Tmax-1), "   "))
    end
    if Tmax == 2
        warn("a V(R) has a single T; whether it has reached the static potential cannot be judged")
    elseif Tmax > 2
        moving = [R for R in 1:Rmax if abs(Vv[R, end] - Vv[R, end-1]) > 2hypot(Ve[R, end], Ve[R, end-1])]
        isempty(moving) || warn("a V(R) still changes between T = $(Tmax-2) and $(Tmax-1) for R = $(join(moving, ", ")): " *
            "no plateau. The largest-T value is only an upper estimate of the static potential, " *
            "and a fit of V(R) or σ from these values is not meaningful. Larger T (a longer lattice) " *
            "or smeared spatial links (not in this skill yet) are needed.")
    end
    noisy = [(R, T) for R in 1:Rmax, T in 1:Tmax if abs(W[R, T]) < 3We[R, T]]
    isempty(noisy) || warn("W(R,T) is within 3σ of zero for (R,T) = $(join(noisy, ", ")); " *
                           "the potential there is noise. Smearing the spatial links would help (not in this skill yet).")
    if Rmax >= 2 && Tmax >= 2
        C = jackknife(w -> vec(creutz_ratios(reshape(w, Rmax, Tmax))), samples; bin)
        Cv = reshape(C.value, Rmax - 1, Tmax - 1)
        Ce = reshape(C.error, Rmax - 1, Tmax - 1)
        println("  Creutz ratios χ(R,R) (approach σa² at large R):")
        for R in 2:min(Rmax, Tmax)
            println("    χ($R,$R) = ", fmt(Cv[R-1, R-1], Ce[R-1, R-1]))
        end
        results["creutz"] = Dict(string(R) => [Cv[R-1, R-1], Ce[R-1, R-1]] for R in 2:min(Rmax, Tmax))
        m = min(Rmax, Tmax)
        println("  stability with the bin size (a V($Rmax) at T = $(Tmax-1), χ($m,$m)):")
        for b in unique(filter(b -> n ÷ b >= 2, [1, 2, 4, 8, 16, bin]))
            rv = jackknife(w -> effective_potential(reshape(w, Rmax, Tmax))[Rmax, Tmax-1], samples; bin=b)
            rc = jackknife(w -> creutz_ratios(reshape(w, Rmax, Tmax))[m-1, m-1], samples; bin=b)
            @printf("    bin %3d  a V = %-22s χ = %s\n", b, fmt(rv.value, rv.error), fmt(rc.value, rc.error))
        end
    end
    results["wilson_loops"] = Dict("W" => [W[R, :] for R in 1:Rmax], "W_error" => [We[R, :] for R in 1:Rmax],
        "V" => [Vv[R, :] for R in 1:Rmax], "V_error" => [Ve[R, :] for R in 1:Rmax])
end

function main(args)
    isempty(args) && error("usage: julia analyze_ensemble.jl RUN_DIR [therm=N] [bin=N] [c=0.3] [sqrt_t0_fm=X]")
    run = args[1]
    opts = Dict(Pair(split(a, '='; limit=2)...) for a in args[2:end])
    meta = TOML.parsefile(joinpath(run, "meta.toml"))
    L = Tuple(meta["lattice"])
    h = read_history(joinpath(run, "history.csv"))
    cut = haskey(opts, "therm") ? parse(Int, opts["therm"]) : thermalization_cut(h["plaquette"])[1]
    keep = Set(Int(k) for k in h["traj"] if k > cut)
    bin = haskey(opts, "bin") ? parse(Int, opts["bin"]) : nothing
    c = parse(Float64, get(opts, "c", "0.3"))
    sqrt_t0_fm = haskey(opts, "sqrt_t0_fm") ? parse(Float64, opts["sqrt_t0_fm"]) : nothing
    dir = joinpath(run, "measure")
    println("== analyze_ensemble: ", run, ", SU($(meta["colors"])) ", join(L, "x"), ", β = ", meta["beta"],
        ", trajectories > $cut", haskey(opts, "therm") ? " (given)" : " (thermalization cut of monitor.jl)")
    results = Dict{String,Any}("therm" => cut, "c" => c)
    isfile(joinpath(dir, "flow.csv")) && analyze_flow(dir, keep, L, c, bin, sqrt_t0_fm, results)
    isfile(joinpath(dir, "wilson_loops.csv")) && analyze_wilson(dir, keep, bin, results)
    out = joinpath(dir, bin === nothing ? "results.toml" : "results_bin$bin.toml")
    open(io -> TOML.print(io, results), out, "w")
    println("\nwritten ", out)
end

main(ARGS)
