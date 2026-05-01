"""T1 contract tests: file-to-file joints.

Each test asserts that a claim in one file matches the authority in another file.
Per PRINCIPLES.md: T1 is the highest-value tier — it catches the drift patterns
that have actually broken sprints in practice.
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest

from conftest import section_body


# ── Helpers ───────────────────────────────────────────────────────────────


SPRINT_CTL_CMD_RE = re.compile(r'bash\s+"?\$SPRINT_CTL"?\s+(\w[\w-]*)')
ANCHOR_CHECK_CMD_RE = re.compile(r'bash\s+"?\$ANCHOR_CHECK"?\s+(\S+)')

BASH_CASE_BRANCH_RE = re.compile(r"^([a-z][a-z_-]*)\)\s*$", flags=re.M)
ANCHOR_RULE_CASE_RE = re.compile(
    r"^\s+(MUST_[A-Z_]+|FILE_NOT_MODIFIED)\)\s*$", flags=re.M
)


def _docs_files(project_root: Path) -> list[Path]:
    return [
        project_root / "skills" / "sprint" / "SKILL.md",
        *(project_root / "stages").glob("*.md"),
    ]


# ── C1: docs invoke only sprint-ctl subcommands that actually exist ──────


def test_c1_sprint_ctl_commands_in_docs_are_implemented(project_root: Path) -> None:
    """
    consumer: bash runtime, when the LLM copy-pastes `bash "$SPRINT_CTL" <cmd>` from docs
    when:     any `[RUN]` block execution during a sprint
    failure:  invoking an unknown subcommand prints the usage message and exits 1;
              the sprint pipeline halts at that stage.
    """
    referenced: set[str] = set()
    for p in _docs_files(project_root):
        if p.is_file():
            for m in SPRINT_CTL_CMD_RE.finditer(p.read_text()):
                cmd = m.group(1)
                # Skip placeholder tokens like {id} which regex won't match anyway
                if cmd.startswith("$") or cmd.startswith("{"):
                    continue
                referenced.add(cmd)

    script = (project_root / "scripts" / "sprint-ctl.sh").read_text()
    defined = set(BASH_CASE_BRANCH_RE.findall(script))

    missing = referenced - defined
    assert not missing, (
        f"docs invoke sprint-ctl subcommands {sorted(missing)} that have no case "
        f"branch in scripts/sprint-ctl.sh; pipeline would exit 1 at runtime"
    )


# ── C2: docs invoke anchor-check with the right signature ────────────────


def test_c2_anchor_check_invocation_signature(project_root: Path) -> None:
    """
    consumer: bash runtime, for each `bash "$ANCHOR_CHECK" {sprint_id}` call
    when:     execute stage and anywhere else anchor-check is invoked
    failure:  anchor-check.sh requires exactly one positional arg (sprint id).
              If docs ever show a zero-arg or extra-arg pattern, users copy it
              and hit "Usage: anchor-check.sh <sprint_id>" / exit 1.
    """
    for p in _docs_files(project_root):
        if not p.is_file():
            continue
        text = p.read_text()
        for m in ANCHOR_CHECK_CMD_RE.finditer(text):
            arg = m.group(1)
            # Accept placeholder tokens; reject obviously-empty or multi-word args
            assert arg, f"{p.name}: anchor-check invoked with empty arg"
            # We cannot fully validate placeholder content, but flag if a literal
            # flag (like `--all`) appears, since anchor-check.sh doesn't support them
            assert not arg.startswith("--"), (
                f"{p.name}: anchor-check invoked with `{arg}` — the script has "
                f"no flag parsing, only accepts a sprint id"
            )


# ── C3: SKILL.md's evaluate example uses 0/1 not yes/no ──────────────────


def test_c3_evaluate_args_use_binary_not_yes_no(skill_md: str) -> None:
    """
    consumer: sprint-ctl.sh's `evaluate` subcommand; line 338-339 uses
              `"${1:-0}"` and `set -u`, so passing `yes`/`no` later triggers
              unbound-variable errors
    when:     first `[RUN]` call after evaluate — e.g. early in sprint start
    failure:  SKILL.md historically modeled examples in English (yes/no); a
              copy-paste user or model produces
              `sprint-ctl evaluate yes yes no` → bash aborts with
              `line 360: yes: unbound variable`. This actually happened in
              sprint 20260422-230506-212's first invocation.
    """
    # Flag any literal yes/no tokens directly after SPRINT_CTL evaluate in SKILL.md
    bad = re.findall(
        r'\$SPRINT_CTL"?\s+evaluate\s+(yes|no)\b',
        skill_md,
    )
    assert not bad, (
        f"SKILL.md shows `evaluate {bad}` — sprint-ctl expects 0/1 binaries, "
        f"will trigger bash unbound-variable error at runtime"
    )


# ── C4: state.json schema fields ⊆ sprint-ctl-written fields ─────────────


def _extract_json_fields_from_block(body: str) -> set[str]:
    m = re.search(r"```json\s*\n(.*?)\n```", body, flags=re.S)
    if not m:
        return set()
    return set(re.findall(r'"(\w+)"\s*:', m.group(1)))


def test_c4_state_json_schema_fields_match_sprint_ctl(
    skill_md: str, project_root: Path
) -> None:
    """
    consumer: downstream readers of state.json (insight summary, compare.py
              schema validator, sprint-ctl activate/stage/end all reload state)
    when:     any stage reads state.json after sprint-ctl creates/mutates it
    failure:  docs claim fields (e.g. `auto`) that sprint-ctl doesn't actually
              write → downstream readers expecting them raise KeyError /
              produce missing-value output. Or docs omit a field the code emits
              → reviewers' mental model is incomplete.
    """
    body = section_body(skill_md, "state.json", depth=3)
    assert body is not None, "SKILL.md must document state.json under `## Data Schemas`"
    doc_fields = _extract_json_fields_from_block(body)
    assert doc_fields, "SKILL.md's state.json example has no parseable fields"

    script = (project_root / "scripts" / "sprint-ctl.sh").read_text()
    script_fields = set(re.findall(r'^\s*"(\w+)"\s*:\s*', script, flags=re.M))

    missing_in_script = doc_fields - script_fields
    assert not missing_in_script, (
        f"SKILL.md state.json documents fields {sorted(missing_in_script)} "
        f"but sprint-ctl.sh does not write them; downstream readers will break"
    )


# ── C5: SKILL.md's anchor rule list ⊆ anchor-check.sh dispatched rules ───


def test_c5_anchor_rule_names_match_implementation(
    skill_md: str, project_root: Path
) -> None:
    """
    consumer: anchor-check.sh's per-line dispatch (case ASSERT in ...)
    when:     every execute-stage anchor check
    failure:  plan stage uses a rule name documented in SKILL.md (e.g.
              `MUST_NOT_EXIST`) but anchor-check has no case branch for it →
              the rule silently falls through to `*) echo UNKNOWN` → PASS/FAIL
              counts are wrong and the assertion never actually enforces.
    """
    doc = set(re.findall(r"`(MUST_[A-Z_]+|FILE_NOT_MODIFIED)`", skill_md))
    assert len(doc) >= 6, (
        f"SKILL.md must document several anchor rule types; found {doc}"
    )

    script = (project_root / "scripts" / "anchor-check.sh").read_text()
    impl = set(ANCHOR_RULE_CASE_RE.findall(script))

    missing = doc - impl
    assert not missing, (
        f"SKILL.md documents anchor rules {sorted(missing)} with no "
        f"case branch in anchor-check.sh; these would silently become `UNKNOWN`"
    )


# ── C6: metrics.log event names in docs = strings emitted by scripts ─────


def test_c6_metrics_event_names_match_emitted_strings(
    skill_md: str, project_root: Path
) -> None:
    """
    consumer: insight stage parses metrics.log by event-name; sprint-ctl's
              `end` and `list` / `report` subcommands also read metrics.log
    when:     every sprint end and every report call
    failure:  docs document an event name the scripts never emit (or scripts
              emit an undocumented name) → insight summary under-counts that
              category silently; per-stage duration may show as "0s".
    """
    # Extract events from the metrics.log table rows. Each row's "Format" column
    # contains `sprint_start|...` etc. We rely on the `|` separator in the format.
    body = section_body(skill_md, "metrics.log (append-only, pipe-delimited)", depth=3)
    if body is None:
        body = section_body(skill_md, "metrics.log", depth=3)
    assert body is not None, "SKILL.md must document metrics.log under `## Data Schemas`"
    doc_events = set(re.findall(r"`(\w+)\\\|", body))
    # Sanity: the obvious 5
    expected_minimum = {"sprint_start", "stage_start", "stage_end", "anchor_check", "sprint_end"}
    assert expected_minimum <= doc_events, (
        f"metrics.log table missing standard events: "
        f"{sorted(expected_minimum - doc_events)} (doc had {sorted(doc_events)})"
    )

    scripts_text = (
        (project_root / "scripts" / "sprint-ctl.sh").read_text()
        + (project_root / "scripts" / "anchor-check.sh").read_text()
    )

    missing = []
    for ev in doc_events:
        # Look for the emit pattern: echo "event|..."
        if not re.search(rf'"\s*{re.escape(ev)}\s*\|', scripts_text):
            missing.append(ev)

    assert not missing, (
        f"SKILL.md documents events {missing} but neither sprint-ctl.sh nor "
        f"anchor-check.sh emits them; insight / summary will under-count."
    )
