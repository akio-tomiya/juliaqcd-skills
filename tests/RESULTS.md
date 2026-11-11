# Test results

One line per run of the tests in `tests/README.md`, newest first. The
records themselves are kept outside the repository. Workstation runs were
on one core of an Apple M4. "Commit" is the commit tested, or, with
"into", the commit that took in the tested working tree.

| Date | Commit | Level | Cases | Driver | Result |
|---|---|---|---|---|---|
| 2026-11-11 | uncommitted after e777acb | 4 behavior | example 25, twice, after the fix to the performance reference | `claude -p`, graded by `claude -p` | 1 pass, 1 pass with remarks |
| 2026-11-11 | uncommitted after e777acb | 4 behavior | retest after the fixes: examples 1, 9, 13, 20, 25, 26 and Japanese 1, 9, 26 | `claude -p`, graded by `claude -p` | 2 pass, 6 pass with remarks, 1 fail (example 25, again; fixed above); retests the fixes of the subagent retest too |
| 2026-11-11 | uncommitted after e777acb | 3 trigger and 4 behavior | full set, 50 cases (28 examples, 5 Japanese, 12 trigger prompts, 5 unrelated) | `claude -p`, Opus 5.5, read-only tools, graded by `claude -p` | trigger: 45 of 45 invoked a fitting skill, 0 of 5 unrelated invoked one; behavior (33 graded): 11 pass, 16 pass with remarks, 6 fail (examples 9, 13, 25, Japanese 1, 9, 26); the records listed only files read under the skills, so the judge took real reads of the package source for guesses (fixed in `agenttest.py`); the other failures led to fixes in the generate, analyze, and visualize skills |
| 2026-11-11 | uncommitted after e777acb | 2b scripts | all 21 workstation checks | `run_checks.jl`, Julia 1.11.9, Gaugefields 1.1.13, LatticeDiracOperators 1.1.6, LatticeMatrices 1.2.11, QCDMeasurements 1.0.2 | all pass, 29 minutes; includes `measure_ensemble.jl` on an Nf = 2 run for the first time |
| 2026-11-11 | uncommitted after e777acb | 4 behavior | retest after the fixes: examples 9, 13, 20, 26 | subagents, graded by a subagent | 1 pass, 3 pass with remarks; the remarks led to three more fixes (an error judged against a remembered size; one of two checks after an update; SU(2) and SU(4) left out twice), not retested |
| 2026-11-11 | uncommitted after e777acb | 4 behavior | smoke set, examples 1, 3, 7, 12, 18, 25 to 28 | subagents, graded by a subagent | 6 pass, 3 pass with remarks; one remark found an error in the debugging reference (fixed) |
| 2026-11-11 | uncommitted after e777acb | 1 static | all | `static_check.jl` | first run: the entry description had 1441 characters (limit 1024); shortened |
| 2026-11-09 | 04be0bd | 3 trigger | 21 prompts (17 lattice, 4 unrelated) | `claude -p` | 17 of 17 invoked a fitting skill; 0 of 4 unrelated invoked one |
| 2026-11-09 | into 484e004 and 4ed3ad8 | 4 behavior | examples 7 to 24 | subagents | all pass, 8 after fixes to the skills (see each example) |
| 2026-11-07 | into 04be0bd | 4 behavior | 17 prompts | subagents | all pass; the remarks led to the fixes of 04be0bd |
| 2026-11-06 | into 04760a0 to 952d9d1 | 4 with computations | examples 1 to 6 | subagents with a shell | all pass; their remarks led to fixes of the scripts |
