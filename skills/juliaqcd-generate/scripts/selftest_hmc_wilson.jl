# Shows that check_hmc_wilson.jl catches deliberately broken fermion HMC.
# Runs the check once correct and once per broken variant, and passes when
# the correct run passes and every broken run fails the check named for it.
#
#   julia --project=ENV selftest_hmc_wilson.jl
#
# 4^4 SU(2), Wilson–clover on stout links (the most code paths in one run).

const CHECK = joinpath(@__DIR__, "check_hmc_wilson.jl")
const BASE = ["colors=2", "lattice=4,4,4,4", "kappa=0.12", "csw=1.0", "rho=0.1", "smear_iterations=2", "ntraj=40", "therm=10"]

# mutation => the check that must fail
const CASES = [
    ("none", ""),
    ("force_kappa", "rms ΔH ∝ δτ²"),
    ("force_rho", "rms ΔH ∝ δτ²"),
    ("phi_D", "S_F after the heat bath"),
]

function run_case(mutation)
    cmd = `$(Base.julia_cmd()) --project=$(Base.active_project()) $CHECK $BASE mutation=$mutation`
    text = read(pipeline(ignorestatus(cmd); stderr=stdout), String)
    return occursin("ALL PASS", text), text
end

function main()
    allok = true
    for (mutation, must_fail) in CASES
        ok, text = run_case(mutation)
        if mutation == "none"
            good = ok && occursin("ALL PASS", text)
        else
            good = !ok && any(l -> occursin("FAIL", l) && occursin(must_fail, l), split(text, '\n'))
        end
        println(good ? "PASS" : "FAIL", "  ", rpad(mutation, 12), mutation == "none" ? "correct code passes every check" : "caught by \"$must_fail\"")
        good || println(text)
        allok &= good
    end
    println(allok ? "ALL PASS" : "SOME CHECKS FAILED")
    return allok
end

exit(main() ? 0 : 1)
