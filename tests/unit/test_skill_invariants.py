"""Retained SKILL.md invariants — T3 behavior-critical content only.

All prior T3 existence checks for sections with no runtime consumer have been
deleted per tests/unit/PRINCIPLES.md (§ Three deletion filters).
"""
from __future__ import annotations

from conftest import section_body


def test_skill_hard_rules_has_enough_bullets(skill_md: str) -> None:
    """
    consumer: the LLM at the start of every sprint turn reads the Hard Rules list
              and applies them as non-negotiable behavioral constraints
    when:     every LLM turn (SKILL.md is always in context)
    failure:  if Hard Rules section is empty or gutted, the LLM has no
              behavioral floor — sprints start mixing refactor+feature in one
              task, skipping anchor checks, etc. Observable as protocol drift
              in the next sprint's handoffs.

    (replaces the prior weaker `exists` check — existence without content is
    meaningless once a reviewer deletes all bullets but keeps the heading.)
    """
    body = section_body(skill_md, "Hard Rules", depth=3)
    assert body is not None, "SKILL.md must contain `### Hard Rules` under `## Rules`"
    bullets = [ln for ln in body.splitlines() if ln.strip().startswith("- ")]
    assert len(bullets) >= 5, (
        f"Hard Rules must have ≥5 bullet rules (the behavioral floor the LLM "
        f"applies every turn); found {len(bullets)}"
    )
