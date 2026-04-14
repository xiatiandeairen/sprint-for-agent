---
name: long-sprint
description: Sprint orchestrator for long-duration tasks. One-round preparation, then auto-executes multiple ordered sub-sprints with Direction Lock verification.
---

# Long Sprint

`/long-sprint {description}` → preparation (human-in-loop) → auto-execute sub-sprints → wrap-up.

## Core Principles

1. **Direction Lock is immutable** — once user confirms, do not re-open scope decisions.
2. **Auto-pilot with journaling** — Phase B runs without human input; every auto-decision logged with basis and result.
3. **Value-target verification** — each sub-sprint delivers one verifiable value point.

## Rules

- All Rules and Hard Rules from sprint SKILL.md apply.
- Do not pause for human input during Phase B unless a blocking failure or direction check failure occurs.
- Script paths: From "Base directory for this skill: {path}", strip `skills/long-sprint/` to get project root. `SPRINT_CTL="{project_root}/scripts/sprint-ctl.sh"`, stage file at `{project_root}/stages/long.md`.

## Default Behaviors

| Situation | Default |
|-----------|---------|
| Description empty | Ask user for description. Do not proceed. |
| Description <10 words | Ask for more context — long-sprint needs enough detail for value discovery. |
| Single value point identified | Suggest regular `/sprint` instead. Proceed only if user insists. |
| Sub-sprint fails direction check | Stop and present failure. Do not auto-recover. |
| Journal write fails | Continue execution, log warning in next journal entry. |
| All sub-sprints complete with no failures | Skip failure sections in report (write "无"). |

## Input Normalization

- Description must be in natural language (not a file path or sprint ID — those route to `/todo`).
- If description is a bullet list, treat each bullet as a candidate value proposition for Step 1.
- If description references an existing sprint, load its handoff as context for preparation.

## Workflow

### Phase A: Preparation (human-in-loop)

`[TASK] preparation`

```bash
# [RUN]
bash "$SPRINT_CTL" create "long" "{english_desc}" "long"
bash "$SPRINT_CTL" activate "{id}"
bash "$SPRINT_CTL" stage "{id}" "long" running
```

Read `$SPRINT_BASE/stages/long.md` and execute Steps 1–5. Produces: value target, difficulty + blind spots, sub-sprint split plan, Direction Lock.

Show split plan to user. [STOP:confirm] before writing artifacts.

After confirm, write `preparation.md`, `direction.md`, and initialize `journal.md` per templates in `stages/long.md` Step 6.

```bash
# [RUN]
bash "$SPRINT_CTL" stage "{id}" "long" completed
```

### Phase B: Auto Execution

**Auto-pilot:** When encountering points that would normally require user input:
- Auto-decide using preparation context (value target, blind spots) + prior sub-sprint handoffs
- Log every decision to `journal.md`: what was decided, basis, result
- Never pause unless blocking failure occurs

#### Sub-sprint Loop

For each sub-sprint N in split plan, in order:

**1. Create + link**

`[TASK] sub-sprint {N}: {desc}`

```bash
# [RUN]
bash "$SPRINT_CTL" create "{type}" "{sub_sprint_desc}" "plan,execute,quality"
bash "$SPRINT_CTL" activate "{sub_id}"
```

Write `{sub_id}` to `.sprint/{long-id}/sub-sprints/sprint-{N}.id`.

**2. Execute pipeline** (plan → execute → quality)

For each stage:
1. `bash "$SPRINT_CTL" stage "{sub_id}" "{stage}" running`
2. Read stage file and execute. Plan reads preparation handoff + prior handoffs. Execute auto-decides ambiguities. Quality checks against Direction Lock.
3. Write handoff.
4. `bash "$SPRINT_CTL" stage "{sub_id}" "{stage}" completed`
5. Append to journal: decision, basis, result, drift status.

**3. Complete**

```bash
# [RUN]
bash "$SPRINT_CTL" end "{sub_id}"
```

Journal entry: value target vs actual output, direction check, next sprint preconditions.

**4. Direction check**

Read `anchors/direction.md`, verify:
1. Actual output matches declared value target? → must be yes
2. Next sub-sprint's dependencies satisfied? → must be yes
3. Work contradicts "Must Not" list? → must be no

All pass → continue. Any fail → stop, report which check failed. [STOP:choose]: A) Adjust B) Skip C) Abort → Phase C.

**5. Cumulative drift check** (after ≥3 sub-sprints)

- Value targets delivered vs pending
- Files changed not mapping to any value target → scope creep flag
- Remaining work achievable in remaining sub-sprints → trajectory check
- Scope creep or at-risk trajectory → journal warning

#### Failure Handling

| Type | Action |
|------|--------|
| Non-blocking (no downstream dependency) | Log, skip, continue |
| Blocking (dependents exist) | [STOP:choose]: A) Retry B) Skip + skip dependents C) Abort → Phase C |

### Phase C: Wrap-up

`[TASK] wrap-up`

1. **Unified review**: files changed per sub-sprint, key decisions, successes/failures/skips
2. **Global stats**: `bash "$SPRINT_CTL" end "{long_sprint_id}"` → N completed / M failed / K skipped, direction alignment, diff stats
3. **Write report** to `.sprint/{id}/reports/long-sprint.md`:

```markdown
# Long Sprint Report
## Summary
{1-3 sentences}
## Sub-sprint Results
| # | Description | Status | Key Output |
## Direction Lock Alignment
{aligned / drifted — explanation}
## Key Decisions
{from journal}
## Skipped / Failed
{if any, with reason}
## Diff Stats
{files changed, lines added/removed}
```

## Directory

```
.sprint/{long-sprint-id}/
├── state.json
├── anchors/direction.md      # immutable after Phase A
├── handoffs/preparation.md
├── journal.md                # append-only decision log
├── sub-sprints/sprint-{N}.id # sub-sprint ID references
└── reports/long-sprint.md    # Phase C report
```

Each sub-sprint has its own `.sprint/{sub-id}/` directory.

## Journal Entry Types

```
## Preparation — {timestamp}
## [Sprint {N}] {stage} — {timestamp}
## [Sprint {N}] completed — {timestamp}
## [Direction Check] sprint-{N} failed — {timestamp}
## [Cumulative Drift] after sprint-{N} — {timestamp}
## [Failure] sprint-{N} blocked — {timestamp}
```
