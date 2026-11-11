# Run the checks listed in tests/checks.toml and print a summary.
#
#   julia tests/run_checks.jl                          # level=ci
#   julia +1.11 --project=ENV tests/run_checks.jl level=workstation
#   julia --project=ENV tests/run_checks.jl level=all only=pipeline
#
# Options:
#   level=ci|workstation|all   which checks to run (default ci)
#   only=TEXT                  only the checks whose name contains TEXT
#   out=DIR                    where logs go (default: a new temporary
#                              directory, printed at the start)
#
# Each check runs in its own process with the same Julia and the same
# active project as this script. The exit code is 1 when any check fails.
# Julia standard library only.

using TOML, Dates, Printf

const ROOT = normpath(joinpath(@__DIR__, ".."))

function parse_args(args)
    opts = Dict("level" => "ci", "only" => "", "out" => "")
    for a in args
        k, v = occursin('=', a) ? split(a, '='; limit = 2) : (a, "")
        haskey(opts, k) || error("unknown option $(k); known: $(join(keys(opts), ", "))")
        opts[k] = v
    end
    opts["level"] in ("ci", "workstation", "all") || error("level must be ci, workstation, or all")
    return opts
end

function main(args)
    opts = parse_args(args)
    checks = TOML.parsefile(joinpath(ROOT, "tests", "checks.toml"))["check"]
    selected = filter(checks) do c
        (opts["level"] == "all" || c["level"] == opts["level"]) &&
            occursin(opts["only"], c["name"])
    end
    isempty(selected) && error("no check matches level=$(opts["level"]) only=$(opts["only"])")
    out = isempty(opts["out"]) ? mktempdir(; cleanup = false) : mkpath(opts["out"])
    tmp = mkpath(joinpath(out, "work"))
    project = Base.active_project()
    total = sum(c -> get(c, "minutes", 1.0), selected)
    println("== $(length(selected)) checks, about $(round(total; digits = 1)) minutes; logs in $out")
    println("   Julia $(VERSION), project $(project === nothing ? "none" : project)")

    failed_groups = Set{String}()
    rows = Tuple{String,String,Float64}[]
    for (i, c) in enumerate(selected)
        group = get(c, "group", "")
        if !isempty(group) && group in failed_groups
            push!(rows, (c["name"], "SKIP", 0.0))
            @printf("  SKIP  %-48s (an earlier step of group %s failed)\n", c["name"], group)
            continue
        end
        script = joinpath(ROOT, c["script"])
        cargs = [replace(a, "{tmp}" => tmp) for a in get(c, "args", String[])]
        cmd = Cmd(vcat(Base.julia_cmd().exec, ["--project=$(something(project, "@."))", script], cargs))
        log = joinpath(out, @sprintf("%02d.log", i))
        t0 = time()
        ok = open(log, "w") do io
            println(io, "# ", c["name"], "\n# ", join(cmd.exec, " "), "\n")
            flush(io)
            success(pipeline(cmd; stdout = io, stderr = io))
        end
        dt = time() - t0
        status = ok ? "PASS" : "FAIL"
        ok || isempty(group) || push!(failed_groups, group)
        push!(rows, (c["name"], status, dt))
        @printf("  %s  %-48s %7.1f s   %s\n", status, c["name"], dt, ok ? "" : log)
        flush(stdout)
    end
    nfail = count(r -> r[2] != "PASS", rows)
    open(joinpath(out, "summary.md"), "w") do io
        println(io, "Checks run $(Dates.format(now(), "yyyy-mm-dd HH:MM")), Julia $(VERSION), level=$(opts["level"])\n")
        println(io, "| Check | Result | Seconds |\n|---|---|---|")
        for (n, s, dt) in rows
            @printf(io, "| %s | %s | %.0f |\n", n, s, dt)
        end
    end
    println(nfail == 0 ? "ALL PASS" : "$(nfail) of $(length(rows)) did not pass")
    return nfail == 0
end

exit(main(ARGS) ? 0 : 1)
