<p align="center">
  <h1 align="center">sprint-for-agent</h1>
  <p align="center">
    Structured task execution engine for AI coding agents.<br>
    Stage pipeline · Anchor verification · Model routing
  </p>
</p>

<p align="center">
  <strong>English</strong> | <a href="README_zh.md">中文</a>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
</p>

---

## What is this?

AI coding agents rush through complex tasks — they skip validation, forget constraints mid-execution, and produce inconsistent results.

**sprint-for-agent** is a [Claude Code plugin](https://docs.anthropic.com/en/docs/claude-code) that enforces a structured execution pipeline. It evaluates task complexity upfront, runs only the stages that matter, verifies structural invariants (anchors) at every checkpoint, and routes each step to the right model tier.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/xiatiandeairen/sprint-for-agent/main/install.sh | bash
```

This clones the plugin to `~/.claude/plugins/sprint-for-agent` and registers it in your Claude Code settings. Requires `git`.

<details>
<summary>Manual installation</summary>

```bash
git clone https://github.com/xiatiandeairen/sprint-for-agent.git ~/.claude/plugins/sprint-for-agent
```

Add to `~/.claude/settings.json`:

```json
{
  "plugins": ["~/.claude/plugins/sprint-for-agent"]
}
```

</details>

<details>
<summary>Uninstall</summary>

```bash
bash ~/.claude/plugins/sprint-for-agent/uninstall.sh
```

Removes the plugin directory and cleans up `settings.json`.

</details>

## Quick Start

```
> /sprint Add dark mode support to the settings panel

# Sprint evaluates complexity:
#   Clarify requirements? No — goal is clear
#   Need technical design? Yes — cross-module changes
#   High risk? No — local, reversible
#
# Pipeline: design → plan → execute → insight
# (brainstorm and review skipped)
```

Sprint evaluates 3 yes/no questions, trims unnecessary stages, and executes with handoff documents flowing between stages.

## Features

- **Complexity-aware pipeline** — 3 questions (clarify / design / risk) determine which of 7 stages to run
- **Anchor verification** — 9 structural assertions (`MUST_EXIST`, `MUST_BUILD`, `MUST_CONTAIN`, etc.) checked throughout execution
- **Model routing** — Selects opus / sonnet / haiku per step based on reasoning complexity
- **Doc-type trimming** — Document tasks auto-skip plan and quality stages
- **Dynamic project detection** — Auto-detects build/test commands for 7 language ecosystems, with `.sprint.json` override
- **Data-driven feedback** — `sprint-ctl report` for trends and anomaly detection, evaluate shows historical hints
- **Adversarial review** — User-triggered first-principles challenge at key decision points

## Skills

### `/sprint` — Standard Execution

Evaluates task complexity, trims the pipeline, executes with anchor verification at each gate.

Best for: single features, bug fixes, refactors, module-scoped changes.

### `/long-sprint` — Multi-Sprint Orchestration

One preparation round with human-in-the-loop, then auto-executes multiple ordered sub-sprints with direction verification between each.

Best for: large features, architecture changes, multi-module rewrites.

### `/todo` — Quick Executor

Lightweight routing: run a task immediately, resume a deferred sprint, or trigger a saved plan.

Best for: quick tasks, sprint resume, plan execution.

## Architecture

```
sprint-for-agent/
├── scripts/
│   ├── sprint-ctl.sh           # Lifecycle CLI (create, activate, stage, end, report)
│   ├── anchor-check.sh         # Anchor assertion runner (9 types, 7 languages)
│   └── sprint-insight-stats.sh # Historical comparison for insight stage
├── skills/
│   ├── sprint/SKILL.md         # Standard sprint workflow
│   ├── long-sprint/SKILL.md    # Multi-sprint orchestrator
│   └── todo/SKILL.md           # Quick task executor
├── stages/                     # 6 stage definitions (brainstorm → insight)
├── tests/                      # 53 automated test cases
├── install.sh                  # One-line installer
└── uninstall.sh                # Clean uninstaller
```

### Pipeline Flow

```
User description
    │
    ▼
┌──────────────┐   3 yes/no   ┌──────────┐
│ Input        │──────────────▶│ Evaluate │
│ Normalize    │               │ (trim)   │
└──────────────┘               └────┬─────┘
                                    │
  ┌─────────┬─────────┬─────────┬───┴────┬─────────┬─────────┐
  ▼         ▼         ▼         ▼        ▼         ▼
brain-   design     plan    execute   review   insight
storm
```

Each stage reads the upstream handoff and writes its own. Skipped stages pass through.

### Evaluate Questions

| Question | yes | no |
|----------|-----|-----|
| Clarify requirements? | brainstorm | skip |
| Need technical design? | design | skip |
| High risk? | review | skip |

Always-on: plan, execute, insight. Review also triggers when tasks >1 AND cross-module. Override keywords (`delete`, `migrate`, `payment`, `production`, `permission`) force risk=yes.

### Anchor Types

| Anchor | Checks |
|--------|--------|
| `MUST_EXIST <path>` | File or directory must exist |
| `MUST_NOT_EXIST <path>` | File or directory must not exist |
| `MUST_IMPORT <target> <module>` | Target must import module (language-aware) |
| `MUST_NOT_IMPORT <target> <module>` | Target must not import module |
| `MUST_BUILD` | Project must compile |
| `MUST_TEST` | Tests must pass |
| `MUST_CONTAIN <file> <pattern>` | File must contain pattern (line-level grep) |
| `MUST_NOT_CONTAIN <file> <pattern>` | File must not contain pattern |
| `FILE_NOT_MODIFIED <path>` | File must not be changed from base commit |

## Configuration

Create `.sprint.json` in your project root to specify build/test/lint commands:

```json
{
  "build": "npm run build",
  "test": "npm test",
  "lint": "eslint ."
}
```

All fields are optional. Without this file, Sprint auto-detects from `Package.swift`, `package.json`, `Cargo.toml`, `Makefile`, `pyproject.toml`, `go.mod`, or `Gemfile`.

Command priority: `.sprint.json` → `CLAUDE.md` → auto-detect.

## Observability

```bash
# Aggregate trends and summary
sprint-ctl.sh report [--last N] [--status completed]

# Single sprint detail
sprint-ctl.sh report <sprint-id>

# Output: trends (duration, anchor rate, scope creep),
#         summary (completion rate, avg duration, anchors)
```

The evaluate stage shows data-driven hints (trends and anomalies) from historical sprints. The insight stage persists pattern-level lessons to auto memory.

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Run the tests: `bash tests/test-anchor-check.sh && bash tests/test-sprint-ctl.sh`
4. Submit a pull request

## License

[MIT](LICENSE)
