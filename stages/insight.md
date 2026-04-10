# insight

## Progress

- total: 5
- steps:
  1. Close the sprint
  2. What went differently than planned?
  3. Did the process work well?
  4. What to remember next time?
  5. Any uncommitted work left?

Metrics summary + deviation analysis + process evaluation. Last stage, always runs.

## Hard Rules

- Do not force lessons when nothing notable happened. "No lessons" is valid.
- Do not classify user-requested scope changes as "issues". They are "change-requests" (neutral).

## Input

- metrics.log
- All handoffs from completed stages
- plan handoff (for expected vs actual comparison)
- execute handoff (for task completion details)

---

## Step 1: End Sprint

Model: sonnet

```bash
# [RUN]
bash "$SPRINT_CTL" end "{id}"
```

This prints the metrics summary: per-stage duration, anchor results, scope creep count.

## Step 2: Deviation Analysis

Model: opus

Compare plan expectations vs actual execution. Read plan handoff and execute handoff.

Classify each deviation as one of:
- `improvement` — positive: found better approach, proactively adjusted
- `issue` — negative: missed requirement, rework, scope creep
- `change-request` — neutral: user added or changed requirements during sprint

```
### 📊 Plan vs Actual

- **Tasks**: {planned} planned → {completed} completed, {skipped} skipped
- **Files**: {expected} expected → {actual} changed
- **Rework**: {count} tasks needed fix after first attempt

**Deviations**

| Description | Classification |
|-------------|---------------|
| {deviation description} | {improvement / issue / change-request} |

**Skipped**
- {planned task that was skipped, with reason}

---
```

If deviation is significant (>30% tasks reworked, or unexpected files > planned files), note the root cause using classification context:
- Mostly `issue` → plan granularity too coarse, suggest finer task splitting next time
- Mostly `issue` with design gaps → suggest including design stage next time
- Mostly `change-request` → scope was fluid, suggest locking requirements earlier
- Mostly `improvement` → execution went well, no structural change needed

## Step 3: Process Evaluation

Model: sonnet

Read per-stage durations from metrics.log. Calculate each stage's share of total sprint time.

For each stage that ran, determine verdict using time ratio thresholds first, then binary output-value questions for stages not flagged by time:

**Time-based flags:**
- Stage took >40% of total time → `too heavy`
- Stage took <5% of total time → `too light`

**Output-value questions (for stages not flagged by time):**
- Did this stage's output change any downstream decision? → `essential`
- Did this stage's output confirm an assumption without changing anything? → `helpful`
- Was this stage's output ignored or redundant with another stage? → `could skip`

```
### 💡 Process Evaluation

| Stage | Duration | Share | Verdict | Reason |
|-------|----------|-------|---------|--------|
| brainstorm | {duration} | {pct}% | {verdict} | {reason} |
| design | {duration} | {pct}% | {verdict} | {reason} |
| plan | {duration} | {pct}% | {verdict} | {reason} |
| execute | {duration} | {pct}% | {verdict} | {reason} |
| quality | {duration} | {pct}% | {verdict} | {reason} |
| review | {duration} | {pct}% | {verdict} | {reason} |

**Recommendation**: {1 sentence — what pipeline to use next time}

---
```

Verdicts: `essential` / `helpful` / `could skip` / `too heavy` / `too light`

## Step 4: Lessons (optional)

Model: opus

Answer each question. If "no", skip it. If "yes", record the finding as a lesson.

1. Was there a task that needed >1 attempt? → What was wrong with the first approach?
2. Did execution discover a constraint not mentioned in design/plan? → What was it?
3. Did any tool/command fail unexpectedly? → What was the workaround?
4. Looking back, should a skipped stage have been included? → Why?
5. Did any task take significantly longer than its size estimate? → Why?

Only output lessons where the answer is "yes". No findings = no lessons — do not force output.

After generating lessons, check if any have universal or reusable value — applicable beyond this sprint or project context. If yes, prompt the user:

This lesson may be valuable for future sprints. Want to persist it with `/know learn`?

If user says yes, suggest the knowledge entry as one of: decision / trap / rule. If no lessons or none worth persisting, skip this prompt entirely.

## Step 5: Uncommitted Changes Check

Model: sonnet

Check for uncommitted changes:

```bash
# [RUN]
git -C "$SPRINT_CTL_DIR" status --short
git -C "$SPRINT_CTL_DIR" diff --stat
```

If there are uncommitted changes, prompt the user:

There are uncommitted changes. Would you like to commit them?

If user says yes:
- Generate a conventional commit message: `{type}({scope}): {description}`
- **type**: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `perf`, `style`, `ci`, `build`
- **scope**: module or area affected (e.g. `scoring`, `bunny`, `sprint`)
- **description**: imperative, lowercase, no period, max 72 chars
- If changes span multiple scopes, pick the most significant one. If breaking changes are included, add `!` after scope.
- Present the proposed message and commit on confirmation.

If no uncommitted changes, skip this step entirely.

Note: The primary commit strategy (per-task or unified) was decided in the plan stage. This step is a safety net only.

---

## Completion

- sprint-ctl end executed
- Metrics summary printed
- Deviation analysis printed with classification column
- Process evaluation printed with time ratios
- Lessons noted; /know learn prompted if applicable
- Uncommitted changes checked; commit proposed if needed
- No handoff file (insight is terminal output only)

## Recovery

- metrics.log missing or empty → skip deviation analysis and process evaluation, report "no metrics available"
- sprint-ctl end fails → report error, proceed with remaining steps using available handoff data
- git status fails → skip uncommitted changes check, report "git not available"
