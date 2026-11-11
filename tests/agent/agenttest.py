"""Agent tests of the skills: does the right skill trigger, and does the agent
then behave as the examples say?

    python3 tests/agent/agenttest.py list [--set smoke]
    python3 tests/agent/agenttest.py prepare OUT [--set smoke] [ID ...]
    python3 tests/agent/agenttest.py run OUT [ID ...]        # driver 1: claude -p
    python3 tests/agent/agenttest.py reparse OUT [ID ...]
    python3 tests/agent/agenttest.py judge OUT [--cli] [ID ...]
    python3 tests/agent/agenttest.py report OUT

prepare  copies the plugin without examples/, tests/, and NOTES.md to
         OUT/plugin (the agent must not see the expected answers), makes an
         empty working folder per case (filled by the case's fixture), and
         writes OUT/cases.json (prompts and expected behavior resolved from
         the examples) and OUT/briefs/ID.md (driver 2, below).
run      driver 1. Sends each prompt once to `claude -p` in the case's
         working folder, with the copied plugin loaded by --plugin-dir, shell
         and file-writing tools disabled, and records the skills invoked, every
         file read and search, and the final reply in OUT/results/ID.json. Set
         CLAUDE_CONFIG_DIR to a separate, logged-in configuration with no
         user instructions (see tests/README.md).
         Driver 2, when the CLI cannot be used: give OUT/briefs/ID.md to a
         subagent with no other context; it writes OUT/results/ID.json in
         the same form. It tests behavior only, not triggering.
reparse  rebuilds OUT/results/ID.json from the saved stream OUT/results/ID.jsonl.
judge    writes OUT/judge/ID.md, the grading prompt (tests/agent/rubric.md,
         the expected behavior, and the record). With --cli it also runs
         `claude -p` on it and writes OUT/grades/ID.json; otherwise give the
         prompts to a judge subagent, which writes the same files.
report   writes OUT/summary.md from the results and grades.

Python 3.8 standard library only.
"""
import json
import os
import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
DENY = ("Bash Write Edit NotebookEdit WebFetch WebSearch Task Agent Monitor "
        "Workflow CronCreate CronDelete RemoteTrigger ScheduleWakeup "
        "PushNotification TaskStop")
GRADE_SCHEMA = {
    "type": "object",
    "properties": {
        "expected": {"type": "array", "items": {
            "type": "object",
            "properties": {"item": {"type": "string"},
                           "verdict": {"enum": ["met", "partly", "not met", "n/a"]},
                           "evidence": {"type": "string"}},
            "required": ["item", "verdict", "evidence"]}},
        "general": {"type": "array", "items": {
            "type": "object",
            "properties": {"rule": {"type": "string"},
                           "verdict": {"enum": ["kept", "broken", "n/a"]},
                           "evidence": {"type": "string"}},
            "required": ["rule", "verdict", "evidence"]}},
        "overall": {"enum": ["pass", "pass with remarks", "fail"]},
        "remarks": {"type": "string"},
    },
    "required": ["expected", "general", "overall", "remarks"],
}


def examples(lang):
    """Example number -> (title, prompt, expected bullets)."""
    path = os.path.join(ROOT, "examples", "prompts.ja.md" if lang == "ja" else "prompts.md")
    out = {}
    for sec in re.split(r"^## ", open(path, encoding="utf-8").read(), flags=re.M)[1:]:
        m = re.match(r"(\d+)\. (.*)", sec)
        num, title = int(m.group(1)), m.group(2).strip()
        prompt = "\n".join(l[2:] if l.startswith("> ") else l[1:]
                           for l in sec.splitlines() if l.startswith(">"))
        expected = []
        m = re.search(r"^Expected:\n((?:- .*\n(?:  .*\n)*)+)", sec, flags=re.M)
        if m:
            for item in re.split(r"^- ", m.group(1), flags=re.M)[1:]:
                expected.append(" ".join(item.split()))
        out[num] = (title, prompt.strip(), expected)
    return out


def load_cases(selected_set=None, ids=()):
    data = json.load(open(os.path.join(HERE, "cases.json"), encoding="utf-8"))
    ex = {"en": examples("en"), "ja": examples("ja")}
    cases = []
    for c in data["cases"]:
        if selected_set and selected_set not in c["sets"]:
            continue
        if ids and c["id"] not in ids:
            continue
        c = dict(c)
        if "example" in c:
            title, prompt, _ = ex[c.get("lang", "en")][c["example"]]
            c["title"], c["prompt"] = title, prompt
            c["expected"] = ex["en"][c["example"]][2]
        else:
            c["title"], c["expected"] = c["id"], []
        cases.append(c)
    return cases


def parse_opts(argv):
    out, sel, cli, ids = None, None, False, []
    it = iter(argv)
    for a in it:
        if a == "--set":
            sel = next(it)
        elif a == "--cli":
            cli = True
        elif out is None:
            out = os.path.abspath(a)
        else:
            ids.append(a)
    return out, sel, cli, ids


BRIEF = """You are taking part in a test of a Claude Code plugin. Act as Claude
Code, the coding agent, would act for a new user who has just installed the
plugin. Ignore any memory files and user instructions you may see: this user
has no other setup, and nothing outside the two folders below exists for you.

The plugin is in {plugin}. Its skills are the folders under
{plugin}/skills/. Work as Claude Code does: at first you see only the
`name` and `description` lines at the top of each SKILL.md. Decide from
those alone whether to invoke a skill (you may invoke none). Invoking a
skill means reading its SKILL.md; then follow it, and read the references
and scripts it points to when you need them.

The user's working folder is {work}; what is in it is what the user has.
Treat yourself as having no shell: run nothing that computes, installs, or
changes anything, and change no files except the one result file below.
Read files with Read (and Glob or Grep if you have them; otherwise a
read-only `ls`, `cat`, or `head` is fine), and only under the two folders
above.

The user wrote:

{prompt}

Write your first reply to the user, exactly as you would send it, in the
user's language. The user has not answered anything yet, so stop where you
would wait for them. Then write this JSON file with the Write tool:
{result}

{{"id": "{id}", "driver": "subagent",
 "skills": [the skills you invoked, in order],
 "reads": [the files you read, relative to {plugin}/skills],
 "final": "your first reply to the user, verbatim",
 "plan": "what you would do after the user's answers, one line per step"}}

Return only the path of the file you wrote.
"""


def cmd_prepare(argv):
    out, sel, _, ids = parse_opts(argv)
    cases = load_cases(sel, ids)
    plugin = os.path.join(out, "plugin")
    if os.path.exists(plugin):
        shutil.rmtree(plugin)
    shutil.copytree(ROOT, plugin, ignore=shutil.ignore_patterns(
        "examples", "tests", "NOTES.md", ".git", ".github", ".DS_Store", "runs"))
    for d in ("work", "briefs", "results", "judge", "grades"):
        os.makedirs(os.path.join(out, d), exist_ok=True)
    for c in cases:
        work = os.path.join(out, "work", c["id"])
        if os.path.exists(work):
            shutil.rmtree(work)
        os.makedirs(work)
        if c.get("fixture"):
            subprocess.run([sys.executable, os.path.join(HERE, "fixtures", c["fixture"]), work], check=True)
        with open(os.path.join(out, "briefs", c["id"] + ".md"), "w", encoding="utf-8") as f:
            f.write(BRIEF.format(plugin=plugin, work=work, prompt=c["prompt"], id=c["id"],
                                 result=os.path.join(out, "results", c["id"] + ".json")))
    json.dump(cases, open(os.path.join(out, "cases.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    print(f"prepared {len(cases)} cases in {out}")


def run_one(c, out):
    env = dict(os.environ, ENABLE_CLAUDEAI_MCP_SERVERS="false")
    cmd = ["claude", "-p", c["prompt"], "--output-format", "stream-json", "--verbose",
           "--max-turns", os.environ.get("MAXTURNS", "12"),
           "--disallowedTools", DENY, "--allowedTools", "Read Glob Grep Skill",
           "--strict-mcp-config", "--plugin-dir", os.path.join(out, "plugin"),
           # an installed copy of this plugin would hide the copy under test
           "--settings", '{"enabledPlugins":{"juliaqcd-skills@juliaqcd-skills":false}}']
    p = subprocess.run(cmd, cwd=os.path.join(out, "work", c["id"]), env=env,
                       capture_output=True, text=True,
                       timeout=int(os.environ.get("TIMEOUT", "900")))
    with open(os.path.join(out, "results", c["id"] + ".jsonl"), "w", encoding="utf-8") as f:
        f.write(p.stdout)
    r = dict(parse_stream(p.stdout), id=c["id"], rc=p.returncode, stderr=p.stderr[-500:])
    json.dump(r, open(os.path.join(out, "results", c["id"] + ".json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    return r


def short(path):
    """A path under the plugin as skill/..., under the home folder as ~/..."""
    if "/skills/" in path:
        return path.split("/skills/")[-1]
    home = os.path.expanduser("~")
    return "~" + path[len(home):] if path.startswith(home) else path


def parse_stream(text):
    """Skills, reads, and searches of a stream-json record of claude -p."""
    skills, reads, lookups, tools, final, model = [], [], [], [], "", ""
    for line in text.splitlines():
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        if ev.get("type") == "system" and ev.get("subtype") == "init":
            model = ev.get("model", "")
        if ev.get("type") == "assistant":
            for b in ev["message"].get("content", []):
                if b.get("type") != "tool_use":
                    continue
                tools.append(b["name"])
                inp = b.get("input", {})
                if b["name"] == "Skill":
                    skills.append((inp.get("skill") or inp.get("command") or "").split(":")[-1])
                if b["name"] == "Read":
                    if "/skills/" in inp.get("file_path", ""):
                        reads.append(short(inp["file_path"]))
                    lookups.append("Read " + short(inp.get("file_path", "")))
                if b["name"] in ("Glob", "Grep"):
                    lookups.append(b["name"] + " " + repr(inp.get("pattern", "")) +
                                   (" in " + short(inp["path"]) if inp.get("path") else ""))
        if ev.get("type") == "result":
            final = ev.get("result") or ""
    return {"driver": "cli", "model": model, "skills": skills, "reads": reads,
            "lookups": lookups, "tools": tools, "final": final}


def cmd_run(argv):
    out, _, _, ids = parse_opts(argv)
    cases = [c for c in json.load(open(os.path.join(out, "cases.json"), encoding="utf-8"))
             if not ids or c["id"] in ids]
    with ThreadPoolExecutor(max_workers=int(os.environ.get("WORKERS", "2"))) as ex:
        for r in ex.map(lambda c: run_one(c, out), cases):
            print(r["id"], r["rc"], r["skills"], flush=True)


def cmd_reparse(argv):
    """Rebuild results/ID.json from the saved stream, after a change to parse_stream."""
    out, _, _, ids = parse_opts(argv)
    for c in json.load(open(os.path.join(out, "cases.json"), encoding="utf-8")):
        res = os.path.join(out, "results", c["id"] + ".json")
        raw = os.path.join(out, "results", c["id"] + ".jsonl")
        if (ids and c["id"] not in ids) or not os.path.exists(raw):
            continue
        r = json.load(open(res, encoding="utf-8"))
        r.update(parse_stream(open(raw, encoding="utf-8").read()))
        json.dump(r, open(res, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print(c["id"], len(r["lookups"]), "lookups")


def cmd_judge(argv):
    out, _, cli, ids = parse_opts(argv)
    rubric = open(os.path.join(HERE, "rubric.md"), encoding="utf-8").read()
    todo = []
    for c in json.load(open(os.path.join(out, "cases.json"), encoding="utf-8")):
        res = os.path.join(out, "results", c["id"] + ".json")
        if (ids and c["id"] not in ids) or not os.path.exists(res) or not c["expected"]:
            continue
        r = json.load(open(res, encoding="utf-8"))
        text = (rubric + "\n\n## The case\n\nThe user wrote:\n\n" + c["prompt"] +
                "\n\nExpected behavior:\n" + "".join("- " + e + "\n" for e in c["expected"]) +
                "\n## The record\n\nSkills invoked: " + ", ".join(r.get("skills", [])) +
                ("\nFiles read and searches, in order (all the agent looked at):\n" +
                 "".join("- " + x + "\n" for x in r["lookups"]) if "lookups" in r else
                 "\nFiles read: " + ", ".join(r.get("reads", []))) +
                "\n\nFirst reply to the user:\n\n" + r.get("final", "") +
                ("\n\nPlan after the user's answers:\n\n" + r["plan"] if r.get("plan") else "") +
                "\n\n## Your answer\n\nGrade the record. Return JSON with keys expected, "
                "general, overall, remarks, as described above.\n")
        path = os.path.join(out, "judge", c["id"] + ".md")
        open(path, "w", encoding="utf-8").write(text)
        todo.append((c["id"], path))
    print(f"wrote {len(todo)} grading prompts in {out}/judge")
    if not cli:
        return

    def grade(item):
        cid, path = item
        p = subprocess.run(["claude", "-p", open(path, encoding="utf-8").read(), "--tools", "",
                            "--strict-mcp-config", "--output-format", "json",
                            "--json-schema", json.dumps(GRADE_SCHEMA)],
                           cwd=out, capture_output=True, text=True, timeout=600)
        try:
            g = json.loads(p.stdout)
            g = g.get("structured_output") or json.loads(g["result"])
        except (json.JSONDecodeError, KeyError, TypeError):
            g = {"overall": "error", "remarks": (p.stdout + p.stderr)[-500:]}
        json.dump(g, open(os.path.join(out, "grades", cid + ".json"), "w", encoding="utf-8"),
                  ensure_ascii=False, indent=1)
        return cid, g.get("overall")

    with ThreadPoolExecutor(max_workers=2) as ex:
        for cid, overall in ex.map(grade, todo):
            print(cid, overall, flush=True)


def cmd_report(argv):
    out, _, _, _ = parse_opts(argv)
    cases = json.load(open(os.path.join(out, "cases.json"), encoding="utf-8"))
    lines = ["| Case | Skills invoked | Trigger | Route | Behavior | Not met or broken |",
             "|---|---|---|---|---|---|"]
    for c in cases:
        res = os.path.join(out, "results", c["id"] + ".json")
        if not os.path.exists(res):
            continue
        r = json.load(open(res, encoding="utf-8"))
        inv = [s for s in r.get("skills", []) if s.startswith("juliaqcd")]
        if r.get("driver") == "subagent":
            trig = "n/a"
        elif c["skills"]:
            trig = "pass" if inv else "FAIL"
        else:
            trig = "pass" if not inv else "FAIL"
        route = "n/a" if not c["skills"] else ("pass" if set(inv) & set(c["skills"]) else "FAIL")
        gpath = os.path.join(out, "grades", c["id"] + ".json")
        beh, bad = "", ""
        if os.path.exists(gpath):
            g = json.load(open(gpath, encoding="utf-8"))
            beh = g.get("overall", "")
            bad = "; ".join([e["item"][:60] + " (" + e["verdict"] + ")" for e in g.get("expected", [])
                             if e["verdict"] in ("not met", "partly")] +
                            [e["rule"][:60] + " (broken)" for e in g.get("general", [])
                             if e["verdict"] == "broken"])
        lines.append(f"| {c['id']} | {', '.join(inv) or '-'} | {trig} | {route} | {beh} | {bad} |")
    open(os.path.join(out, "summary.md"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("\n".join(lines))


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cmd, argv = sys.argv[1], sys.argv[2:]
    if cmd == "list":
        _, sel, _, ids = parse_opts(["-"] + argv)
        for c in load_cases(sel, ids):
            print(f"{c['id']:16} {','.join(c['sets']):10} {c['title'][:50]}")
    elif cmd in ("prepare", "run", "reparse", "judge", "report"):
        globals()["cmd_" + cmd](argv)
    else:
        sys.exit(__doc__)


main()
