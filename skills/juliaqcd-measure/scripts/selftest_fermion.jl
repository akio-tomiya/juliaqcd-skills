# Self-test of check_fermion.jl: the unbroken run must pass every check, and
# each deliberately broken variant must fail the checks named next to it.
#
#   julia --project=ENV selftest_fermion.jl [colors=3 lattice=4,4,4,6]
#
# Runs check_fermion.jl five times in subprocesses; about 4 minutes for
# 4x4x4x6 SU(3) on one core.

const CHECK = joinpath(@__DIR__, "check_fermion.jl")

const CASES = [
    ("none", String[]),
    # A wrong boundary condition changes only the hops across t = L₄, so the
    # phases, the operator check, and the free spectrum must all see it.
    ("bc_periodic", ["spinor round trip and boundary phases",
        "Wilson: D ψ and D† ψ equal the reference", "free field: spectrum of D"]),
    # A wrong clover normalization leaves Wilson, γ5-hermiticity, and gauge
    # covariance intact: only the reference sees it.
    ("csw_halved", ["Wilson–clover: D ψ and D† ψ equal the reference",
        "Wilson–clover: 16 channels"]),
    ("dagger_is_D", ["Wilson: D ψ and D† ψ equal the reference", "Wilson: γ5 D γ5 = D†"]),
    # The free field is translation invariant, so only the rough field sees a
    # source in the wrong place.
    ("source_shift", ["Wilson: 16 channels", "Wilson–clover: 16 channels"]),
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
            println(good ? "CAUGHT  " : "MISSED  ", rpad(mutation, 13), " failed: ",
                join((first(split(f, "  ")) for f in failed), "; "))
            good || (println("        expected failures not seen: ", join(missing, ", ")); print(out))
        end
        flush(stdout)
        ok &= good
    end
    println(ok ? "SELFTEST PASS" : "SELFTEST FAIL")
    return ok
end

exit(main(ARGS) ? 0 : 1)
