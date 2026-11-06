# Checks that the pure-gauge measurements and the gradient flow are correct
# on a small lattice, before measuring an ensemble. Each check prints PASS or
# FAIL; exit code 1 on any FAIL.
#
#   julia --project=ENV check_measure.jl colors=3 lattice=4,4,4,4
#   julia --project=ENV check_measure.jl colors=2 lattice=4,4,6
#
# Optional: seed=2024, workdir=<tmp dir>, mutation=<name> (deliberately
# broken variants for selftest_measure.jl). About 25 seconds and 1.7 GB for
# 4^4 SU(3) on one core, most of it compilation.
#
# The oracle is LatticeReference.jl (plain arrays, Julia standard library):
# every JuliaQCD number is compared with an independent computation on the
# same links. Checks:
#  1. links written to JuliaQCD come back unchanged
#  2. cold field: W(R,T) = 1, plaquette = 1, E = 0, Q = 0
#  3. t = 0, rough field: plaquette, W(R,T), E (plaquette and clover), Q
#     equal the reference
#  4. gauge invariance at t = 0 under a random gauge transformation
#  5. flowed links equal the reference RK3 flow
#  6. E(t) and Q(t) along the flow equal the reference
#  7. gauge invariance of E(t) and Q(t) along the flow
#  8. the flow integrator is third order: differences in E(t) shrink as ε³
#  9. the flow lowers the Wilson action monotonically (hot start)
# 10. links stay in SU(N) after a long flow
# 11. t0 and w0: this skill's analysis and QCDMeasurements.estimate_flow_scales
#     agree with each other and with the exact values of a synthetic E(t)

import JACC
JACC.@init_backend
using Gaugefields
using Printf
using Random
include(joinpath(@__DIR__, "measure_common.jl"))
include(joinpath(@__DIR__, "analysis.jl"))
include(joinpath(@__DIR__, "LatticeReference.jl"))
import .LatticeReference as LR
include(joinpath(@__DIR__, "..", "..", "juliaqcd-extend", "scripts", "GaugeGroups.jl"))
using .GaugeGroups

const RESULTS = Tuple{String,Bool,String}[]

# Deliberately broken variants, used only by selftest_measure.jl:
#   open_loop         Wilson loop without its last side: equals 1 on a cold
#                     field, so only the reference and gauge invariance see it
#   flow_double_step  flow integrated with step 2ε while t is reported as nε:
#                     still a monotone third-order flow, so the reference is
#                     what must catch it
#   flow_euler        first-order (Euler) flow integrator
const MUTATION = Ref("none")

function record(name, ok, detail)
    push!(RESULTS, (name, ok, detail))
    println("  ", ok ? "PASS" : "FAIL", "  ", rpad(name, 52), detail)
    flush(stdout)
end

function wilson_measurement(U, Rmax, Tmax)
    m = WilsonLoops(U, Rmax, Tmax)
    if MUTATION[] == "open_loop"
        d = length(U)
        for R in 1:Rmax, T in 1:Tmax, μ in 1:d-1
            m.loops[R, T][μ] = [Wilsonline([(μ, R), (d, T), (μ, -R)], Dim=d)]
        end
    end
    return m
end

function flow_measurement(U; step_size, steps, every)
    MUTATION[] == "flow_double_step" &&
        return (FlowMeasurement(U; step_size=2step_size, steps, every), 2.0)
    return (FlowMeasurement(U; step_size, steps, every), 1.0)
end

function measure_flow_checked(mf, U)
    m, factor = mf
    r = measure_flow(m, U)
    return merge(r, (t=r.t ./ factor,))
end

function euler_flow!(U, ε, nsteps)
    F = Gaugefields.initialize_TA_Gaugefields(U)
    temps = Gaugefields.Temporalfields(U[1], num=10)
    W = copy_configuration(U)
    for _ in 1:nsteps
        Gaugefields.clear_U!(F)
        Gaugefields.add_force!(F, U, temps, plaqonly=true)
        Gaugefields.exp_aF_U!(W, -ε, F, U, temps)
        copy_configuration!(U, W)
    end
end

"Flow `U` in place by `nsteps` RK3 steps of size ε."
function run_flow!(U, ε, nsteps)
    MUTATION[] == "flow_euler" && return euler_flow!(U, ε, nsteps)
    ε_used = MUTATION[] == "flow_double_step" ? 2ε : ε
    flow!(U, gradient_flow(U; steps=nsteps, step_size=ε_used))
end

maxdiff(a, b) = maximum(abs.(a .- b))
maxdiff_links(A, B) = maximum(maximum(abs.(A[μ] .- B[μ])) for μ in eachindex(A))

"Rough field: each link exp(s X) with X a Gaussian element of the algebra."
function rough_field(rng, G, L, d; s=0.6)
    gens = generators(G)
    return [[exp(s * sum(randn(rng) * Ta for Ta in gens)) for _ in CartesianIndices(L)] for _ in 1:d]
end

haar_field(rng, G, L, d) = [[random_element(rng, G) for _ in CartesianIndices(L)] for _ in 1:d]

"Observables at t = 0 from JuliaQCD, as a flat vector with names."
function juliaqcd_t0(U, wm, fm)
    W = measure_wilson_loops(wm, U)
    f = measure_flow_checked(fm, U)
    vals = Dict("plaquette" => [measure_plaquette(U)], "W(R,T)" => vec(W), "E plaquette" => [f.E_plaq[1]])
    if length(U) == 4
        vals["E clover"] = [f.E_clover[1]]
        vals["Q clover"] = [f.Q_clover[1]]
    end
    return vals
end

function reference_t0(F, Rmax, Tmax)
    vals = Dict("plaquette" => [LR.plaquette(F)], "W(R,T)" => vec(LR.wilson_loops(F, Rmax, Tmax)),
        "E plaquette" => [LR.energy_plaquette(F)])
    if length(F) == 4
        vals["E clover"] = [LR.energy_clover(F)]
        vals["Q clover"] = [LR.topological_charge_clover(F)]
    end
    return vals
end

function compare(a, b)
    worst = 0.0
    parts = String[]
    for k in sort(collect(keys(b)))
        dk = maxdiff(a[k], b[k])
        worst = max(worst, dk)
        push!(parts, @sprintf("%s %.1e", k, dk))
    end
    return worst, join(parts, ", ")
end

"Exact t0 and w0 of E(t) = a + b t: solve a t² + b t³ = c and 2a t² + 3b t³ = c."
function exact_scales(a, b, c)
    solve(f) = (lo = 0.0; hi = 10.0; for _ in 1:200; m = (lo + hi) / 2; f(m) < c ? (lo = m) : (hi = m); end; (lo + hi) / 2)
    t0 = solve(t -> a * t^2 + b * t^3)
    w0 = sqrt(solve(t -> 2a * t^2 + 3b * t^3))
    return t0, w0
end

function main(args)
    a = parse_args(args)
    colors = getarg(a, "colors", 3)
    lattice = getarg(a, "lattice", (4, 4, 4, 4))
    seed = getarg(a, "seed", 2024)
    workdir = mkpath(getarg(a, "workdir", mktempdir()))
    MUTATION[] = getarg(a, "mutation", "none")
    MUTATION[] == "none" || println("!! mutation = ", MUTATION[], " (deliberately broken)")
    N = colors
    d = length(lattice)
    L = Tuple(lattice)
    G = SU(N)
    rng = Xoshiro(seed)
    Rmax = minimum(L[1:d-1]) ÷ 2
    Tmax = L[d] ÷ 2
    tol = 1e-10
    println("== check_measure: SU($N), lattice ", join(L, "x"), ", W(R,T) up to R = $Rmax, T = $Tmax")

    U = gauge_configuration(L; colors=N, start=:cold, process_grid=ntuple(_ -> 1, d))
    wm = wilson_measurement(U, Rmax, Tmax)
    fm0 = flow_measurement(U; step_size=0.02, steps=10, every=5)

    # 2. cold field (U is still cold here)
    W = measure_wilson_loops(wm, U)
    f = measure_flow_checked(fm0, U)
    dev = max(maxdiff(W, 1.0), abs(measure_plaquette(U) - 1), abs(f.E_plaq[1]),
        d == 4 ? max(abs(f.E_clover[1]), abs(f.Q_clover[1])) : 0.0)
    cold_ok = dev <= 1e-12

    # 1. round trip of links
    F = rough_field(rng, G, L, d)
    set_links!(U, LR.to_host(F), joinpath(workdir, "rough.jld2"))
    back = host_links(U, joinpath(workdir, "back.jld2"))
    rt = maxdiff_links(back, LR.to_host(F))
    record("links round trip", rt == 0, @sprintf("max |ΔU| = %.1e", rt))
    record("cold field: W = 1, P = 1, E = 0, Q = 0", cold_ok, @sprintf("max deviation %.1e", dev))

    # 3. t = 0 against the reference
    jq = juliaqcd_t0(U, wm, fm0)
    ref = reference_t0(F, Rmax, Tmax)
    worst, detail = compare(jq, ref)
    record("t = 0 equals the reference", worst <= tol, detail)

    # 4. gauge invariance at t = 0
    g = [random_element(rng, G) for _ in CartesianIndices(L)]
    Fg = LR.gauge_transform(F, g)
    Ug = gauge_configuration(L; colors=N, start=:cold, process_grid=ntuple(_ -> 1, d))
    set_links!(Ug, LR.to_host(Fg), joinpath(workdir, "gauge.jld2"))
    jqg = juliaqcd_t0(Ug, wm, fm0)
    worst, detail = compare(jqg, jq)
    record("gauge invariance at t = 0", worst <= tol, detail)

    # 5. flowed links against the reference
    nflow, ε = 10, 0.02
    Uf = copy_configuration(U)
    run_flow!(Uf, ε, nflow)
    Fref5 = LR.flow(F, ε, 5)
    Fref10 = LR.flow(Fref5, ε, 5)
    dl = maxdiff_links(host_links(Uf, joinpath(workdir, "flowed.jld2")), LR.to_host(Fref10))
    record("flowed links equal the reference (t = $(nflow * ε))", dl <= tol, @sprintf("max |ΔU| = %.1e", dl))

    # 6. E(t), Q(t) along the flow against the reference
    f = measure_flow_checked(fm0, U)
    times_ok = maxdiff(f.t, [0.0, 0.1, 0.2]) <= 1e-12
    refE = [LR.energy_plaquette(X) for X in (F, Fref5, Fref10)]
    dE = maxdiff(f.E_plaq, refE)
    detail = @sprintf("E plaquette %.1e", dE)
    worst = dE
    if d == 4
        dC = maxdiff(f.E_clover, [LR.energy_clover(X) for X in (F, Fref5, Fref10)])
        dQ = maxdiff(f.Q_clover, [LR.topological_charge_clover(X) for X in (F, Fref5, Fref10)])
        worst = max(worst, dC, dQ)
        detail *= @sprintf(", E clover %.1e, Q clover %.1e", dC, dQ)
    end
    record("E(t), Q(t) equal the reference", times_ok && worst <= tol,
        times_ok ? detail : "flow times $(f.t) ≠ [0, 0.1, 0.2]")

    # 7. gauge invariance along the flow
    fg = measure_flow_checked(fm0, Ug)
    worst = maxdiff(fg.E_plaq, f.E_plaq)
    if d == 4
        worst = max(worst, maxdiff(fg.E_clover, f.E_clover), maxdiff(fg.Q_clover, f.Q_clover),
            maxdiff(fg.Q_improved, f.Q_improved))
    end
    record("gauge invariance along the flow", worst <= tol, @sprintf("max difference %.1e", worst))

    # 8. order of the integrator: E(t = 0.4) with ε = 0.1, 0.05, 0.025, 0.0125
    planes = d * (d - 1) ÷ 2
    Es = Float64[]
    for n in (4, 8, 16, 32)
        V = copy_configuration(U)
        run_flow!(V, 0.4 / n, n)
        push!(Es, 2N * planes * (1 - measure_plaquette(V)))
    end
    diffs = abs.(Base.diff(Es))
    slopes = log2.(diffs[1:end-1] ./ diffs[2:end])
    record("flow integrator is third order", all(s -> 2.6 <= s <= 3.4, slopes),
        "slopes " * join((@sprintf("%.2f", s) for s in slopes), ", ") * " (expect 3)")

    # 9. monotone decrease of the action along the flow, hot start
    H = haar_field(rng, G, L, d)
    Uh = gauge_configuration(L; colors=N, start=:cold, process_grid=ntuple(_ -> 1, d))
    set_links!(Uh, LR.to_host(H), joinpath(workdir, "hot.jld2"))
    fmh = flow_measurement(Uh; step_size=0.02, steps=50, every=1)
    fh = measure_flow_checked(fmh, Uh)
    dS = Base.diff(fh.E_plaq)
    record("flow lowers the action (hot start, t ≤ 1)", all(<(0), dS),
        @sprintf("E: %.3f → %.3f, largest step %.1e", fh.E_plaq[1], fh.E_plaq[end], maximum(dS)))

    # 10. links in SU(N) after the flow
    run_flow!(Uh, 0.02, 50)
    hl = host_links(Uh, joinpath(workdir, "hotflowed.jld2"))
    res = maximum(maximum(maximum(ingroup_residual(G, l[:, :, I])[[:unitarity, :determinant]]) for I in CartesianIndices(L)) for l in hl)
    record("links stay in SU($N) after the flow", res <= 1e-12, @sprintf("max residual %.1e", res))

    # 11. t0 and w0 on a synthetic E(t) = A + B t, plus noise on 20 configurations
    A, B, c = 0.15, 0.12, 0.3
    ts = collect(0.0:0.01:3.0)
    t0x, w0x = exact_scales(A, B, c)
    noisy = [(A + 0.01 * randn(rng)) .+ (B + 0.005 * randn(rng)) .* ts for _ in 1:20]
    mine = flow_scales(ts, A .+ B .* ts; c)
    hist = [GradientFlowHistory(ts, Dict("plaquette" => A .+ B .* ts))]
    theirs = estimate_flow_scales(hist; c)
    jk = jackknife(E -> [flow_scales(ts, E; c)...], noisy; bin=1)
    theirs_n = estimate_flow_scales([GradientFlowHistory(ts, Dict("plaquette" => E)) for E in noisy]; c)
    agree = max(abs(mine.t0 - theirs.t0["plaquette"]), abs(mine.w0 - theirs.w0["plaquette"]),
        abs(jk.value[1] - theirs_n.t0["plaquette"]), abs(jk.value[2] - theirs_n.w0["plaquette"]),
        abs(jk.error[1] - theirs_n.t0_error["plaquette"]), abs(jk.error[2] - theirs_n.w0_error["plaquette"]))
    exact = max(abs(mine.t0 / t0x - 1), abs(mine.w0 / w0x - 1))
    record("t0, w0: two implementations and exact values", agree <= 1e-12 && exact <= 1e-3,
        @sprintf("t0 = %.5f (exact %.5f), w0 = %.5f (exact %.5f), implementations differ by %.1e",
            mine.t0, t0x, mine.w0, w0x, agree))

    ok = all(r -> r[2], RESULTS)
    println(ok ? "ALL PASS" : "SOME CHECKS FAILED")
    return ok
end

exit(main(ARGS) ? 0 : 1)
