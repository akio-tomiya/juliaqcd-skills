# Self-test of monitor.jl on synthetic histories. Julia standard library only;
# runs in seconds anywhere.
#
#   julia selftest_monitor.jl
#
# A healthy synthetic chain must give PASS; each broken chain must give the
# named status on the named item.

using Random

const MONITOR = joinpath(@__DIR__, "monitor.jl")

# AR(1) series with autocorrelation time about (1 + r)/(2(1 - r))
function ar1(rng, n, r; mean=0.0, sd=1.0)
    x = zeros(n)
    x[1] = randn(rng)
    for i in 2:n
        x[i] = r * x[i-1] + sqrt(1 - r^2) * randn(rng)
    end
    return mean .+ sd .* x
end

function write_history(dir; n=2000, drift=false, bias=0.0, frozen=false, seed=1)
    rng = Xoshiro(seed)
    mkpath(dir)
    plaq = ar1(rng, n, 0.6; mean=0.55, sd=0.002)
    drift && (plaq .+= range(-0.05, 0.0; length=n))           # never settles
    !drift && (plaq[1:20] .= range(0.0, 0.55; length=20))      # hot start
    # dH from the exact relation for Gaussian dH: <dH> = var/2 gives <exp(-dH)> = 1
    s = 0.3
    dH = s .* randn(rng, n) .+ s^2 / 2 .- bias
    acc = [rand(rng) < min(1, exp(-d)) for d in dH]
    Q = fill(NaN, n)
    qtrue = frozen ? fill(1.0, n ÷ 10) : round.(ar1(rng, n ÷ 10, 0.3; sd=2.0))
    for (j, k) in enumerate(10:10:n)
        Q[k] = qtrue[j] + 0.03 * randn(rng)
    end
    open(joinpath(dir, "history.csv"), "w") do io
        println(io, "traj,dH,exp_minus_dH,accepted,plaquette,polyakov_re,polyakov_im,Q,seconds")
        for k in 1:n
            println(io, k, ",", dH[k], ",", exp(-dH[k]), ",", Int(acc[k]), ",", plaq[k], ",0,0,", Q[k], ",0.1")
        end
    end
    return dir
end

function monitor_lines(dir)
    out = read(ignorestatus(`$(Base.julia_cmd()) $MONITOR $dir`), String)
    return split(out, '\n')
end

status_of(lines, item) = (l = findfirst(l -> occursin(item, l), lines);
    l === nothing ? "missing" : split(strip(lines[l]))[1])

function main()
    root = mktempdir()
    cases = [
        ("healthy", (;), [("RESULT", "RESULT:"), ("<exp(-dH)> = 1", "PASS"), ("topological charge", "PASS"), ("thermalization", "PASS")]),
        ("energy bias", (; bias=0.1), [("<exp(-dH)> = 1", "FAIL")]),
        ("frozen topology", (; frozen=true), [("topological charge", "WARN")]),
        ("drifting plaquette", (; drift=true), [("thermalization", "WARN")]),
    ]
    ok = true
    for (name, kw, expect) in cases
        lines = monitor_lines(write_history(joinpath(root, replace(name, ' ' => '_')); kw...))
        for (item, want) in expect
            got = status_of(lines, item)
            good = item == "RESULT" ? any(l -> occursin("RESULT: PASS", l), lines) : got == want
            println(good ? "OK      " : "WRONG   ", rpad(name, 20), rpad(item, 22), "expected ",
                item == "RESULT" ? "RESULT: PASS" : want, ", got ", item == "RESULT" ? strip(lines[findfirst(l -> occursin("RESULT", l), lines)]) : got)
            ok &= good
        end
    end
    println(ok ? "SELFTEST PASS" : "SELFTEST FAIL")
    return ok
end

exit(main() ? 0 : 1)
