# insight

Metrics summary + deviation analysis + process evaluation. Last stage, always runs.

## Input

- metrics.log
- All handoffs from completed stages
- plan handoff (for expected vs actual comparison)
- execute handoff (for task completion details)

---

## Step 1: End Sprint

```bash
# [RUN]
bash "$SPRINT_CTL" end "{id}"
```

This prints the metrics summary: per-stage duration, anchor results, scope creep count.

## Step 2: Deviation Analysis

Compare plan expectations vs actual execution. Read plan handoff and execute handoff.

```
═══════════════════════════════════════
  📊 Plan vs Actual
═══════════════════════════════════════

  Tasks:    {planned} planned → {completed} completed, {skipped} skipped
  Files:    {expected} expected → {actual} changed
  Rework:   {count} tasks needed fix after first attempt

  Unexpected:
  - {file or task not in plan but changed/added}

  Skipped:
  - {planned task that was skipped, with reason}

═══════════════════════════════════════
```

If deviation is significant (>30% tasks reworked, or unexpected files > planned files), note the root cause:
- Plan granularity too coarse → suggest finer task splitting next time
- Design gap → suggest including design stage next time
- Scope creep → note which additions were unplanned

## Step 3: Process Evaluation

For each stage that ran, give a 1-line verdict: was it necessary, what would you change next time.

```
═══════════════════════════════════════
  💡 Process Evaluation
═══════════════════════════════════════

  brainstorm  {verdict} — {reason}
  design      {verdict} — {reason}
  plan        {verdict} — {reason}
  execute     {verdict} — {reason}
  quality     {verdict} — {reason}
  review      {verdict} — {reason}

  Recommendation for similar tasks:
  {1 sentence — what pipeline to use next time}

═══════════════════════════════════════
```

Verdicts: `essential` / `helpful` / `could skip` / `too heavy` / `too light`

## Step 4: Lessons (optional)

If any of these occurred during the sprint, note them:
- Approach that failed before finding the right one
- Unexpected constraint discovered during execution
- Tool or command that didn't work as expected
- Stage that should have been included but was skipped

Only output if genuinely useful. Do not force lessons.

---

## Completion

- sprint-ctl end executed
- Metrics summary printed
- Deviation analysis printed (plan vs actual)
- Process evaluation printed
- No handoff file (insight is terminal output only)
