"""Sprint benchmark runner.

Architectural note: sprint is an AI-driven skill. Automated headless driving
of the full /sprint conversation is out of scope for this harness.
Instead, this runner orchestrates the surrounding work:

  1. `prepare`  — create an isolated SPRINT_HOME for a fixture run
  2. `capture`  — copy the sprint's produced artifacts into reports/{fixture}/{ts}/
  3. `show`     — print fixture description + recommended user replies
                  (so the operator or a Claude Code subagent can drive /sprint)
  4. `compare`  — proxy to compare.py
  5. `judge`    — emit a judge prompt for a Claude Code subagent (no API call)

Usage:
  python -m runner list
  python -m runner show <fixture>
  python -m runner prepare <fixture>     # prints SPRINT_HOME path to export
  python -m runner capture <fixture>     # copies latest sprint under SPRINT_HOME to reports/
  python -m runner compare <fixture>
  python -m runner judge <fixture>       # prints the judge prompt + artifact paths
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

import yaml

BENCH_DIR = Path(__file__).resolve().parent
FIXTURES_DIR = BENCH_DIR / "fixtures"
BASELINES_DIR = BENCH_DIR / "baselines"
REPORTS_DIR = BENCH_DIR / "reports"


@dataclass
class Reply:
    match: str
    reply: str


@dataclass
class Fixture:
    name: str
    description: str
    replies: list[Reply] = field(default_factory=list)
    notes: str = ""
    timeout_sec: int = 900

    @classmethod
    def load(cls, name: str) -> "Fixture":
        path = FIXTURES_DIR / name / "input.yaml"
        if not path.is_file():
            raise FileNotFoundError(f"Fixture not found: {path}")
        data = yaml.safe_load(path.read_text())
        replies = [Reply(**r) for r in data.get("replies", [])]
        return cls(
            name=name,
            description=data["description"],
            replies=replies,
            notes=data.get("notes", ""),
            timeout_sec=int(data.get("timeout_sec", 900)),
        )


@dataclass
class RunArtifacts:
    fixture: str
    sprint_dir: Path
    duration_sec: float
    captured_at: str


def _now_stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def _project_id(path: Path) -> str:
    return str(path).replace("/", "-")


def _sprint_home(workdir: Path) -> Path:
    return workdir / "sprint-home"


def list_fixtures() -> list[str]:
    if not FIXTURES_DIR.is_dir():
        return []
    return sorted(
        p.name for p in FIXTURES_DIR.iterdir()
        if p.is_dir() and (p / "input.yaml").is_file()
    )


def cmd_list(_args) -> int:
    names = list_fixtures()
    if not names:
        print("no fixtures found", file=sys.stderr)
        return 1
    for n in names:
        print(n)
    return 0


def cmd_show(args) -> int:
    fx = Fixture.load(args.fixture)
    print(f"== fixture: {fx.name} ==")
    print(f"description: {fx.description}")
    if fx.notes:
        print(f"notes: {fx.notes}")
    print(f"timeout: {fx.timeout_sec}s")
    print(f"\nreplies ({len(fx.replies)}):")
    for i, r in enumerate(fx.replies, 1):
        print(f"  {i}. when stdout matches: {r.match!r}")
        print(f"     reply: {r.reply!r}")
    print(
        "\nTo drive this fixture:\n"
        "  1. run `python -m runner prepare {name}` and export SPRINT_HOME\n"
        "  2. in Claude Code, run `/sprint {desc}`\n"
        "  3. answer per the replies table above (or delegate to a subagent)\n"
        "  4. run `python -m runner capture {name}`".format(
            name=fx.name, desc=fx.description
        )
    )
    return 0


def cmd_prepare(args) -> int:
    workdir = REPORTS_DIR / args.fixture / f"prep-{_now_stamp()}"
    home = _sprint_home(workdir)
    home.mkdir(parents=True, exist_ok=True)
    print(f"export XDG_DATA_HOME={home.parent}")
    print(f"# sprint data will go to: {home}")
    print(f"# workdir: {workdir}")
    # Persist workdir path so `capture` can find it.
    pointer = REPORTS_DIR / args.fixture / ".current"
    pointer.parent.mkdir(parents=True, exist_ok=True)
    pointer.write_text(str(workdir))
    return 0


def _find_latest_sprint(sprint_home: Path, project_path: Path) -> Path | None:
    pdir = sprint_home / "projects" / _project_id(project_path)
    if not pdir.is_dir():
        return None
    candidates = sorted(
        [p for p in pdir.iterdir() if p.is_dir() and len(p.name) == 19],
        key=lambda p: p.name,
    )
    return candidates[-1] if candidates else None


def cmd_capture(args) -> int:
    pointer = REPORTS_DIR / args.fixture / ".current"
    if not pointer.is_file():
        print("no prepared workdir; run `prepare` first", file=sys.stderr)
        return 2
    workdir = Path(pointer.read_text().strip())
    home = _sprint_home(workdir)

    project_root = Path(
        subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            check=True, capture_output=True, text=True,
        ).stdout.strip()
    )
    latest = _find_latest_sprint(home, project_root)
    if latest is None:
        print(f"no sprint found under {home}", file=sys.stderr)
        return 3

    dest = REPORTS_DIR / args.fixture / _now_stamp()
    dest.mkdir(parents=True, exist_ok=True)
    shutil.copytree(latest, dest / "sprint", dirs_exist_ok=True)
    latest_link = REPORTS_DIR / args.fixture / "latest"
    if latest_link.exists() or latest_link.is_symlink():
        latest_link.unlink()
    latest_link.symlink_to(dest.name)

    print(f"captured: {dest}/sprint")
    print(f"latest -> {latest_link}")
    return 0


def cmd_compare(args) -> int:
    """Schema-validate a single sprint directory (post-pivot).
    Legacy fixture-baseline mode is removed."""
    from compare import validate_sprint, _pretty

    target = Path(args.fixture)
    if not target.is_dir():
        print(f"not a sprint directory: {target}", file=sys.stderr)
        return 2
    rep = validate_sprint(target)
    print(_pretty(rep, verbose=True))
    return 0 if rep.ok else 1


def cmd_judge(args) -> int:
    from judge import emit_judge_prompt

    emit_judge_prompt(args.fixture)
    return 0


def cmd_replay(args) -> int:
    """Replay: validate every historical sprint under $SPRINT_HOME and write
    a summary report to reports/replay-{ts}.json."""
    from compare import discover_sprints, validate_sprint

    targets = discover_sprints()
    if not targets:
        print("no sprints discovered under $SPRINT_HOME", file=sys.stderr)
        return 2

    reports = [validate_sprint(t) for t in targets]
    n_pass = sum(1 for r in reports if r.ok)
    n_fail = len(reports) - n_pass

    # Aggregate violation counts by rule name.
    rule_counts: dict[str, int] = {}
    for r in reports:
        for rule, _ in r.failed:
            rule_counts[rule] = rule_counts.get(rule, 0) + 1

    summary = {
        "generated_at": _now_stamp(),
        "total": len(reports),
        "pass": n_pass,
        "fail": n_fail,
        "violations_by_rule": dict(sorted(rule_counts.items(), key=lambda kv: -kv[1])),
        "failures": [
            {
                "sprint_id": r.sprint_id,
                "failed_rules": [name for name, _ in r.failed],
            }
            for r in reports if not r.ok
        ],
    }

    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    out = REPORTS_DIR / f"replay-{summary['generated_at']}.json"
    out.write_text(json.dumps(summary, indent=2, ensure_ascii=False))

    print(f"Replay summary: {n_pass}/{len(reports)} PASS, {n_fail} FAIL")
    if rule_counts:
        print("\nTop protocol-drift rules:")
        for rule, n in summary["violations_by_rule"].items():
            print(f"  [{n:3d}] {rule}")
    print(f"\nFull report: {out}")
    return 0 if n_fail == 0 else 1


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="runner", description=__doc__)
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("list").set_defaults(func=cmd_list)

    s = sub.add_parser("show")
    s.add_argument("fixture")
    s.set_defaults(func=cmd_show)

    s = sub.add_parser("prepare")
    s.add_argument("fixture")
    s.set_defaults(func=cmd_prepare)

    s = sub.add_parser("capture")
    s.add_argument("fixture")
    s.set_defaults(func=cmd_capture)

    s = sub.add_parser("compare")
    s.add_argument("fixture")
    s.set_defaults(func=cmd_compare)

    s = sub.add_parser("judge")
    s.add_argument("fixture")
    s.set_defaults(func=cmd_judge)

    s = sub.add_parser("replay", help="validate all historical sprints")
    s.set_defaults(func=cmd_replay)

    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
