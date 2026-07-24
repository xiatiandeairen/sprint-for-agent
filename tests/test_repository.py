from __future__ import annotations

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CODE_SKILL = ROOT / "skills" / "sprint-for-code" / "SKILL.md"
ANALYSIS_SKILL = ROOT / "skills" / "sprint-for-analysis" / "SKILL.md"


def frontmatter(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    match = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not match:
        raise AssertionError(f"missing frontmatter: {path}")

    result: dict[str, str] = {}
    current_key: str | None = None
    for raw_line in match.group(1).splitlines():
        if raw_line.startswith((" ", "\t")) and current_key:
            result[current_key] += " " + raw_line.strip()
            continue
        key, separator, value = raw_line.partition(":")
        if separator:
            current_key = key.strip()
            result[current_key] = value.strip().strip('"')
    return result


class RepositoryTests(unittest.TestCase):
    def test_skill_entrypoints(self) -> None:
        self.assertEqual(frontmatter(CODE_SKILL)["name"], "sprint-for-code")
        self.assertEqual(frontmatter(ANALYSIS_SKILL)["name"], "sprint-for-analysis")
        self.assertTrue((CODE_SKILL.parent / "agents" / "openai.yaml").is_file())
        self.assertTrue((ANALYSIS_SKILL.parent / "agents" / "openai.yaml").is_file())

    def test_plugin_versions_are_consistent(self) -> None:
        plugin = json.loads((ROOT / ".claude-plugin" / "plugin.json").read_text())
        marketplace = json.loads(
            (ROOT / ".claude-plugin" / "marketplace.json").read_text()
        )
        entry = marketplace["plugins"][0]
        self.assertEqual(plugin["name"], "sprint")
        self.assertEqual(entry["name"], plugin["name"])
        self.assertEqual(entry["version"], plugin["version"])

    def test_code_skill_uses_problem_driven_contract(self) -> None:
        text = CODE_SKILL.read_text(encoding="utf-8")
        required = {
            "change",
            "review",
            "optimize",
            "动态问题",
            "证据门禁",
            "bug",
            "feature",
            "refactor",
            "docs",
            "code-review",
            "performance",
            "reliability",
            "passed",
            "partial",
            "blocked",
        }
        for term in required:
            with self.subTest(term=term):
                self.assertIn(term, text)

        forbidden = {
            "loop(",
            "parallel(",
            "SECTION: runtime",
            "SPRINT_SID",
            "开始？(yes",
        }
        for term in forbidden:
            with self.subTest(term=term):
                self.assertNotIn(term, text)

        self.assertLess(len(text.splitlines()), 800)

    def test_code_skill_has_no_legacy_stage_tree(self) -> None:
        self.assertFalse((CODE_SKILL.parent / "stages").exists())
        self.assertFalse((CODE_SKILL.parent / "templates").exists())
        self.assertFalse((ROOT / "tests" / "units").exists())
        self.assertFalse((ROOT / "docs").exists())

    def test_local_markdown_links_resolve(self) -> None:
        link_pattern = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
        broken: list[str] = []
        for path in ROOT.rglob("*.md"):
            if ".git" in path.parts:
                continue
            for target in link_pattern.findall(path.read_text(encoding="utf-8")):
                target = target.strip().split("#", 1)[0]
                if not target or "://" in target or target.startswith("mailto:"):
                    continue
                if not (path.parent / target).resolve().exists():
                    broken.append(f"{path.relative_to(ROOT)} -> {target}")
        self.assertEqual(broken, [])


if __name__ == "__main__":
    unittest.main()
