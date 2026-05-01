"""Shared pytest fixtures for markdown invariant tests."""
from __future__ import annotations

import re
from pathlib import Path

import pytest


def _walk_up_for(name: str, start: Path) -> Path | None:
    for p in [start, *start.parents]:
        if (p / name).exists():
            return p
    return None


@pytest.fixture(scope="session")
def project_root() -> Path:
    # tests/unit/ → .. → ..
    here = Path(__file__).resolve()
    candidate = here.parent.parent.parent
    assert (candidate / "skills" / "sprint" / "SKILL.md").exists(), \
        f"skills/sprint/SKILL.md not found under {candidate}"
    assert (candidate / "stages").is_dir(), f"stages/ not found under {candidate}"
    return candidate


@pytest.fixture(scope="session")
def skill_md_path(project_root: Path) -> Path:
    return project_root / "skills" / "sprint" / "SKILL.md"


@pytest.fixture(scope="session")
def skill_md(skill_md_path: Path) -> str:
    return skill_md_path.read_text()


@pytest.fixture(scope="session")
def stage_files(project_root: Path) -> list[Path]:
    return sorted((project_root / "stages").glob("*.md"))


@pytest.fixture(scope="session")
def auto_principles_md(project_root: Path) -> str | None:
    p = project_root / "skills" / "sprint" / "auto-principles.md"
    return p.read_text() if p.is_file() else None


@pytest.fixture(scope="session")
def interaction_terms_md(project_root: Path) -> str | None:
    p = project_root / "skills" / "sprint" / "interaction-terms.md"
    return p.read_text() if p.is_file() else None


# ── Helpers shared across test modules ────────────────────────────────────

def find_sections(md: str) -> list[tuple[int, str, str]]:
    """Return (depth, title, body) for every ATX heading in md."""
    out = []
    lines = md.splitlines()
    cur_depth = None
    cur_title = None
    cur_start = None
    for i, line in enumerate(lines):
        m = re.match(r"^(#+)\s+(.*?)\s*$", line)
        if m:
            if cur_depth is not None:
                body = "\n".join(lines[cur_start:i])
                out.append((cur_depth, cur_title, body))
            cur_depth = len(m.group(1))
            cur_title = m.group(2).strip()
            cur_start = i + 1
    if cur_depth is not None:
        out.append((cur_depth, cur_title, "\n".join(lines[cur_start:])))
    return out


def has_section(md: str, title: str, depth: int | None = None) -> bool:
    for d, t, _ in find_sections(md):
        if t == title and (depth is None or d == depth):
            return True
    return False


def section_body(md: str, title: str, depth: int | None = None) -> str | None:
    """Return body of the matched section, up to the next heading of equal or
    shallower depth (so subsections remain included)."""
    lines = md.splitlines()
    start = None
    stop_depth = None
    for i, line in enumerate(lines):
        m = re.match(r"^(#+)\s+(.*?)\s*$", line)
        if not m:
            continue
        d = len(m.group(1))
        t = m.group(2).strip()
        if start is None:
            if t == title and (depth is None or d == depth):
                start = i + 1
                stop_depth = d
        else:
            if d <= stop_depth:
                return "\n".join(lines[start:i])
    if start is not None:
        return "\n".join(lines[start:])
    return None
