"""Mutation demos — prove the invariant suite actually catches bad changes.

Each mutation:
  1. Backs up a real project file
  2. Mutates it in a specific way
  3. Runs pytest against the relevant invariant test in a subprocess
  4. Asserts the pytest run EXITS NON-ZERO (i.e. the invariant fired)
  5. Restores the file in a try/finally

Marked with `@pytest.mark.mutation` — excluded by default; run explicitly:
  pytest tests/unit/ -m mutation
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

import pytest

# ── Helpers ───────────────────────────────────────────────────────────────


def _run_pytest(targets: list[Path], project_root: Path) -> int:
    """Run pytest on given test files, return exit code."""
    cmd = [sys.executable, "-m", "pytest", "-q", "--no-header", *map(str, targets)]
    r = subprocess.run(cmd, cwd=str(project_root), capture_output=True)
    return r.returncode


class _Mutator:
    """Save/mutate/restore a file safely."""

    def __init__(self, path: Path):
        self.path = path
        self._original: str | None = None

    def __enter__(self) -> "_Mutator":
        self._original = self.path.read_text()
        return self

    def write(self, new: str) -> None:
        self.path.write_text(new)

    def __exit__(self, exc_type, exc, tb) -> None:
        if self._original is not None:
            self.path.write_text(self._original)


# ── Mutations ─────────────────────────────────────────────────────────────


@pytest.mark.mutation
def test_mut_skill_delete_hard_rules(project_root: Path) -> None:
    """
    consumer: this mutation demo is itself a test of `test_skill_hard_rules_has_enough_bullets`
    when:     `pytest -m mutation`
    failure:  if the skill invariant test can be bypassed by deleting `### Hard Rules`
              without failing — the guard is broken, LLM loses its behavioral floor silently
    """
    skill_md_path = project_root / "skills" / "sprint" / "SKILL.md"
    test_file = project_root / "tests" / "unit" / "test_skill_invariants.py"

    # Sanity: invariant passes currently.
    assert _run_pytest([test_file], project_root) == 0, \
        "pre-mutation: skill invariants must be green"

    with _Mutator(skill_md_path) as m:
        original = skill_md_path.read_text()
        # Delete the entire `### Hard Rules` block (through next `### ` or `## ` heading).
        mutated = re.sub(
            r"### Hard Rules.*?(?=\n### |\n## )",
            "",
            original,
            count=1,
            flags=re.DOTALL,
        )
        assert mutated != original, "mutation did not change anything"
        m.write(mutated)

        rc = _run_pytest([test_file], project_root)
        assert rc != 0, (
            "MUTATION NOT CAUGHT: deleted `### Hard Rules` but "
            "test_skill_invariants still passed"
        )


@pytest.mark.mutation
def test_mut_stage_progress_total_mismatch(project_root: Path) -> None:
    """
    consumer: validates `test_stage_progress_total_matches_steps_count` actually fires
    when:     `pytest -m mutation`
    failure:  if invariant misses this mismatch, progress indicator silently shows
              wrong denominators for whole sprints — reviewers lose trust
    """
    stage_path = project_root / "stages" / "plan.md"
    test_file = project_root / "tests" / "unit" / "test_stage_invariants.py"

    assert _run_pytest([test_file], project_root) == 0, \
        "pre-mutation: stage invariants must be green"

    with _Mutator(stage_path) as m:
        original = stage_path.read_text()
        # Flip `- total: 6` → `- total: 99` (99 definitely won't match step count)
        mutated = re.sub(
            r"(^\s*-\s*total:\s*)\d+\s*$",
            r"\g<1>99",
            original,
            count=1,
            flags=re.M,
        )
        assert mutated != original, "mutation did not change anything"
        m.write(mutated)

        rc = _run_pytest([test_file], project_root)
        assert rc != 0, (
            "MUTATION NOT CAUGHT: total/steps mismatch but stage invariants still passed"
        )


@pytest.mark.mutation
def test_mut_auto_principles_remove_decision_id(project_root: Path) -> None:
    """
    consumer: validates `test_every_referenced_id_is_defined_in_mapping` in test_crossref.py
    when:     `pytest -m mutation`
    failure:  if this referential-integrity guard is broken, stage files can reference
              undefined decision IDs and auto-mode silently fails at runtime
    """
    auto_md = project_root / "skills" / "sprint" / "auto-principles.md"
    test_file = project_root / "tests" / "unit" / "test_crossref.py"

    assert _run_pytest([test_file], project_root) == 0, \
        "pre-mutation: crossref must be green"

    with _Mutator(auto_md) as m:
        original = auto_md.read_text()
        # Remove the mapping row for D3-design-decisions.
        mutated = re.sub(
            r"^\|\s*`D3-design-decisions`\s*\|.*\n",
            "",
            original,
            count=1,
            flags=re.M,
        )
        assert mutated != original, (
            "mutation did not change anything — maybe D3-design-decisions "
            "is not in the mapping row format"
        )
        m.write(mutated)

        rc = _run_pytest([test_file], project_root)
        assert rc != 0, (
            "MUTATION NOT CAUGHT: removed D3-design-decisions from mapping but "
            "crossref tests still passed — referential integrity check is broken"
        )
