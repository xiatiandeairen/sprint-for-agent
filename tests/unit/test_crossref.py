"""Cross-file referential integrity — T1 contract tests.

These are the highest-value tests in the suite: they catch drift between
two or more files that form a runtime contract.
"""
from __future__ import annotations

import re
from pathlib import Path

from conftest import has_section, section_body

DECISION_ID_RE = re.compile(r"D\d+-[a-z][a-z0-9-]*")


def _extract_decision_ids_from_mapping(md: str) -> list[str]:
    body = section_body(md, "决策点映射", depth=2)
    assert body is not None, "auto-principles.md is missing `## 决策点映射` — " \
        "this is the authoritative list of auto-mode decision IDs"
    ids = []
    for line in body.splitlines():
        s = line.strip()
        if not s.startswith("|"):
            continue
        if set(s.replace("|", "").replace(" ", "").replace("-", "")) == set():
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if not cells:
            continue
        first = cells[0].strip("`").strip()
        if DECISION_ID_RE.fullmatch(first):
            ids.append(first)
    return ids


def test_auto_principles_required_sections_exist(auto_principles_md: str | None) -> None:
    """
    consumer: the LLM in auto mode reads `## 原则标签` for the principle vocabulary
              and `## 决策点映射` for which decision triggers which self-check
    when:     every auto-mode sprint, at each mandatory decision point
    failure:  missing either section → LLM cannot produce valid self-check blocks
              (G1/G2/G3 require principle labels from the tag section, IDs from
              the mapping section) → handoff reported as incomplete, flow blocks.

    (merged from test_stage_invariants.py — same assertion, better placement as
    it is the prerequisite for every other test in this file.)
    """
    assert auto_principles_md is not None, \
        "skills/sprint/auto-principles.md must exist"
    assert has_section(auto_principles_md, "原则标签", depth=2), \
        "auto-principles.md must contain `## 原则标签`"
    assert has_section(auto_principles_md, "决策点映射", depth=2), \
        "auto-principles.md must contain `## 决策点映射`"
    assert has_section(auto_principles_md, "自检 block 模板", depth=2), \
        "auto-principles.md must contain `## 自检 block 模板`"


def test_auto_principles_mapping_has_ids(auto_principles_md: str | None) -> None:
    """
    consumer: self-check blocks in auto mode must reference `Dn-xxx` IDs from this
              table; downstream tests in this file depend on non-empty extraction
    when:     insight stage's 自动审视汇总 enumerates decisions by ID
    failure:  empty mapping → every self-check block references unknown IDs →
              insight summary renders nothing → user cannot approve/redo.
    """
    assert auto_principles_md is not None
    ids = _extract_decision_ids_from_mapping(auto_principles_md)
    assert len(ids) >= 3, \
        f"决策点映射 must list ≥3 decision IDs, found {ids}"


def test_every_mapping_id_is_referenced_somewhere(
    project_root: Path, auto_principles_md: str | None
) -> None:
    """
    consumer: each `Dn-xxx` row in the mapping table claims "at decision point X
              in stage Y, produce self-check block"; the stage file is where
              this is actually enforced at runtime
    when:     auto-mode sprint reaches the stage referenced by the ID
    failure:  unreferenced ID → self-check for that decision is never triggered
              (auto mode silently skips it), user thinks decision was self-audited
              but it wasn't; also indicates dead spec.
    """
    assert auto_principles_md is not None
    mapping_ids = _extract_decision_ids_from_mapping(auto_principles_md)
    search_files = [
        *(project_root / "stages").glob("*.md"),
        project_root / "skills" / "sprint" / "SKILL.md",
    ]
    combined = "\n".join(p.read_text() for p in search_files if p.is_file())
    unreferenced = [i for i in mapping_ids if i not in combined]
    assert not unreferenced, (
        f"auto-principles.md defines decision IDs {unreferenced} but no stage / "
        f"SKILL.md references them — self-checks will never fire"
    )


def test_every_referenced_id_is_defined_in_mapping(
    project_root: Path, auto_principles_md: str | None
) -> None:
    """
    consumer: auto-mode LLM sees an ID reference in a stage file and looks up its
              principle bindings + template in auto-principles.md's mapping
    when:     auto mode, the LLM reaches that stage's decision point
    failure:  dangling reference → LLM cannot build the self-check block (no
              bound principles to cite) → Hosted Mode hard rule "G1/G2/G3 missing"
              fires → flow blocks with error.
    """
    assert auto_principles_md is not None
    defined = set(_extract_decision_ids_from_mapping(auto_principles_md))
    referenced: set[str] = set()
    for p in [
        *(project_root / "stages").glob("*.md"),
        project_root / "skills" / "sprint" / "SKILL.md",
    ]:
        if not p.is_file():
            continue
        for m in DECISION_ID_RE.finditer(p.read_text()):
            referenced.add(m.group(0))
    undefined = referenced - defined
    assert not undefined, (
        f"stage files / SKILL.md reference IDs {sorted(undefined)} not defined "
        f"in auto-principles.md 决策点映射 — will fail G1/G2/G3 at runtime"
    )


def test_skill_stages_table_files_exist(project_root: Path, skill_md: str) -> None:
    """
    consumer: SKILL.md `## Stages` table tells the LLM (and by extension
              sprint-ctl) which stage-file to load; the LLM reads `stages/{stem}.md`
              literally
    when:     every stage transition
    failure:  table references stages/xxx.md that doesn't exist → LLM has no
              protocol for that stage → hallucinates steps → breaks handoff contract.
    """
    body = section_body(skill_md, "Stages", depth=2)
    assert body is not None, "SKILL.md must contain `## Stages`"
    mentioned = set(re.findall(r"stages/([a-z][a-z0-9_-]*)\.md", body))
    assert mentioned, "SKILL.md ## Stages must reference files like `stages/xxx.md`"
    for stem in mentioned:
        p = project_root / "stages" / f"{stem}.md"
        assert p.is_file(), f"SKILL.md references stages/{stem}.md but file missing"


def test_skill_stages_table_covers_all_stage_files(
    project_root: Path, skill_md: str
) -> None:
    """
    consumer: users (and the LLM during evaluate) rely on SKILL.md's Stages
              table to know the pipeline; orphan files on disk mean someone
              added a stage without wiring it into SKILL.md
    when:     evaluate-stage pipeline construction
    failure:  a stage exists on disk but isn't in the table → evaluate never
              puts it in the pipeline → the stage is dead, but anyone grepping
              stages/ sees it and expects it to run.
    """
    body = section_body(skill_md, "Stages", depth=2)
    assert body is not None
    mentioned = set(re.findall(r"stages/([a-z][a-z0-9_-]*)\.md", body))
    actual = {p.stem for p in (project_root / "stages").glob("*.md")}
    missing_in_skill = actual - mentioned
    assert not missing_in_skill, (
        f"stage files exist on disk but are NOT listed in SKILL.md ## Stages: "
        f"{sorted(missing_in_skill)}"
    )


def test_skill_hosted_mode_count_matches_mapping(
    skill_md: str, auto_principles_md: str | None
) -> None:
    """
    consumer: SKILL.md's Hosted Mode section states "当前 N 个" decision points;
              auto-principles.md's mapping is the authoritative list
    when:     reviewers reading SKILL.md to understand auto mode
    failure:  N claimed in SKILL.md diverges from mapping row count → docs lie;
              if SKILL.md says 6 but mapping has 7, reviewers wouldn't add the
              7th to their mental model of what auto mode covers.
    """
    import pytest as _pt
    assert auto_principles_md is not None
    mapping_count = len(_extract_decision_ids_from_mapping(auto_principles_md))
    hosted_body = section_body(skill_md, "Hosted Mode (`--auto`)", depth=2) \
        or section_body(skill_md, "Hosted Mode", depth=2)
    assert hosted_body is not None
    m = re.search(r"当前\s*(\d+)\s*个", hosted_body)
    if m is None:
        _pt.skip("SKILL.md Hosted Mode states no explicit count (non-strict invariant)")
    else:
        claimed = int(m.group(1))
        assert claimed == mapping_count, (
            f"SKILL.md claims {claimed} decision points, "
            f"auto-principles.md has {mapping_count}"
        )
