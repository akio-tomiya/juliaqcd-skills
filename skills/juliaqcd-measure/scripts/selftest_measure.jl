# Self-test of check_measure.jl: the unbroken run must pass every check, and
# each deliberately broken variant must fail the checks named next to it.
#
#   julia --project=ENV selftest_measure.jl [colors=3 lattice=4,4,4,4]
#
# Runs check_measure.jl four times in subprocesses; about 2 minutes for 4^4
# SU(3) on one core.

const CHECK = joinpath(@__DIR__, "check_measure.jl")

const CASES = [
    ("none", String[]),
    # Equals 1 on a cold field, so the cold check alone would miss it.
    ("open_loop", ["t = 0 equals the reference", "gauge invariance at t = 0"]),
    # Still a third-order integrator, so only the reference is required to see
    # the wrong t. (The order check also fails, but only because its largest
    # step becomes 0.2, outside the range where the error scales as ε³.)
    ("flow_double_step", ["flowed links equal the reference", "E(t), Q(t) equal the reference"]),
    ("flow_euler", ["flowed links equal the reference", "flow integrator is third order"]),
]

function run_case(mutation, extra)
    cmd = `$(Base.julia_cmd()) --project=$(Base.active_project()) $CHECK mutation=$mutation $extra`
    out = read(ignorestatus(cmd), String)
    failed = [strip(split(l, "FAIL"; limit=2)[2]) for l in split(out, '\n') if occursin(r"^\s+FAIL", l)]
    return out, failed
end

function main(args)
    ok = true
    for (mutation, must_fail) in CASES
        out, failed = run_case(mutation, args)
        if mutation == "none"
            good = isempty(failed) && occursin("ALL PASS", out)
            println(good ? "PASS    " : "BROKEN  ", "unbroken run passes every check")
            good || print(out)
        else
            missing = [name for name in must_fail if !any(f -> startswith(f, name), failed)]
            good = isempty(missing)
            println(good ? "CAUGHT  " : "MISSED  ", rpad(mutation, 17), " failed: ",
                join((first(split(f, "  ")) for f in failed), "; "))
            good || (println("        expected failures not seen: ", join(missing, ", ")); print(out))
        end
        ok &= good
    end
    println(ok ? "SELFTEST PASS" : "SELFTEST FAIL")
    return ok
end

exit(main(ARGS) ? 0 : 1)
