# Self-test of check_hmc.jl: the unbroken run must pass every check, and each
# deliberately broken variant must fail the checks named next to it.
#
#   julia --project=ENV selftest_hmc.jl [colors=3 lattice=4,4,4,4]
#
# Runs check_hmc.jl four times in subprocesses; about 7 minutes for 4^4 SU(3)
# on one core. Run it on a workstation or cluster node, not on a laptop.

const CHECK = joinpath(@__DIR__, "check_hmc.jl")

const CASES = [
    ("none", String[]),
    ("beta_twice", ["strong coupling", "weak coupling"]),
    ("first_order", ["reversibility", "rms ΔH ∝ δτ²"]),
    # Width √2 with kinetic term p²/2 is, after rescaling MD time by √2, HMC at
    # β/2; <exp(-ΔH)> stays at 1 within errors, so only the known values catch it.
    ("sigma_only", ["strong coupling", "weak coupling"]),
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
            println(good ? "CAUGHT  " : "MISSED  ", rpad(mutation, 12), " failed: ",
                join((first(split(f, "  ")) for f in failed), "; "))
            good || println("        expected failures not seen: ", join(missing, ", "))
        end
        ok &= good
    end
    println(ok ? "SELFTEST PASS" : "SELFTEST FAIL")
    return ok
end

exit(main(ARGS) ? 0 : 1)
