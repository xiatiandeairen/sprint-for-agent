# insight

Metrics summary + process evaluation. Last stage, always runs.

## Input

- metrics.log
- All handoffs from completed stages

---

## Step 1: End Sprint

```bash
# [RUN]
bash "$SPRINT_CTL" end "{id}"
```

This prints the metrics summary: per-stage duration, anchor results, scope creep count.

## Step 2: Process Evaluation

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

## Step 3: Lessons (optional)

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
- Process evaluation printed
- No handoff file (insight is terminal output only)
