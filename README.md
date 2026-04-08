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
  <a href="https://github.com/xiatiandeairen/sprint-for-agent/actions/workflows/ci.yml"><img src="https://github.com/xiatiandeairen/sprint-for-agent/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/xiatiandeairen/sprint-for-agent/releases"><img src="https://img.shields.io/github/v/release/xiatiandeairen/sprint-for-agent?include_prereleases" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
</p>

---

## What is this?

**sprint-for-agent** is a [Claude Code plugin](https://docs.anthropic.com/en/docs/claude-code) that gives AI agents a structured task execution workflow. Instead of letting the agent freestyle through complex tasks, Sprint enforces a stage pipeline with quality gates and anchor verification.

**The problem:** AI agents often rush through complex tasks, skip validation, forget constraints mid-execution, and produce inconsistent quality.

**The solution:** Sprint evaluates task complexity upfront, trims unnecessary stages, routes each stage to the right model tier (opus/sonnet/haiku), and verifies invariants (anchors) at every checkpoint.

### Key Features

- **Complexity-aware pipeline** — Evaluates 4 dimensions (goal clarity, scope, risk, validation difficulty) to decide which stages to run
- **7-stage architecture** — brainstorm → design → plan → execute → quality → review → insight
- **Anchor verification** — Compile-time-like assertions (`MUST_EXIST`, `MUST_NOT_IMPORT`, `MUST_BUILD`, etc.) checked throughout execution
- **Model routing** — Automatically selects opus/sonnet/haiku per stage and per chunk based on complexity
- **3 skill modes** — `/sprint` (standard), `/long-sprint` (multi-sprint orchestration), `/todo` (lightweight quick tasks)
- **Lifecycle tracking** — SQLite-backed state machine with metrics logging

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
#   goal_clarity: 0 (actionable)
#   scope_size: 1 (module)
#   risk_level: 0 (low)
#   validation_difficulty: 1 (medium)
#
# Pipeline: plan → execute → quality → insight
# (brainstorm, design, review skipped — low complexity)
```

The evaluate step produces a trimmed pipeline. You confirm, and Sprint runs each stage sequentially with handoff documents flowing downstream.

## Skills

### `/sprint` — Standard Execution

The core workflow. Evaluates task complexity across 4 dimensions, trims the stage pipeline, and executes with anchor verification at each gate.

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
│   ├── plugin.json        #   Name, version, description
│   └── marketplace.json   #   Registry metadata
├── hooks/
│   └── hooks.json         # Pre/PostToolUse hooks for anchor compliance
├── scripts/
│   ├── sprint-ctl.sh      # Lifecycle CLI (create, activate, stage, end, list)
│   └── anchor-check.sh    # Anchor assertion runner
├── skills/
│   ├── sprint/SKILL.md    # Standard sprint skill definition
│   ├── long-sprint/SKILL.md  # Multi-sprint orchestrator
│   └── todo/SKILL.md      # Quick task executor
└── stages/
    ├── brainstorm.md      # Clarify requirements (clarity ≥ 1)
    ├── design.md          # Technical design (design ≥ 1)
    ├── plan.md            # Task breakdown + anchors (always)
    ├── execute.md         # Implementation (always)
    ├── quality.md         # Verification (guardrail ≥ 1)
    ├── review.md          # Code review (guardrail ≥ 2)
    ├── insight.md         # Retrospective (always)
    └── long.md            # Long-sprint sub-sprint stage
```

### Data Flow

```
User description
    │
    ▼
┌─────────┐    evaluate    ┌──────────────┐
│ Evaluate │──────────────▶│ Stage Config  │
│ 4 dims   │               │ (trimmed)     │
└─────────┘               └──────┬───────┘
                                  │
    ┌─────────────────────────────┼─────────────────────────┐
    ▼              ▼              ▼              ▼           ▼
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

### Evaluate Dimensions

| Dimension | 0 | 1 | 2 |
|-----------|---|---|---|
| goal_clarity | Actionable | Directional | Vague |
| scope_size | Point | Module | System |
| risk_level | Low (local) | Medium (module) | High (data/auth/prod) |
| validation_difficulty | Easy (automated) | Medium (partial) | Hard (subjective) |

### Model Routing

| Stage | Level 0 | Level 1 | Level 2 |
|-------|---------|---------|---------|
| brainstorm | — | sonnet | opus |
| design | — | sonnet | opus |
| plan | sonnet | sonnet | sonnet |
| execute | sonnet | sonnet | per-chunk |
| quality | sonnet | sonnet | sonnet |
| review | — | sonnet | opus |
| insight | sonnet | sonnet | sonnet |

Execute chunks at level 2 use: **opus** (cross-module/API changes), **sonnet** (clear spec), **haiku** (mechanical only).

### Anchor Types

Anchors are compile-time-like assertions verified throughout execution:

| Anchor | Checks |
|--------|--------|
| `MUST_EXIST <path>` | File/directory must exist |
| `MUST_NOT_EXIST <path>` | File/directory must not exist |
| `MUST_IMPORT <module> <file>` | File must import module |
| `MUST_NOT_IMPORT <module> <file>` | File must not import module |
| `MUST_BUILD` | Project must compile |
| `MUST_TEST` | Tests must pass |
| `FILE_NOT_MODIFIED <path>` | File must not be changed |

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Make your changes
4. Run the CI checks locally: `bash scripts/ci-lint.sh` (once available)
5. Submit a pull request

### Development

```bash
# Test sprint-ctl.sh
bash scripts/sprint-ctl.sh evaluate 0 1 0 1

# Test anchor checking
echo "MUST_EXIST README.md" > /tmp/test-anchors.txt
bash scripts/anchor-check.sh /tmp/test-anchors.txt
```

## License

[MIT](LICENSE)
