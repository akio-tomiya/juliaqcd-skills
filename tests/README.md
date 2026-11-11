# Tests of the skills

The skills are tested at four levels. The first two test the files and the
scripts; the last two test what an agent does with them.

| Level | What it tests | Command | Where, how long |
|---|---|---|---|
| 1. Static | every SKILL.md has a valid name and a description of at most 1024 characters; every file the skills name exists; every script can be found from the skills; every check is listed in `checks.toml`; the examples are complete in both languages and each has a case; no Japanese in the English files | `julia tests/static_check.jl` | anywhere, seconds; CI |
| 2a. Scripts, standard library | the self-tests that need no packages: groups, the monitor, the analysis | `julia tests/run_checks.jl` | anywhere, about 2 minutes; CI |
| 2b. Scripts, JuliaQCD | every check script against its reference, every self-test against its broken variants, and a small pipeline (generate, restart, monitor, measure, analyze; pure gauge and Nf = 2) | `julia +1.11 --project=ENV tests/run_checks.jl level=workstation` | a workstation, about 30 minutes on one core; never a laptop |
| 3. Trigger | the right skill is invoked from the descriptions alone, and no skill for unrelated requests | `tests/agent/agenttest.py run` | needs a separate Claude Code login |
| 4. Behavior | the first reply and the plan follow the skills and the "Expected" list of the example | `tests/agent/agenttest.py run` or subagents, then `judge` | as level 3 |

Run level 1 after every change to the text, level 2b after every change to
a script or to the JuliaQCD versions, and levels 3 and 4 after a change to
a description or to a rule the agent must follow. `ENV` is a project with
Gaugefields, LatticeDiracOperators, LatticeMatrices, QCDMeasurements, JLD2,
and TOML; `run_checks.jl` prints the logs' folder and writes `summary.md`
there.

## Agent tests

The cases are in `tests/agent/cases.json`. A case either names an example
(its prompt and its "Expected" list come from `examples/prompts.md` or
`prompts.ja.md`) or carries its own prompt. Positive cases list the skills
that fit; negative cases list none. The set `smoke` is a quick regression
run of 13 cases, `full` is all of them.

```
python3 tests/agent/agenttest.py prepare OUT --set smoke
CLAUDE_CONFIG_DIR=TESTCONFIG python3 tests/agent/agenttest.py run OUT
CLAUDE_CONFIG_DIR=TESTCONFIG python3 tests/agent/agenttest.py judge OUT --cli
python3 tests/agent/agenttest.py report OUT
```

`OUT` is a folder outside the repository: the records contain local paths.
`prepare` copies the plugin without `examples/`, `tests/`, and the notes, so
the agent cannot read the expected answers, and gives each case its own
working folder (empty, or filled by a fixture).

`TESTCONFIG` is a Claude Code configuration folder used only for these
tests: log in once with `CLAUDE_CONFIG_DIR=TESTCONFIG claude` and `/login`,
install nothing, and put in its `settings.json`
`"claudeMdExcludes": ["~/.claude/CLAUDE.md", "~/.claude/rules/**"]` with
the paths written out, because the user's own CLAUDE.md is read even with
another configuration folder. The run loads the plugin with `--plugin-dir`,
allows only Read, Glob, Grep, and Skill, and stops after 12 turns, so the
agent runs nothing and its questions stay unanswered. It disables an
installed copy of this plugin, which would hide the copy under test. The
record lists every file read and every search, also outside the plugin
(the agent may read the installed package source), so the judge can tell
a reading from a guess; `reparse` rebuilds the records from the saved
stream after a change to what is recorded.

When the CLI cannot be used, give each `OUT/briefs/ID.md` to a subagent
with no other context. It plays Claude Code with the copied plugin and
writes `OUT/results/ID.json` in the same form. This tests behavior only:
the subagent is told where the skills are, so it says nothing about
triggering. A judge subagent can then grade `OUT/judge/ID.md` and write
`OUT/grades/ID.json` with the keys described in `tests/agent/rubric.md`.

Each run differs: the agent is not deterministic. A single failure is a
reason to read the record, not yet a verdict on the skill; a failure that
repeats is.

## Recording results

Write the date, the commit, the level, the set, the driver, and the result
into the "Tested" line of each example and, for the whole run, into
`tests/RESULTS.md`. Keep the records themselves outside the repository.
