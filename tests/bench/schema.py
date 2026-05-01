"""Sprint artifact schema invariants.

Declarative rule list; compare.py drives the checks.
Each rule: (name, callable(sprint_dir: Path) -> list[str]).
Return empty list = pass; non-empty list = list of violation messages.
"""
from __future__ import annotations

import json
import re
from collections.abc import Callable
from pathlib import Path

KNOWN_STAGES = {"brainstorm", "design", "plan", "execute", "review", "insight"}
KNOWN_EVENTS = {
    "sprint_start", "sprint_end",
    "stage_start", "stage_end",
    "anchor_check",
}
KNOWN_ANCHOR_RULES = {
    "MUST_EXIST", "MUST_NOT_EXIST",
    "MUST_CONTAIN", "MUST_NOT_CONTAIN",
    "MUST_BUILD", "MUST_TEST",
    "MUST_IMPORT", "MUST_NOT_IMPORT",
    "FILE_NOT_MODIFIED",
}

REQUIRED_STATE_FIELDS = {
    "id", "type", "desc", "stages", "status", "current_stage",
    "created_at",
}


def _read_state(sprint_dir: Path) -> dict | None:
    p = sprint_dir / "state.json"
    if not p.is_file():
        return None
    try:
        return json.loads(p.read_text())
    except json.JSONDecodeError:
        return None


# ── Rule implementations ─────────────────────────────────────────────────


def check_state_json_valid(sprint_dir: Path) -> list[str]:
    state_path = sprint_dir / "state.json"
    if not state_path.is_file():
        return ["state.json missing"]
    try:
        data = json.loads(state_path.read_text())
    except json.JSONDecodeError as e:
        return [f"state.json not valid JSON: {e}"]
    missing = REQUIRED_STATE_FIELDS - data.keys()
    if missing:
        return [f"state.json missing fields: {sorted(missing)}"]
    return []


def check_stages_are_known(sprint_dir: Path) -> list[str]:
    data = _read_state(sprint_dir)
    if data is None:
        return []  # covered by check_state_json_valid
    stages = data.get("stages") or []
    if not isinstance(stages, list):
        return [f"state.json.stages must be list, got {type(stages).__name__}"]
    unknown = [s for s in stages if s not in KNOWN_STAGES]
    if unknown:
        return [f"state.json.stages contains unknown names: {unknown}"]
    return []


def check_handoffs_match_stages(sprint_dir: Path) -> list[str]:
    data = _read_state(sprint_dir)
    if data is None:
        return []
    stages = set(data.get("stages") or [])
    # insight never writes a handoff; drop it from expected
    expected = stages - {"insight"}
    handoff_dir = sprint_dir / "handoffs"
    if not handoff_dir.is_dir():
        return (["handoffs/ directory missing"] if expected else [])
    actual = {p.stem for p in handoff_dir.glob("*.md")}
    extra = actual - expected
    missing = expected - actual
    violations = []
    if missing and data.get("status") == "completed":
        violations.append(f"completed sprint is missing handoffs: {sorted(missing)}")
    if extra:
        violations.append(f"handoffs present for non-existent stages: {sorted(extra)}")
    return violations


def check_anchors_valid_syntax(sprint_dir: Path) -> list[str]:
    p = sprint_dir / "anchors.txt"
    if not p.is_file():
        return []  # optional
    bad = []
    for ln_no, raw in enumerate(p.read_text().splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        rule = line.split(None, 1)[0]
        if rule not in KNOWN_ANCHOR_RULES:
            bad.append(f"anchors.txt:{ln_no}: unknown rule `{rule}`")
    return bad


def check_metrics_event_chain(sprint_dir: Path) -> list[str]:
    p = sprint_dir / "metrics.log"
    if not p.is_file():
        return ["metrics.log missing"]

    events: list[tuple[str, list[str]]] = []
    for ln in p.read_text().splitlines():
        if not ln:
            continue
        parts = ln.split("|")
        ev = parts[0]
        if ev not in KNOWN_EVENTS:
            return [f"metrics.log has unknown event `{ev}`"]
        events.append((ev, parts[1:]))

    if not events:
        return ["metrics.log is empty"]

    # sprint_start must be first event (or anywhere but exist)
    if not any(e == "sprint_start" for e, _ in events):
        return ["metrics.log missing sprint_start event"]

    # Pair stage_start / stage_end per stage
    open_stages: list[str] = []
    for ev, fields in events:
        if ev == "stage_start":
            if fields:
                open_stages.append(fields[0])
        elif ev == "stage_end":
            if fields and fields[0] in open_stages:
                open_stages.remove(fields[0])
            else:
                return [f"metrics.log stage_end without matching start: {fields}"]

    data = _read_state(sprint_dir)
    is_completed = data is not None and data.get("status") == "completed"
    if is_completed and open_stages:
        return [f"completed sprint has unclosed stages in metrics.log: {open_stages}"]
    if is_completed and not any(e == "sprint_end" for e, _ in events):
        return ["completed sprint missing sprint_end in metrics.log"]
    return []


def check_handoff_nonempty_with_headings(sprint_dir: Path) -> list[str]:
    """Every written handoff must be non-empty and have ≥1 `##` heading.
    Stricter 'must have Conclusion' was tried and rejected (plan uses
    Execution Mode, not Conclusion — protocol variance)."""
    handoff_dir = sprint_dir / "handoffs"
    if not handoff_dir.is_dir():
        return []
    violations = []
    for p in handoff_dir.glob("*.md"):
        txt = p.read_text().strip()
        if not txt:
            violations.append(f"handoffs/{p.name} is empty")
            continue
        if not re.search(r"^##\s", txt, flags=re.M):
            violations.append(f"handoffs/{p.name} has no `##` section heading")
    return violations


# ── Registry ─────────────────────────────────────────────────────────────

SCHEMA_INVARIANTS: list[tuple[str, Callable[[Path], list[str]]]] = [
    ("state.json is valid and has required fields", check_state_json_valid),
    ("state.json.stages contains only known stage names", check_stages_are_known),
    ("handoff files match the state.stages list", check_handoffs_match_stages),
    ("anchors.txt lines use valid rule types", check_anchors_valid_syntax),
    ("metrics.log event chain is complete and consistent", check_metrics_event_chain),
    ("each handoff is non-empty with section headings", check_handoff_nonempty_with_headings),
]


def validate(sprint_dir: Path) -> list[tuple[str, list[str]]]:
    """Run all invariants. Return list of (rule_name, violations)."""
    results = []
    for name, fn in SCHEMA_INVARIANTS:
        try:
            violations = fn(sprint_dir)
        except Exception as e:
            violations = [f"rule raised {type(e).__name__}: {e}"]
        results.append((name, violations))
    return results
