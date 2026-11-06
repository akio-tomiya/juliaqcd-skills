# Effective masses from the meson correlators written by measure_mesons.jl.
# Julia standard library only; runs anywhere the files are.
#
#   julia analyze_mesons.jl runs/NAME [name=kappa0.153_csw0.0]
#
# Optional:
#   name=      the folder measure/mesons_NAME; needed when there are several
#   therm=N    drop trajectories ≤ N (default: the cut of monitor.jl)
#   bin=N      jackknife bin size in measured configurations (default: 4 τ_int
#              of the pion correlator at the Δt where τ_int is largest)
#
# Zero momentum only. Channels with directions 1–3 (vector_μ, axial_μ) are
# averaged. Correlators are folded, C(Δt) and C(L₄ − Δt), and the cosh
# effective mass is computed with a binned jackknife. There is no fit: the
# plateau of m_eff is an estimate, and the tables show how far it is from flat.
#
# Prints tables and writes measure/mesons_NAME/results.toml (results_binN.toml
# when bin=N is given). Lines start with WARN when the result needs care.

include(joinpath(@__DIR__, "analysis.jl"))
using Printf
import TOML

warn(msg) = println("  WARN  ", msg)
fmt(x, e) = isnan(x) ? "—" : @sprintf("%.4f ± %.4f", x, e)

"Rows of mesons.csv as (traj, channel, momentum, dt, re, im)."
function read_mesons(path)
    rows = []
    for line in readlines(path)[2:end]
        isempty(strip(line)) && continue
        f = split(line, ',')
        push!(rows, (parse(Int, f[1]), String(f[2]), (parse(Int, f[3]), parse(Int, f[4]), parse(Int, f[5])),
            parse(Int, f[6]), parse(Float64, f[7]), parse(Float64, f[8])))
    end
    return rows
end

"Zero-momentum correlators: channel → (trajectories, matrix [config, Δt], max |im|/|re|)."
function zero_momentum(rows, keep, T)
    data = Dict{String,Dict{Int,Vector{ComplexF64}}}()
    for (k, ch, p, dt, re, im) in rows
        (p == (0, 0, 0) && k in keep) || continue
        d = get!(data, ch, Dict{Int,Vector{ComplexF64}}())
        v = get!(d, k, fill(NaN + 0im, T))
        v[dt+1] = re + im * 1im
    end
    out = Dict{String,Any}()
    for (ch, d) in data
        trajs = sort([k for (k, v) in d if !any(isnan ∘ real, v)])
        M = [d[k][dt] for k in trajs, dt in 1:T]
        out[ch] = (trajs, M)
    end
    # average the spatial directions
    for base in ("vector", "axial")
        parts = [base * "_$μ" for μ in 1:3 if haskey(out, base * "_$μ")]
        isempty(parts) && continue
        common = intersect((Set(out[p][1]) for p in parts)...)
        trajs = sort(collect(common))
        M = sum(out[p][2][[findfirst(==(k), out[p][1]) for k in trajs], :] for p in parts) ./ length(parts)
        for p in parts
            delete!(out, p)
        end
        out[base * (length(parts) == 3 ? "_spatial" : "_" * join(last.(parts), ""))] = (trajs, M)
    end
    return out
end

function main(args)
    isempty(args) && error("usage: julia analyze_mesons.jl RUN_DIR [name=...] [therm=N] [bin=N]")
    run = args[1]
    opts = Dict(Pair(split(a, '='; limit=2)...) for a in args[2:end])
    unknown = setdiff(keys(opts), ("name", "therm", "bin",))
    isempty(unknown) || error("unknown argument(s): $(join(sort(collect(unknown)), ", ")). This script accepts: " * join(("name", "therm", "bin",), ", "))
    meta = TOML.parsefile(joinpath(run, "meta.toml"))
    L = Tuple(meta["lattice"])
    T = L[4]
    dirs = filter(d -> startswith(d, "mesons_"), readdir(joinpath(run, "measure")))
    name = get(opts, "name", nothing)
    if name === nothing
        length(dirs) == 1 || error("several or no measure/mesons_* folders ($(join(dirs, ", "))); give name=")
        dir = joinpath(run, "measure", dirs[1])
    else
        dir = joinpath(run, "measure", startswith(name, "mesons_") ? name : "mesons_" * name)
    end
    mmeta = TOML.parsefile(joinpath(dir, "meta.toml"))
    h = read_history(joinpath(run, "history.csv"))
    cut = haskey(opts, "therm") ? parse(Int, opts["therm"]) : thermalization_cut(h["plaquette"])[1]
    keep = Set(Int(k) for k in h["traj"] if k > cut)
    println("== analyze_mesons: ", dir, ", SU($(meta["colors"])) ", join(L, "x"), ", β = ", meta["beta"], ", ",
        mmeta["operator"], " κ = ", mmeta["kappa"], mmeta["csw"] == 0 ? "" : ", c_SW = $(mmeta["csw"])",
        ", trajectories > $cut", haskey(opts, "therm") ? " (given)" : " (thermalization cut of monitor.jl)")
    results = Dict{String,Any}("therm" => cut, "kappa" => mmeta["kappa"], "csw" => mmeta["csw"])

    solver = read_csv(joinpath(dir, "solver.csv"))
    worst_res = maximum(solver["residual"])
    worst_res > 1e-8 && warn(@sprintf("a solver residual reached %.0e (eps_CG too large, or κ near κ_c on some configuration)", worst_res))

    data = zero_momentum(read_mesons(joinpath(dir, "mesons.csv")), keep, T)
    haskey(data, "pseudoscalar") || error("no zero-momentum pseudoscalar correlator in $dir")
    trajs_pi, Mpi = data["pseudoscalar"]
    n = length(trajs_pi)
    n >= 2 || error("fewer than two configurations after the cut")
    # bin from the slowest Δt: short distances decorrelate fastest
    τs = [gamma_method(real.(Mpi[:, 1+Δ])).tau_int for Δ in 1:T÷2]
    Δslow = argmax(τs)
    series = real.(Mpi[:, 1+Δslow])
    bin, capped = haskey(opts, "bin") ? (parse(Int, opts["bin"]), false) : choose_bin(series)
    println(@sprintf("  %d configurations; τ_int of C_PP(Δt) = %s configurations (largest at Δt = %d); bin = %d (%d bins)",
        n, join((@sprintf("%.1f", τ) for τ in τs), ", "), Δslow, bin, n ÷ bin))
    capped && warn(@sprintf("4 τ_int = %d configurations leaves fewer than 20 bins; bin capped at %d, so the errors are too small. Measure more configurations.", auto_bin(series), bin))
    n ÷ bin < 20 && warn("only $(n ÷ bin) bins; errors are rough. Measure more configurations.")
    results["bin"] = bin
    results["bin_capped"] = capped

    # outliers: configurations whose pion correlator at T/2 is far from the median
    mid = real.(Mpi[:, 1+T÷2])
    med = sort(mid)[(n+1)÷2]
    out = [trajs_pi[i] for i in 1:n if mid[i] > 20med]
    isempty(out) || warn("C_PP(T/2) is more than 20 times the median on trajectories $(join(out, ", ")): " *
                         "exceptional configurations (κ near κ_c for this β?); check them before averaging")

    for ch in sort(collect(keys(data)), by=c -> (c != "pseudoscalar", c))
        trajs, M = data[ch]
        Cre = real.(M)
        imag_ratio = maximum(abs.(sum(imag.(M), dims=1))) / maximum(abs.(sum(Cre, dims=1)))
        samples = [fold_correlator(Cre[i, :]) for i in axes(Cre, 1)]
        nb = length(samples) ÷ bin
        nb >= 2 || (warn("$ch: fewer than two bins"); continue)
        Cf = jackknife(identity, samples; bin)
        jm = jackknife(C -> effective_mass_cosh(C, T), samples; bin)
        # time-reflection symmetry of the unfolded mean
        raw = jackknife(identity, [Cre[i, :] for i in axes(Cre, 1)]; bin)
        asym = maximum(abs(raw.value[1+Δ] - raw.value[1+T-Δ]) /
                       hypot(raw.error[1+Δ], raw.error[1+T-Δ]) for Δ in 1:T-1)
        println("\n-- ", ch, " (zero momentum, ", length(trajs), " configurations)")
        println("   Δt   C(Δt) folded                 m_eff(Δt → Δt+1)")
        for Δ in 0:T÷2
            me = Δ + 1 <= length(jm.value) ? fmt(jm.value[Δ+1], jm.error[Δ+1]) : ""
            println(@sprintf("   %2d   %-28s %s", Δ, @sprintf("%.5g ± %.2g", Cf.value[Δ+1], Cf.error[Δ+1]), me))
        end
        asym > 4 && warn(@sprintf("%s: C(Δt) and C(L₄ − Δt) differ by up to %.1fσ; folding assumes they agree", ch, asym))
        imag_ratio > 1e-6 && warn(@sprintf("%s: the ensemble-averaged imaginary part is %.0e of the real part", ch, imag_ratio))
        good = [i for i in eachindex(jm.value) if isfinite(jm.value[i]) && isfinite(jm.error[i])]
        if length(good) >= 2
            a, b = good[end-1], good[end]
            if abs(jm.value[b] - jm.value[a]) > 2hypot(jm.error[a], jm.error[b])
                warn(@sprintf("%s: m_eff still changes between Δt = %d and %d: no plateau. The last value is an upper estimate; a longer time extent is needed.", ch, a - 1, b - 1))
            end
        end
        isempty(good) && warn("$ch: no effective mass (noise or sign changes)")
        results[ch] = Dict("C_folded" => Cf.value, "C_folded_error" => Cf.error,
            "m_eff" => replace(jm.value, NaN => -1.0), "m_eff_error" => replace(jm.error, NaN => -1.0),
            "configurations" => length(trajs))
        if ch == "pseudoscalar" && !isempty(good)
            mlast = jm.value[good[end]]
            Ls = minimum(L[1:3])
            println(@sprintf("   m_π L ≲ %.2f (last m_eff, an upper estimate, × L = %d)", mlast * Ls, Ls))
            mlast * Ls < 4 && warn("m_π L < 4: finite-volume effects on the pion can be large (rule of thumb)")
            T / 2 * mlast < 3 && warn(@sprintf("m_π L₄/2 = %.1f: the excited states may not have died out by the middle of the lattice", T / 2 * mlast))
        end
    end

    # stability of the pion m_eff with the bin size
    samples = [fold_correlator(real.(Mpi[i, :])) for i in 1:n]
    Δs = max(1, T ÷ 4)
    println("\n  stability with the bin size (pseudoscalar m_eff at Δt = $Δs):")
    for b in sort(unique([1, 2, 4, 8, 16, bin]))
        n ÷ b >= 2 || continue
        j = jackknife(C -> effective_mass_cosh(C, T), samples; bin=b)
        println(@sprintf("    bin %3d  %s", b, fmt(j.value[Δs+1], j.error[Δs+1])))
    end
    println("\n  m_eff is not fitted here; a correlated fit with its fit-range dependence belongs to juliaqcd-analyze (not written yet).")

    outfile = joinpath(dir, haskey(opts, "bin") ? "results_bin$bin.toml" : "results.toml")
    open(io -> TOML.print(io, results), outfile, "w")
    println("\nwritten ", outfile)
end

main(ARGS)
