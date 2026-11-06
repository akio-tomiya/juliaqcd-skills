# Run the group checks and print PASS or FAIL for each.
#
#   julia check_group.jl SU 3
#   julia check_group.jl SO 5
#   julia check_group.jl Sp 4      # USp(4); the argument is the matrix size
#   julia check_group.jl G2
#   julia check_group.jl all
#
# Exit code 0 when every check passes, 1 otherwise.

include(joinpath(@__DIR__, "GaugeGroups.jl"))
using .GaugeGroups

const ALL = [SU(2), SU(3), SU(4), SO(3), SO(4), SO(5), Sp(4), Sp(6), G2()]

function parse_group(args)
    isempty(args) && error("usage: julia check_group.jl SU|SO|Sp N, G2, or all")
    name = args[1]
    name == "all" && return ALL
    name == "G2" && return [G2()]
    n = parse(Int, args[2])
    name == "SU" && return [SU(n)]
    name == "SO" && return [SO(n)]
    name == "Sp" && return [Sp(n)]
    error("unknown group $name")
end

function main(args)
    ok = true
    for G in parse_group(args)
        ok &= print_checks(G, run_checks(G))
    end
    println(ok ? "ALL PASS" : "SOME CHECKS FAILED")
    return ok
end

exit(main(ARGS) ? 0 : 1)
