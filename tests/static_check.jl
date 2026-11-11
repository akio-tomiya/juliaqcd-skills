# Static checks of the skills: no Julia packages, no computation, seconds.
#
#   julia tests/static_check.jl
#
# Checks that
#   - every SKILL.md has a name equal to its folder and a description of at
#     most 1024 characters;
#   - every file named in the skills (references/…, scripts/…, $SKILLS/…,
#     a lowercase *.jl in backticks, a relative Markdown link) exists, and
#     every include("…") of a script resolves;
#   - every script is named somewhere in the skills, so an agent can find it;
#   - every check and self-test script is listed in tests/checks.toml, and
#     every listed script exists;
#   - the examples are numbered 1, 2, … in both languages, each English
#     example has "Expected:" and a "Tested" or "Not tested" line, and each
#     has a case in tests/agent/cases.json;
#   - the English files contain no Japanese text.
# Prints the size of each skill and of its descriptions. Exit code 1 on any
# error. Julia standard library only.

using TOML, Printf

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SKILLS = joinpath(ROOT, "skills")
errors = String[]
err(msg) = push!(errors, msg)
rel(p) = relpath(p, ROOT)

function files_under(dir, exts)
    out = String[]
    isdir(dir) || return out
    for (d, _, fs) in walkdir(dir), f in fs
        any(endswith(f, e) for e in exts) && push!(out, joinpath(d, f))
    end
    return sort(out)
end

skill_dirs = sort(filter(d -> isfile(joinpath(SKILLS, d, "SKILL.md")), readdir(SKILLS)))
md_files = files_under(SKILLS, (".md",))
jl_files = files_under(SKILLS, (".jl",))
script_names = Set(basename.(jl_files))

# --- frontmatter and sizes
println("== skills (bytes: SKILL.md, references, scripts; description characters)")
desc_total = 0
for s in skill_dirs
    text = read(joinpath(SKILLS, s, "SKILL.md"), String)
    m = match(r"\A---\n(.*?)\n---\n"s, text)
    if m === nothing
        err("skills/$s/SKILL.md: no frontmatter")
        continue
    end
    name = match(r"^name:\s*(.+)$"m, m[1])
    desc = match(r"^description:\s*(.+)$"m, m[1])
    name === nothing || strip(name[1]) == s || err("skills/$s/SKILL.md: name is $(strip(name[1])), folder is $s")
    name === nothing && err("skills/$s/SKILL.md: no name")
    n = desc === nothing ? 0 : length(strip(desc[1]))
    desc === nothing && err("skills/$s/SKILL.md: no description")
    n > 1024 && err("skills/$s/SKILL.md: description has $n characters (limit 1024)")
    global desc_total += n
    refs = sum(filesize, files_under(joinpath(SKILLS, s, "references"), (".md",)); init = 0)
    scr = sum(filesize, files_under(joinpath(SKILLS, s, "scripts"), (".jl",)); init = 0)
    @printf("  %-20s %7d %7d %7d   %4d\n", s, filesize(joinpath(SKILLS, s, "SKILL.md")), refs, scr, n)
end
println("  descriptions in total: $desc_total characters (always in the agent's context)")

# --- named files exist
function skill_of(path)
    parts = splitpath(relpath(path, SKILLS))
    return parts[1]
end

for f in md_files
    text = read(f, String)
    here = skill_of(f)
    for m in eachmatch(r"\$SKILLS/([\w-]+)/((?:scripts|references)/[\w./-]+?\.(?:md|jl))\b", text)
        isfile(joinpath(SKILLS, m[1], m[2])) || err("$(rel(f)): \$SKILLS/$(m[1])/$(m[2]) does not exist")
    end
    for line in eachline(IOBuffer(text))
        # references/x.md or scripts/x.jl: in this skill, or in a skill named on the same line
        named = [here; [s for s in skill_dirs if occursin(s, line)]]
        for m in eachmatch(r"(?<![\w/$-])((?:references|scripts)/[\w./-]+?\.(?:md|jl))\b", line)
            any(s -> isfile(joinpath(SKILLS, s, m[1])), named) || isfile(joinpath(dirname(f), m[1])) ||
                err("$(rel(f)): $(m[1]) does not exist in skills/$here or a skill named on its line")
        end
    end
    # a lowercase *.jl in backticks is one of our scripts (the code map names
    # files of the JuliaQCD packages instead)
    if !occursin("code-map", f)
        for m in eachmatch(r"`([a-z][\w]*\.jl)`", text)
            m[1] in script_names || err("$(rel(f)): `$(m[1])` is not a script of the skills")
        end
    end
    for m in eachmatch(r"\]\(([^)#:]+?\.(?:md|jl))(?:#[^)]*)?\)", text)
        isfile(normpath(joinpath(dirname(f), m[1]))) || err("$(rel(f)): link $(m[1]) does not exist")
    end
end
included = Set{String}()
for f in jl_files
    for m in eachmatch(r"include\((?:joinpath\(\s*@__DIR__\s*,)?([^)]*)\)", read(f, String))
        parts = [x[1] for x in eachmatch(r"\"([^\"]+)\"", m[1])]
        isempty(parts) && continue
        target = normpath(joinpath(dirname(f), parts...))
        isfile(target) ? push!(included, target) :
            err("$(rel(f)): include of $(join(parts, "/")) does not resolve")
    end
end

# --- every script is named somewhere in the Markdown of the skills
all_md = join((read(f, String) for f in md_files), "\n")
for f in jl_files
    occursin(basename(f), all_md) || f in included ||
        err("$(rel(f)): neither named in the skills nor included by a script, so an agent will not find it")
end

# --- checks.toml covers every check and self-test
checks = TOML.parsefile(joinpath(ROOT, "tests", "checks.toml"))["check"]
listed = Set(c["script"] for c in checks)
for c in checks
    isfile(joinpath(ROOT, c["script"])) || err("tests/checks.toml: $(c["script"]) does not exist")
    c["level"] in ("ci", "workstation") || err("tests/checks.toml: $(c["name"]): level must be ci or workstation")
end
for f in jl_files
    b = basename(f)
    (startswith(b, "check_") || startswith(b, "selftest")) && !(rel(f) in listed) &&
        err("$(rel(f)): not listed in tests/checks.toml")
end

# --- examples
function example_numbers(path)
    nums = [parse(Int, m[1]) for m in eachmatch(r"^## (\d+)\. "m, read(path, String))]
    nums == collect(1:length(nums)) || err("$(rel(path)): examples are not numbered 1, 2, …: $nums")
    return nums
end
en = joinpath(ROOT, "examples", "prompts.md")
ja = joinpath(ROOT, "examples", "prompts.ja.md")
nen, nja = example_numbers(en), example_numbers(ja)
nen == nja || err("examples: $(length(nen)) in English, $(length(nja)) in Japanese")
for sec in split(read(en, String), r"^## "m)[2:end]
    num = match(r"^\d+", sec).match
    occursin("\nExpected:", sec) || err("examples/prompts.md: example $num has no \"Expected:\"")
    occursin(r"^(Tested|Not tested)"m, sec) || err("examples/prompts.md: example $num has no \"Tested\" or \"Not tested\" line")
end
casefile = joinpath(ROOT, "tests", "agent", "cases.json")
if isfile(casefile)
    have = Set(parse(Int, m[1]) for m in eachmatch(r"\"example\"\s*:\s*(\d+)", read(casefile, String)))
    for n in nen
        n in have || err("tests/agent/cases.json: no case for example $n")
    end
else
    err("tests/agent/cases.json does not exist")
end

# --- no Japanese in the English files
english = vcat(md_files, jl_files, [en, joinpath(ROOT, "README.md")],
    files_under(joinpath(ROOT, "tests"), (".md", ".jl", ".toml", ".py")))
for f in english
    for (i, line) in enumerate(eachline(f))
        # the link to the Japanese version is allowed
        if occursin(r"[\p{Hiragana}\p{Katakana}\p{Han}]", line) && !occursin(r"\]\([\w./-]+\.ja\.md\)", line)
            err("$(rel(f)):$i: Japanese text in an English file")
            break
        end
    end
end

println()
if isempty(errors)
    println("ALL PASS")
else
    foreach(e -> println("  ERROR ", e), errors)
    println("$(length(errors)) errors")
end
exit(isempty(errors) ? 0 : 1)
