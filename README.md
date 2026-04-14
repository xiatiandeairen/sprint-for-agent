<p align="center">
  <h1 align="center">sprint-for-agent</h1>
  <p align="center">
    Task execution engine for AI agents — stage pipeline, anchor verification, model routing.
  </p>
</p>

<p align="center">
  <a href="#installation">Installation</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#skills">Skills</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#stages">Stages</a> •
  <a href="#contributing">Contributing</a>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
</p>

---

## What is this?

**sprint-for-agent** is a [Claude Code plugin](https://docs.anthropic.com/en/docs/claude-code) that gives AI agents a structured task execution workflow. Instead of letting the agent freestyle through complex tasks, Sprint enforces a stage pipeline with quality gates and anchor verification.

**The problem:** AI agents often rush through complex tasks, skip validation, forget constraints mid-execution, and produce inconsistent quality.

**The solution:** Sprint evaluates task complexity upfront (3 yes/no questions), trims unnecessary stages, routes each step to the right model tier (opus/sonnet/haiku), and verifies structural invariants (anchors) at every checkpoint.

### Key Features

- **Complexity-aware pipeline** — 3 yes/no questions (clarify/design/risk) determine which stages to run
- **7-stage architecture** — brainstorm → design → plan → execute → quality → review → insight
- **Doc-type trimming** — Document tasks auto-skip plan and quality stages
- **Anchor verification** — Structural assertions (`MUST_EXIST`, `MUST_BUILD`, `MUST_IMPORT`, etc.) checked throughout execution
- **Dynamic project detection** — Auto-detects 7 language types for build/test commands, with `.sprint.json` config override
- **Model routing** — Selects opus/sonnet/haiku per step based on complexity
- **3 skill modes** — `/sprint` (standard), `/long-sprint` (multi-sprint orchestration), `/todo` (lightweight quick tasks)
- **Observability** — `sprint-ctl stats` for cross-sprint metrics, insight stage shows historical comparison
- **Regression tests** — 46 automated test cases covering all anchor types and CLI commands

## Installation

### As a Claude Code plugin (recommended)

Clone into your Claude Code plugins directory:

```bash
# Navigate to your project
cd your-project

# Add as a git submodule (recommended)
git submodule add https://github.com/xiatiandeairen/sprint-for-agent.git src/plugins/sprint

# Or clone directly
git clone https://github.com/xiatiandeairen/sprint-for-agent.git src/plugins/sprint
```

Register in your `.claude/settings.json`:

```json
{
  "plugins": ["src/plugins/sprint"]
}
```

### Project Configuration (optional)

Create `.sprint.json` in your project root to specify build/test/lint commands:

```json
{
  "build": "npm run build",
  "test": "npm test",
  "lint": "eslint ."
}
```

All fields are optional. Without this file, Sprint auto-detects project type from Package.swift, package.json, Cargo.toml, Makefile, pyproject.toml, go.mod, or Gemfile.

### Verify installation

Once installed, the following slash commands become available in Claude Code:

```
/sprint    — Standard task execution
/long-sprint — Multi-sprint orchestration for large tasks
/todo      — Quick task execution or sprint resume
```

## Quick Start

```
> /sprint Add dark mode support to the settings panel

# Sprint evaluates complexity:
#   Clarify requirements? No (goal is clear)
#   Need technical design? Yes (cross-module)
#   High risk? No (local, reversible)
#
# Pipeline: design → plan → execute → quality → insight
# (brainstorm, review skipped)
```

The evaluate step produces a trimmed pipeline. You confirm, and Sprint runs each stage sequentially with handoff documents flowing downstream.

## Skills

### `/sprint` — Standard Execution

The core workflow. Evaluates task complexity with 3 yes/no questions, trims the stage pipeline, and executes with anchor verification at each gate.

Best for: single-feature tasks, bug fixes, refactors, module-scoped changes.

### `/long-sprint` — Multi-Sprint Orchestration

Wraps multiple ordered sub-sprints under a single goal. One preparation round with human-in-the-loop, then auto-executes sub-sprints with direction anchor verification between each.

Best for: large features, architecture changes, multi-module rewrites.

### `/todo` — Quick Executor

Lightweight routing: run a task immediately, resume a deferred sprint, or trigger a saved plan. Skips the full evaluate ceremony for simple actions.

Best for: quick tasks, sprint resume, plan execution.

## Architecture

```
sprint-for-agent/
├── .claude-plugin/        # Plugin metadata
├── scripts/
│   ├── sprint-ctl.sh      # Lifecycle CLI (create, activate, stage, end, evaluate, list, stats)
│   ├── anchor-check.sh    # Anchor assertion runner (7 types, 7 languages)
│   └── sprint-insight-stats.sh  # Historical comparison for insight stage
├── skills/
│   ├── sprint/SKILL.md    # Standard sprint skill definition
│   ├── long-sprint/SKILL.md  # Multi-sprint orchestrator
│   └── todo/SKILL.md      # Quick task executor
├── stages/
│   ├── brainstorm.md      # Clarify requirements (clarify=yes)
│   ├── design.md          # Technical design (design=yes)
│   ├── plan.md            # Task breakdown + anchors (always)
│   ├── execute.md         # Implementation (always)
│   ├── quality.md         # Verification (always)
│   ├── review.md          # Code review (risk=yes)
│   ├── insight.md         # Retrospective + historical comparison (always)
│   └── long.md            # Long-sprint sub-sprint stage
└── tests/
    ├── test-helpers.sh    # Shared assert functions + fixture management
    ├── test-anchor-check.sh  # 28 test cases for anchor verification
    └── test-sprint-ctl.sh    # 18 test cases for lifecycle CLI
```

### Data Flow

```
User description
    │
    ▼
┌──────────────────┐    3 yes/no     ┌──────────────┐
│ Input Normalize   │───────────────▶│ Evaluate      │
│ (detect patterns) │                │ (trim stages) │
└──────────────────┘                └──────┬───────┘
                                           │
    ┌──────────────────────────────────────┼──────────────────┐
    ▼              ▼              ▼              ▼              ▼
┌────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐  ┌─────────┐
│ brain- │  │  design   │  │   plan   │  │ execute │  │ quality │ ...
│ storm  │─▶│          │─▶│          │─▶│         │─▶│         │
└────────┘  └──────────┘  └──────────┘  └─────────┘  └─────────┘
                                │              │
                                ▼              ▼
                          anchors.txt    anchor-check
```

### Sprint Directory (runtime)

Each sprint creates a working directory:

```
.sprint/{id}/
├── state.json      # created → running → completed
├── handoffs/       # Stage handoff documents
├── anchors.txt     # Assertions from plan stage
└── metrics.log     # Append-only event log
```

### Evaluate Questions

| Question | yes → enable | no → skip |
|----------|-------------|----------|
| Clarify requirements? | brainstorm | skip |
| Need technical design? | design | skip |
| High risk? | quality + review | quality only |

Always-on: plan, execute, insight. Doc-type tasks auto-skip plan + quality.

Override keywords: `delete`, `migrate`, `payment`, `production`, `permission` → risk=yes.

### Command Priority (build/test)

```
.sprint.json → CLAUDE.md → auto-detect (7 languages)
```

### Anchor Types

| Anchor | Checks |
|--------|--------|
| `MUST_EXIST <path>` | File/directory must exist |
| `MUST_NOT_EXIST <path>` | File/directory must not exist |
| `MUST_IMPORT <target> <module>` | Target path must import module (language-aware) |
| `MUST_NOT_IMPORT <target> <module>` | Target path must not import module |
| `MUST_BUILD` | Project must compile (auto-detect or configured) |
| `MUST_TEST` | Tests must pass (auto-detect or configured) |
| `FILE_NOT_MODIFIED <path>` | File must not be changed from base commit |

### Observability

```bash
# Cross-sprint aggregated metrics
sprint-ctl.sh stats [--last N] [--status completed]

# Output: Efficiency (completion rate, avg duration, stage distribution)
#         Quality (anchor pass rate, scope creep)
#         Value (task completion rate)
```

Insight stage auto-shows historical comparison (this sprint vs average).

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Run the tests: `bash tests/test-anchor-check.sh && bash tests/test-sprint-ctl.sh`
4. Submit a pull request

## License

[MIT](LICENSE)
