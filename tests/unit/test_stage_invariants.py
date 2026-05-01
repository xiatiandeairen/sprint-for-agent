"""Retained stage-file invariants — T1 (crossref) / T2 (self-consistency) / T3.

Deleted per PRINCIPLES.md § Three deletion filters:
- `test_stage_has_completion_section` × 6 — Completion has no runtime consumer
- `test_interaction_terms_has_at_least_one_table` — formal existence only
- `test_auto_principles_has_label_and_mapping_sections` — merged into test_crossref.py
  as a shared prerequisite for its referential-integrity checks
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest

from conftest import has_section, section_body

EXPECTED_STAGES = {"brainstorm", "design", "plan", "execute", "review", "insight"}


def test_all_expected_stage_files_exist(project_root: Path) -> None:
    """
    consumer: sprint-ctl.sh's `evaluate` subcommand hardcodes the full stage
              pipeline in its output (`brainstorm,design,plan,execute,[review,]insight`);
              the LLM then reads each corresponding `stages/{stage}.md` per turn
    when:     every `sprint-ctl evaluate` call + every stage transition
    failure:  if a stage file is missing, the LLM in that stage has no protocol —
              it will hallucinate steps / handoff template, breaking the next stage's
              upstream-read.
    """
    names = {p.stem for p in (project_root / "stages").glob("*.md")}
    missing = EXPECTED_STAGES - names
    assert not missing, f"stages/ missing files for: {missing}"


@pytest.mark.parametrize("stage", sorted(EXPECTED_STAGES))
def test_stage_has_progress_section(project_root: Path, stage: str) -> None:
    """
    consumer: SKILL.md's Progress Indicator template (`{stage} ({step}/{total}) — {step_name}`)
              reads total + steps from each stage file's `## Progress` section
    when:     every LLM turn that begins with the progress indicator
    failure:  without `## Progress`, the LLM cannot render the progress bar;
              it either skips the indicator (protocol violation per Output Rules)
              or hallucinates counts.
    """
    md = (project_root / "stages" / f"{stage}.md").read_text()
    assert has_section(md, "Progress", depth=2), \
        f"stages/{stage}.md must contain `## Progress` section"


@pytest.mark.parametrize("stage", sorted(EXPECTED_STAGES))
def test_stage_progress_has_total_and_steps(project_root: Path, stage: str) -> None:
    """
    consumer: progress indicator uses `total` as the denominator and `steps` list
              as the source of step names
    when:     every turn the progress indicator is rendered
    failure:  missing `- total: N` → indicator denominator is unknown → renders
              as `N/?`; missing `- steps:` list → step names fall back to raw
              section titles, which diverges from protocol.
    """
    md = (project_root / "stages" / f"{stage}.md").read_text()
    body = section_body(md, "Progress", depth=2)
    assert body is not None
    assert re.search(r"^\s*-\s*total:\s*\d+\s*$", body, flags=re.M), \
        f"stages/{stage}.md Progress must have `- total: N` line"
    assert re.search(r"^\s*-\s*steps:\s*$", body, flags=re.M), \
        f"stages/{stage}.md Progress must have `- steps:` line"


@pytest.mark.parametrize("stage", sorted(EXPECTED_STAGES))
def test_stage_progress_total_matches_steps_count(project_root: Path, stage: str) -> None:
    """
    consumer: progress indicator shows `{step}/{total}`; step ordinal is
              looked up from the steps list, total from the `- total:` line
    when:     every turn the progress indicator is rendered
    failure:  total=N but only M step entries → indicator shows `3/6` when the
              stage actually has 4 steps → user loses trust in progress; worse,
              code paths that enumerate steps by index run past the end.
    """
    md = (project_root / "stages" / f"{stage}.md").read_text()
    body = section_body(md, "Progress", depth=2)
    assert body is not None
    total_m = re.search(r"^\s*-\s*total:\s*(\d+)\s*$", body, flags=re.M)
    assert total_m
    total = int(total_m.group(1))

    steps_block = re.search(
        r"^\s*-\s*steps:\s*\n((?:\s{2,}\d+\.\s+.*\n?)+)",
        body,
        flags=re.M,
    )
    assert steps_block, f"{stage}.md `- steps:` block not parseable"
    steps = re.findall(r"^\s{2,}(\d+)\.\s+", steps_block.group(1), flags=re.M)
    assert len(steps) == total, (
        f"stages/{stage}.md: total={total} but steps list has {len(steps)} entries"
    )
