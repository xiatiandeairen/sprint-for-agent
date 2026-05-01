"""Schema validator: run SCHEMA_INVARIANTS against a sprint artifact dir.

Pivot from `baseline diff` to `schema validation` (design decision D2/D3):
- Old: compare report vs baseline (could not detect anything useful unless baseline matched fixture exactly)
- New: check sprint artifact against invariants of the sprint protocol itself

Usage:
  python -m compare <sprint_dir>              # single directory
  python -m compare --all                     # all completed sprints under $SPRINT_HOME
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import asdict, dataclass, field
from pathlib import Path

from schema import SCHEMA_INVARIANTS, validate


@dataclass
class SprintReport:
    sprint_id: str
    sprint_dir: str
    passed: list[str] = field(default_factory=list)  # rule names
    failed: list[tuple[str, list[str]]] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.failed


def validate_sprint(sprint_dir: Path) -> SprintReport:
    rep = SprintReport(sprint_id=sprint_dir.name, sprint_dir=str(sprint_dir))
    for name, violations in validate(sprint_dir):
        if violations:
            rep.failed.append((name, violations))
        else:
            rep.passed.append(name)
    return rep


def _sprint_home() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "sprint"


def _project_id(root: Path) -> str:
    return str(root).replace("/", "-")


def _discover_project_dir() -> Path:
    # Same logic as sprint-ctl.sh
    import subprocess
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            check=True, capture_output=True, text=True,
        ).stdout.strip()
        root = Path(out)
    except Exception:
        root = Path.cwd()
    return _sprint_home() / "projects" / _project_id(root)


def discover_sprints(project_dir: Path | None = None) -> list[Path]:
    base = project_dir or _discover_project_dir()
    if not base.is_dir():
        return []
    out = []
    for p in base.iterdir():
        if p.is_dir() and (p / "state.json").is_file():
            out.append(p)
    return sorted(out, key=lambda p: p.name)


def _pretty(rep: SprintReport, verbose: bool = False) -> str:
    total = len(rep.passed) + len(rep.failed)
    status = "PASS" if rep.ok else "FAIL"
    lines = [f"{status} {rep.sprint_id}: {len(rep.passed)}/{total} rules ok"]
    if rep.failed:
        for rule, viols in rep.failed:
            lines.append(f"  ✗ {rule}")
            for v in viols:
                lines.append(f"      - {v}")
    elif verbose:
        for rule in rep.passed:
            lines.append(f"  ✓ {rule}")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="compare", description=__doc__)
    ap.add_argument("path", nargs="?", help="sprint directory (omit with --all)")
    ap.add_argument("--all", action="store_true",
                    help="validate every completed sprint under $SPRINT_HOME")
    ap.add_argument("--json", action="store_true", help="emit JSON array")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args(argv)

    if args.all:
        targets = discover_sprints()
        if not targets:
            print("no sprints discovered under $SPRINT_HOME", file=sys.stderr)
            return 2
    elif args.path:
        targets = [Path(args.path)]
    else:
        ap.error("specify a sprint dir or --all")

    reports = [validate_sprint(t) for t in targets]

    if args.json:
        print(json.dumps([asdict(r) for r in reports], indent=2, ensure_ascii=False))
    else:
        for r in reports:
            print(_pretty(r, verbose=args.verbose))
        n_fail = sum(1 for r in reports if not r.ok)
        n_pass = len(reports) - n_fail
        print()
        print(f"Total: {len(reports)} sprints | {n_pass} PASS | {n_fail} FAIL")

    return 0 if all(r.ok for r in reports) else 1


# Backward-compat shim used by runner.py legacy tests (no longer active).
def compare_fixture(fixture: str) -> int:
    print("compare_fixture is deprecated; use validate_sprint(sprint_dir) instead.",
          file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
