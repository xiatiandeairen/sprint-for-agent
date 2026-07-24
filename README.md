# Sprint for Agent

Problem-driven skills for software engineering and decision-grade analysis.

Sprint does not force agents through a stage pipeline. It selects only the questions that can materially affect the result, resolves discoverable questions autonomously, and asks the user only for scope, authority, risk, or value decisions.

[中文](README_zh.md)

## Skills

### `sprint-for-code`

Use for code, configuration, tests, build files, repository engineering documentation, implementation reviews, code review, performance optimization, and reliability optimization.

It recognizes three task shapes:

```text
change:   goal → solution → Eval → implement ⇄ Eval → evidence gate
review:   goal → review criteria → inspect ⇄ challenge → evidence gate
optimize: metric → baseline → hypothesis → change ⇄ remeasure → evidence gate
```

Questions come from a small core, task-specific domain checks, and new uncertainties discovered during execution. The skill has no fixed stage DSL, mandatory flow confirmation, or default handoff archive.

### `sprint-for-analysis`

Use for investigations, decision memos, trade-off analysis, root-cause analysis, requirements analysis, document or data interpretation, risk assessment, and strategy diagnosis.

## Design principles

- Users control goals, scope, authority, risk, and material trade-offs.
- Agents autonomously resolve ordinary implementation and investigation details.
- Every important completion claim maps to evidence.
- Unrun checks, manual validation, and evidence limits remain explicit.
- Persistence is optional and reserved for long or resumable work.

## Install

In Claude Code, add the repository as a marketplace and install the plugin:

```text
/plugin marketplace add xiatiandeairen/sprint-for-agent
/plugin install sprint@sprint
```

For local development, add this repository directory as the marketplace source instead.

Codex can load either skill directory directly or through a symlink in `~/.codex/skills/`.

## Repository

```text
skills/
├── sprint-for-code/
│   ├── SKILL.md
│   └── agents/openai.yaml
└── sprint-for-analysis/
    ├── SKILL.md
    ├── agents/openai.yaml
    ├── stages/
    └── templates/
tests/
└── test_repository.py
```

Run validation with:

```bash
python3 -m unittest discover -s tests -v
```

## License

[MIT](LICENSE)
