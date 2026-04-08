---
name: long-sprint
description: Sprint orchestrator for long-duration tasks. One-round preparation, then auto-executes multiple ordered sub-sprints with direction anchor verification.
---

# Long Sprint

`/long-sprint {description}` → preparation (human-in-loop) → auto-execute sub-sprints → wrap-up.

## Rules

- Bash commands marked `# [RUN]` must be executed with Bash tool, not described verbally.
- `[TASK] xxx` triggers TaskCreate. Mark TaskUpdate completed when done.
- Wait for user at `[STOP:confirm]` (only proceed on: ok/yes/continue/确认/好/可以), `[STOP:choose]` (user picks one option), `[STOP:respond]` (user gives substantive reply).
- Match user's language. Chinese input → Chinese response. Internal docs stay in English.
- Script paths: Set `SPRINT_BASE` from "Base directory for this skill: {path}" — navigate up two levels from `skills/long-sprint/` to reach plugin root. `SPRINT_CTL="$SPRINT_BASE/scripts/sprint-ctl.sh"`, stage file at `$SPRINT_BASE/stages/long.md`.

---

## Phase A: Preparation

Human-in-loop. Establish the direction anchor and sub-sprint split plan before any code is written.

### A0 — Create long sprint

`[TASK] preparation`

```bash
# [RUN]
bash "$SPRINT_CTL" create "long" "{english_desc}" "long"
bash "$SPRINT_CTL" activate "{id}"
```

```bash
# [RUN]
bash "$SPRINT_CTL" stage "{id}" "long" running
```

### A1–A4 — Execute preparation stage

Read `$SPRINT_BASE/stages/long.md` and execute it (Steps A1–A4).

The stage produces:
- Value target: what success looks like
- Difficulty + blind spots: risks and unknowns
- Sub-sprint split plan: ordered list with types and descriptions
- Direction anchor: end-state assertions

Show the split plan to the user. [STOP:confirm] before writing anchors.

### A5 — Write artifacts

After user confirms:

Write `.sprint/{id}/handoffs/preparation.md`:
```markdown
## Conclusion
{summary of preparation discussion}

## Value Target
{what success looks like — used by every sub-sprint}

## Difficulty & Blind Spots
{risks and unknowns identified}

## Split Plan
| # | Type | Description | Depends On |
|---|------|-------------|------------|
| 1 | {type} | {desc} | — |
| 2 | {type} | {desc} | sprint-1 |
...

## Downstream
Sub-sprints read this file. Use Value Target + Blind Spots as decision basis for auto-pilot choices.
```

Write `.sprint/{id}/anchors/direction.md` (immutable after this point):
```markdown
# Direction Anchor
## End State
{what the system looks like when long-sprint is done}

## Value Points
{bullet list of must-deliver outcomes}

## Must Not
{explicit non-goals or forbidden side effects}
```

Initialize `.sprint/{id}/journal.md`:
```markdown
# Long Sprint Journal

## Preparation — {timestamp}
Value points confirmed: {list}
Split plan: {N} sub-sprints
Direction anchor written.
```

```bash
# [RUN]
bash "$SPRINT_CTL" stage "{id}" "long" completed
```

TaskUpdate completed for preparation task.

---

## Phase B: Auto Execution

**Auto-pilot mode.** Human does not intervene unless a blocking failure occurs or a direction check fails.

**Auto-pilot instruction**: During sub-sprint execution, read stage files (plan.md, execute.md, quality.md) and execute them normally. When encountering any point that would normally require user input, confirmation, or a choice:
- Auto-decide using preparation context (value target, difficulty, blind spots) + prior sub-sprint handoffs as decision basis
- Log every auto-decision to `journal.md` with: what was decided, what info informed the decision, the result
- Never pause for human input during Phase B unless a blocking failure occurs

### Sub-sprint loop

Repeat for each sub-sprint N in the split plan, in order:

#### Step 1 — Create + activate

`[TASK] sub-sprint {N}: {desc}`

```bash
# [RUN]
bash "$SPRINT_CTL" create "{type}" "{sub_sprint_desc}" "plan,execute,quality"
bash "$SPRINT_CTL" activate "{sub_id}"
```

#### Step 2 — Link sub-sprint

Write `{sub_id}` as the sole content of `.sprint/{long-id}/sub-sprints/sprint-{N}.id`.

#### Step 3 — Execute pipeline

For each stage in `plan → execute → quality`:

1. `[TASK] sprint-{N} {stage}`
2. `bash "$SPRINT_CTL" stage "{sub_id}" "{stage}" running`
3. Read the corresponding stage file and execute:
   - **plan**: reads preparation handoff + prior sub-sprint handoffs (if this sprint has dependencies)
   - **execute**: auto-pilot mode, coding with TDD; auto-decide any ambiguities using preparation context; log all decisions to journal
   - **quality**: build + test + check against direction anchor value points
4. Write stage handoff
5. `bash "$SPRINT_CTL" stage "{sub_id}" "{stage}" completed`
6. Append to `journal.md`:

```markdown
## [Sprint {N}] {stage} — {timestamp}
Decision: {what was chosen or done}
Basis: {preparation context or prior handoff that informed this}
Result: {files changed, tests passed/failed, or stage output summary}
Drift: aligned
```

TaskUpdate completed for stage task.

#### Step 4 — Complete sub-sprint

```bash
# [RUN]
bash "$SPRINT_CTL" end "{sub_id}"
```

Append to `journal.md`:
```markdown
## [Sprint {N}] completed — {timestamp}
Value target: {target from preparation}
Actual output: {what was delivered}
Direction check: pass
Next sprint preconditions: pass
```

TaskUpdate completed for sub-sprint task.

#### Step 5 — Direction check

After each sub-sprint completes, read `anchors/direction.md` and verify:

- Actual output vs value target → match?
- Next sprint preconditions → still hold?
- End-state heading → still on track?

All pass → continue to next sub-sprint.

Any fail → stop, report to user. [STOP:choose]:
- A) Adjust — revise the split plan or direction anchor, then continue
- B) Skip — skip the failed check's sub-sprint and continue
- C) Abort — end the long-sprint now, go to Phase C

#### Step 6 — Cumulative drift check (after 3+ sub-sprints)

After every sub-sprint once 3 or more are completed:

- Compare total outputs so far vs direction anchor end-state
- If end-state still far away → append warning to journal
- If outputs contain work not in anchor → append scope creep flag to journal

### Failure handling

**Non-blocking failure** (sub-sprint failed but no downstream dependency):
- Log failure in journal
- Skip this sub-sprint
- Continue to next

**Blocking failure** (downstream sub-sprints depend on this one):
- Stop execution. [STOP:choose]:
  - A) Retry — re-run the failed sub-sprint
  - B) Skip — skip failed sub-sprint and mark all dependents as skipped too, then continue with remaining
  - C) Abort — end long-sprint now, go to Phase C

---

## Phase C: Wrap-up

After all sub-sprints complete (or execution stopped).

`[TASK] wrap-up`

### C1 — Unified review

Summarize across all sub-sprints:
- Files changed per sub-sprint
- Key decisions made (from journal)
- What succeeded, what failed, what was skipped

### C2 — Global insight

```bash
# [RUN]
bash "$SPRINT_CTL" end "{long_sprint_id}"
```

Report:
- Total sub-sprints: N completed / M failed / K skipped
- Direction anchor alignment: aligned / drifted
- Total diff stats

### C3 — Write report

Write `.sprint/{id}/reports/long-sprint.md`:
```markdown
# Long Sprint Report

## Summary
{1–3 sentence summary of what was accomplished}

## Sub-sprint Results
| # | Description | Status | Key Output |
|---|-------------|--------|------------|
| 1 | {desc} | completed | {output} |
...

## Direction Anchor Alignment
{aligned / drifted — with explanation}

## Key Decisions
{top decisions from journal that shaped the outcome}

## What Was Skipped / Failed
{if any, with reason}

## Diff Stats
{total files changed, lines added/removed}
```

### C4 — Present to user

Show the summary. TaskUpdate completed for wrap-up task.

---

## Data Directory Structure

```
.sprint/{long-sprint-id}/
├── state.json
├── anchors/
│   └── direction.md          # immutable after Phase A
├── handoffs/
│   └── preparation.md        # Phase A output
├── journal.md                # append-only decision log
├── sub-sprints/              # sub-sprint ID references
│   ├── sprint-1.id
│   ├── sprint-2.id
│   └── ...
└── reports/
    └── long-sprint.md        # Phase C global report
```

Each sub-sprint has its own standard `.sprint/{sub-id}/` directory managed by the sprint skill.

---

## Journal Format Reference

The journal is append-only and human-readable. Each entry uses one of these headers:

```markdown
## Preparation — {timestamp}
## [Sprint {N}] {stage} — {timestamp}
## [Sprint {N}] completed — {timestamp}
## [Direction Check] sprint-{N} failed — {timestamp}
## [Cumulative Drift] after sprint-{N} — {timestamp}
## [Failure] sprint-{N} blocked — {timestamp}
```
