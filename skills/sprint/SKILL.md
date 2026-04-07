---
name: sprint
description: Task execution workflow. Evaluates complexity, trims stages, executes step by step with anchor verification.
---

# Sprint

`/sprint {description}` → evaluate → trim stages → execute pipeline.

## Rules

- Bash commands marked `# [RUN]` must be executed with Bash tool, not described verbally.
- `[TASK] xxx` triggers TaskCreate. Mark TaskUpdate completed when done.
- Wait for user at `[STOP:confirm]` (only proceed on: ok/yes/continue/确认/好/可以), `[STOP:choose]` (user picks one option), `[STOP:respond]` (user gives substantive reply).
- Questions that ask user to choose must always list explicit options (A/B/C). Never ask a choice question without options.
- Questions that ask user to confirm must always show the content being confirmed. Never ask "confirm?" without showing what to confirm.
- Never expose internal concepts to user: mark names, layer/step/level numbers, evidence levels, algorithm terms, execution mode names. User sees natural conversation and formatted output blocks only.
- Match user's language. Chinese input → Chinese response. English input → English response. Internal docs (skill files, handoffs) stay in English.
- Script paths are relative to this skill's base directory (provided by Claude Code as "Base directory for this skill: {path}"). Set `SPRINT_BASE` to that path, then: `SPRINT_CTL="$SPRINT_BASE/scripts/sprint-ctl.sh"`, `ANCHOR_CHECK="$SPRINT_BASE/scripts/anchor-check.sh"`, stage files at `$SPRINT_BASE/stages/{stage}.md`.

---

## Evaluate

Extract 4 dimensions from user description, run evaluate command.

| Dimension | 0 | 1 | 2 |
|-----------|---|---|---|
| goal_clarity | Actionable | Directional | Vague |
| scope_size | Point | Module | System |
| risk_level | Low (local, reversible) | Medium (module impact) | High (data/auth/prod/delete/migrate) |
| validation_difficulty | Easy (automated) | Medium (partial manual) | Hard (subjective/complex) |

Override keywords from description: `delete/migrate/payment/production/permission` → risk=2. `optimize/explore` → clarify≥1. `system/architecture` → design≥1, plan≥1.

```bash
# [RUN]
bash "$SPRINT_CTL" evaluate {gc} {ss} {rl} {vd} {keywords...}
```

### Decision → Stage Mapping

| Decision | 0 | 1 | 2 | Stage |
|----------|---|---|---|-------|
| clarify | skip | light | deep | brainstorm |
| design | skip | quick | research+model | design |
| plan | minimal | split tasks | tasks+deps+anchor | plan |
| guardrail | skip | basic verify | full+review | quality, review |

execute and insight: always.

Render evaluate result in formatted block. [STOP:confirm] before creating sprint.

```bash
# [RUN] after confirm
bash "$SPRINT_CTL" create "{desc}" "{stages}"
bash "$SPRINT_CTL" activate "{id}"
```

---

## Directory

```
.sprint/{id}/
├── state.json      # created → running → completed
├── handoffs/       # stage handoff docs
├── anchors.txt     # plan produces, execute verifies
└── metrics.log     # append-only event log
```

Handoff minimum: `## Conclusion` + `## Downstream` + `## Output`. Plan adds `## Expected Files`. Each stage file defines its specific template.

Anchor format: `MUST_NOT_IMPORT`, `MUST_IMPORT`, `MUST_NOT_EXIST`, `MUST_EXIST`, `MUST_BUILD`, `MUST_TEST`, `FILE_NOT_MODIFIED` — one assertion per line.

Metrics: `{timestamp}|{event}|{data...}` — sprint_start, stage_start, stage_end, anchor_check, sprint_end.

---

## Stages

| Stage | File | When |
|-------|------|------|
| brainstorm | `stages/brainstorm.md` | clarify ≥ 1 |
| design | `stages/design.md` | design ≥ 1 |
| plan | `stages/plan.md` | always |
| execute | `stages/execute.md` | always |
| quality | `stages/quality.md` | guardrail ≥ 1 |
| review | `stages/review.md` | guardrail ≥ 2 |
| insight | `stages/insight.md` | always |

---

## Pipeline

For each stage in trimmed pipeline:

1. `[TASK] {stage}`
2. `bash "$SPRINT_CTL" stage "{id}" "{stage}" running`
3. Read `stages/{stage}.md`, execute by level from evaluate output
4. Write handoff if applicable
5. `bash "$SPRINT_CTL" stage "{id}" "{stage}" completed`
6. TaskUpdate completed

Chaining: each stage reads upstream handoff. design skipped → plan uses user description. execute reads plan + anchors.txt. quality reads execute handoff. review reads execute handoff + git diff.

```bash
# [RUN] after all stages
bash "$SPRINT_CTL" end "{id}"
```
