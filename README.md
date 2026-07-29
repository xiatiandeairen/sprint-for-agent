# Sprint for Agent

Problem-driven skills for software engineering and decision-grade analysis.

Sprint does not force agents through a stage pipeline. It selects only the questions that can materially affect the result, resolves discoverable questions autonomously, and asks the user only for scope, authority, risk, or value decisions.

[中文](README_zh.md)

## Skills

### `sprint-for-code`

Use only when the primary deliverable is a software repository change, an implementation / PR / diff code-review verdict, or a performance / reliability result backed by repeatable measurement. This includes code, configuration, tests, build files, and repository engineering documentation tied to the implementation.

Use this skill when fixing a software issue; use `sprint-for-analysis` when only investigating its cause. Ordinary code explanations, technical Q&A, summaries, translations, rewrites, brainstorming, and simple commands do not automatically use this skill.

It recognizes three task shapes:

```text
change:   goal → solution → Eval → implement ⇄ Eval → evidence gate
review:   goal → review criteria → inspect ⇄ challenge → evidence gate
optimize: metric → baseline → hypothesis → change ⇄ remeasure → evidence gate
```

Questions come from a small core, task-specific domain checks, and new uncertainties discovered during execution. The skill has no fixed stage DSL, mandatory flow confirmation, or default handoff archive.

### `sprint-for-analysis`

Use only when the primary deliverable is an explanation, comparison, recommendation, or verdict grounded in materials and evidence. This includes investigations, decision memos, trade-off analysis, root-cause analysis, requirements analysis, document / log / data / claim review, risk assessment, and strategy diagnosis.

Use this skill when only investigating a software issue; use `sprint-for-code` when changing the repository or reviewing implementation code. Simple factual Q&A, summaries, translations, rewrites, brainstorming, pure content creation, and direct execution that needs no judgment do not automatically use this skill.

It recognizes three analysis shapes:

```text
investigate: question → evidence → hypotheses ⇄ challenge → explanation
decide:      objective → options → evidence and trade-offs ⇄ challenge → recommendation
review:      claim → criteria → inspect evidence ⇄ challenge → verdict
```

It derives confidence from evidence coverage and limits rather than mandatory self-reported scores.

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
    └── agents/openai.yaml
tests/
└── test_repository.py
```

Run validation with:

```bash
python3 -m unittest discover -s tests -v
```

## License

[MIT](LICENSE)
