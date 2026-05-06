"""Runner for sprint-for-code behavior tests.

Two commands:
  emit  [case]            — print subagent prompt (batch if no case given)
  check <output> [case]   — diff subagent JSON output vs expected.json
  render-handoff [case]   — write markdown handoff samples from expected.json

No Anthropic SDK. Evaluation is performed by a Claude Code subagent invoked
separately via the Agent tool.

Cases without `input.execution` test §4.1 only.
Cases with `input.execution` test §4.1 plus normalized §4.2-§4.4 handoff state.
"""
from __future__ import annotations

import argparse
import difflib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SKILL_PATH = ROOT.parent.parent.parent / "skills" / "sprint-for-code" / "SKILL.md"
GENERATED_HANDOFF_DIR = ROOT / ".generated-handoffs"


def list_cases() -> list[str]:
    return sorted(
        p.name for p in ROOT.iterdir()
        if p.is_dir() and (p / "input.json").is_file()
    )


def load_case(name: str) -> dict:
    case_dir = ROOT / name
    inp = json.loads((case_dir / "input.json").read_text())
    exp = json.loads((case_dir / "expected.json").read_text())
    return {"name": name, "input": inp, "expected": exp}


def emit_prompt(cases: list[str]) -> str:
    blocks = []
    template = {}
    for c in cases:
        case = load_case(c)
        inp = case["input"]
        template[c] = {"stages": [], "sequence": ""}
        if "execution" in inp:
            template[c]["handoff"] = {
                "frontmatter": {},
                "stage_entries": [],
                "runtime": {},
                "finalize": {},
            }

        execution = ""
        if "execution" in inp:
            execution = (
                "\nexecution fixture for §4.2-§4.4 simulation:\n"
                + json.dumps(inp["execution"], indent=2, ensure_ascii=False)
            )

        blocks.append(
            f"### CASE {c}\n"
            f"desc: {inp['desc']}\n"
            f"user_replies (in order, applied at §4.1 confirmation prompt):\n"
            + "\n".join(f"  {i+1}. {r}" for i, r in enumerate(inp["replies"]))
            + execution
        )

    template_json = json.dumps(template, indent=2, ensure_ascii=False)

    return f"""You are testing the sprint-for-code skill.

SKILL spec to follow strictly:
  {SKILL_PATH}

For every CASE below, simulate §4.1 in full:
  1. Apply §4.1 step 2 (Stage 挂载规则) to determine mounted stages.
  2. Apply §4.1 step 3 (parallel / loop rules) to determine the recommended flow.
  3. Apply each user reply in order:
       - "yes" / "确认" / "ok" → finalize and stop applying further replies
       - stage adjustment, such as "加 verify" / "不用 plan" → mutate stages list; re-evaluate flow; require next reply
       - flow adjustment, such as "关掉写-验证循环" / "开 implement 并行" → mutate flow; require next reply
  4. After the final yes-equivalent reply, compute the final outputs:
       - stages: list of mounted stage names in fixed order
                 [clarify, explore, design, plan, implement, verify, reflect]
                 (omit unmounted)
       - sequence: single-line execution flow per §4.3 step 1, using the format:
                 stageA → stageB → loop(stageX → stageY) max=N → stageZ
                 (English stage names; loops as `loop(...) max=N`; omit `until` clause)

For CASES with an `execution fixture`, also simulate §4.2-§4.4. Do not create files.
Return a normalized `handoff` object instead of raw markdown:
  - frontmatter:
      id: fixture.sid
      type: "sprint-for-code"
      desc: original desc
      sequence: final sequence
      created: fixture.created
  - stage_entries: append-stage records in exact execution order. Use:
      number: SPRINT_N starting at 1
      stage: stage name
      round: loop round number, or null outside loops
      task: parallel task name, or null outside parallel
      body: lookup from fixture.stage_bodies by exact key:
            normal stage: "stage"
            loop stage: "stage#roundN"
            parallel stage: "task_name/stage"
  - runtime: final Runtime section state after execution, before finalize.
      cursor is the last execution unit written by §4.3.
      loop_active is "" when cleared, otherwise the active loop stage.
      parallel_completed is the final YAML array content as a JSON list.
  - finalize:
      status: "completed" unless fixture.status says otherwise
      completed_at: fixture.completed_at
      insight: include only non-empty normalized insight fields.
        sequence_adjust_reason must be "<动作> — <理由>" when user adjusted stage/flow.

Execution fixture fields:
  - sid, created, completed_at: deterministic metadata timestamps.
  - stage_bodies: body strings used for appended stage records.
  - loop_results: optional list of result keywords for loop terminal stages; `fail`/`partial` continue, `pass`/`done` exits.
  - parallel_tasks: optional ordered task names read from the previous stage body.
  - status: optional final status override.

Return STRICT JSON matching this exact shape, filling each case's stages and sequence
based on the simulation. No prose, no markdown, no code fences.

{template_json}

Cases:

""" + "\n\n".join(blocks)


def normalized(value: object) -> str:
    return json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True)


def check(output_path: Path, only: str | None) -> int:
    out = json.loads(output_path.read_text())
    cases = [only] if only else list_cases()
    fails = 0
    for c in cases:
        case = load_case(c)
        actual = out.get(c)
        if actual is None:
            print(f"FAIL {c}: missing in output")
            fails += 1
            continue
        exp = case["expected"]
        if actual != exp:
            print(f"FAIL {c}")
            diff = difflib.unified_diff(
                normalized(exp).splitlines(),
                normalized(actual).splitlines(),
                fromfile=f"{c}/expected.json",
                tofile=f"{c}/actual.json",
                lineterm="",
            )
            print("\n".join(diff))
            fails += 1
        else:
            print(f"PASS {c}")
    print(f"\n{len(cases) - fails}/{len(cases)} pass")
    return 1 if fails else 0


def render_stage_title(entry: dict) -> str:
    suffix = ""
    if entry.get("round") is not None:
        suffix = f" (round {entry['round']})"
    if entry.get("task") is not None:
        suffix = f" (task: {entry['task']})"
    return f"### {entry['number']}. {entry['stage']}{suffix}"


def render_handoff(case_name: str, handoff: dict) -> str:
    fm = handoff["frontmatter"]
    runtime = handoff["runtime"]
    finalize = handoff["finalize"]
    insight = finalize.get("insight", {})

    stages = "\n\n".join(
        f"{render_stage_title(entry)}\n\n{entry['body']}"
        for entry in handoff["stage_entries"]
    )
    completed = json.dumps(runtime["parallel_completed"], ensure_ascii=False)
    insight_lines = []
    if reason := insight.get("sequence_adjust_reason"):
        insight_lines.append(f"  sequence_adjust_reason: {reason}")
    insight_body = "\n".join(insight_lines)
    if insight_body:
        insight_body += "\n"

    return f"""---
id: {fm['id']}
type: {fm['type']}
desc: {fm['desc']}
sequence: {fm['sequence']}
created: {fm['created']}
---

# Sprint Handoff — {fm['desc']}

<!-- generated from tests/units/sprint-for-code/{case_name}/expected.json -->

## Stages
<!-- SECTION: stages -->
{stages}
<!-- /SECTION: stages -->

## Runtime
<!-- SECTION: runtime -->
cursor: {runtime['cursor']}
loop:
  active: {runtime['loop_active']}
parallel:
  completed: {completed}
<!-- /SECTION: runtime -->

## Finalize
<!-- SECTION: finalize -->
status: {finalize['status']}
completed_at: {finalize['completed_at']}
insight:
{insight_body}<!-- /SECTION: finalize -->
"""


def render_handoffs(only: str | None) -> int:
    cases = [only] if only else list_cases()
    GENERATED_HANDOFF_DIR.mkdir(parents=True, exist_ok=True)
    wrote = 0
    for c in cases:
        if not (ROOT / c).is_dir():
            print(f"ERROR: case not found: {c}", file=sys.stderr)
            return 2
        case = load_case(c)
        handoff = case["expected"].get("handoff")
        if handoff is None:
            if only:
                print(f"ERROR: case has no handoff expectation: {c}", file=sys.stderr)
                return 2
            continue
        out_path = GENERATED_HANDOFF_DIR / f"{c}.md"
        out_path.write_text(render_handoff(c, handoff))
        print(out_path)
        wrote += 1
    print(f"\n{wrote} handoff sample(s) written")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    p_emit = sub.add_parser("emit")
    p_emit.add_argument("case", nargs="?")
    p_check = sub.add_parser("check")
    p_check.add_argument("output")
    p_check.add_argument("case", nargs="?")
    p_render = sub.add_parser("render-handoff")
    p_render.add_argument("case", nargs="?")
    args = ap.parse_args()

    if args.cmd == "emit":
        cases = [args.case] if args.case else list_cases()
        for c in cases:
            if not (ROOT / c).is_dir():
                print(f"ERROR: case not found: {c}", file=sys.stderr)
                return 2
        print(emit_prompt(cases))
        return 0

    if args.cmd == "check":
        out_path = Path(args.output)
        if not out_path.is_file():
            print(f"ERROR: output file not found: {out_path}", file=sys.stderr)
            return 2
        return check(out_path, args.case)

    if args.cmd == "render-handoff":
        return render_handoffs(args.case)

    return 2


if __name__ == "__main__":
    sys.exit(main())
