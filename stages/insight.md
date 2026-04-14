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

- Do not force lessons when nothing notable happened.

## Input

- metrics.log
- All handoffs from completed stages
- plan handoff (expected vs actual)
- execute handoff (task completion details)

---

## Step 1: End Sprint

Model: sonnet

```bash
# [RUN]
bash "$SPRINT_CTL" end "{id}"
```

Prints: per-stage duration, anchor results, scope creep count.

## Step 2: Deviation Analysis

Model: opus

Compare plan vs actual. Classify each deviation:
- `improvement` — found better approach
- `issue` — missed requirement, rework, scope creep
- `change-request` — user changed requirements (neutral)

```
### Plan vs Actual
- **Tasks**: {planned} → {completed} completed, {skipped} skipped
- **Files**: {expected} → {actual} changed
- **Rework**: {count} tasks needed fix

**Deviations**
| Description | Classification |
|-------------|---------------|

**Skipped**: {task, reason}
```

Significant deviation (>30% rework or unexpected files > planned):
- Mostly `issue` → suggest finer task splitting
- `issue` with design gaps → suggest including design stage
- Mostly `change-request` → suggest locking requirements earlier
- Mostly `improvement` → no structural change needed

## Step 3: Process Evaluation

Model: sonnet

Per-stage duration from metrics.log. Calculate time share.

**Time flags**: >40% → `too heavy`. <5% → `too light`.

**Output-value questions** (for unflagged stages):
- Output changed downstream decision? → `essential`
- Confirmed assumption without change? → `helpful`
- Output ignored or redundant? → `could skip`

```
### Process Evaluation
| Stage | Duration | Share | Verdict | Reason |

**Recommendation**: {1 sentence — pipeline for next time}
```

Then run historical comparison:

```bash
# [RUN]
bash "{project_root}/scripts/sprint-insight-stats.sh" "{sprint_id}"
```

If output contains a comparison table, present it to user. If insufficient data, skip silently.

## Step 4: Lessons (optional)

Model: opus

Answer each. "No" → skip. "Yes" → record as lesson.

1. Task needed >1 attempt? → What went wrong first?
2. Execution discovered constraint not in design/plan?
3. Tool/command failed unexpectedly? Workaround?
4. Should a skipped stage have been included?
5. Task took significantly longer than estimate?

No findings = no lessons. Do not force output.

Universal/reusable lesson found → prompt: "This lesson may be valuable for future sprints. Want to persist it with `/know learn`?"

## Step 5: Uncommitted Changes

Model: sonnet

```bash
# [RUN]
git status --short
git diff --stat
```

Uncommitted changes exist → "There are uncommitted changes. Would you like to commit them?"

If yes: generate conventional commit message `{type}({scope}): {description}` (imperative, lowercase, no period, max 72 chars). Present and commit on confirmation.

No changes → skip.

---

## Completion

- Sprint ended, metrics printed
- Deviation analysis with classification
- Process evaluation with time ratios
- Lessons noted; `/know learn` prompted if applicable
- Uncommitted changes checked
- No handoff (insight is terminal output only)

## Recovery

- metrics.log missing → skip deviation/process evaluation
- sprint-ctl end fails → proceed with available handoff data
- git status fails → skip uncommitted changes check
