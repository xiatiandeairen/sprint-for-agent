# review

Write a human-readable explanation of what changed, why, and what to watch out for. Only runs when guardrail=2.

## Input

- execute handoff: tasks completed, files changed
- `git diff {base_commit}` for actual diff

---

## Step 1: Generate Review

Read execute handoff and git diff. Write two sections:

### For yourself (quick context recovery)

- **Summary:** 1-2 sentences, what was done
- **Key decisions:** Each decision with "why A not B" rationale
- **Watch out:** Things to be careful about when touching this code later

### For team (code review level)

- **Change table:** Every changed file with action type and 1-line description

```
| File | Action | What changed |
|------|--------|-------------|
| path | create | ... |
| path | modify | ... |
```

- **Code walkthrough:** Explain changes in logical order (not file order). Focus on "why this approach" not "what the code does".

---

## Step 2: Present

```
═══════════════════════════════════════
  📝 Review
═══════════════════════════════════════

  Summary: {1-2 sentences}

  Key Decisions:
  - {decision}: {why}

  Watch Out:
  - {gotcha}

  Changes:
  | File | Action | What |
  |------|--------|------|
  | ...  | ...    | ...  |

  Walkthrough:
  {logical explanation}

═══════════════════════════════════════
```

---

## Step 3: Write Handoff

Write `.sprint/{id}/handoffs/review.md`:

```markdown
# review Handoff

## Summary
{1-2 sentences}

## Key Decisions
- {decision}: {rationale}

## Watch Out
- {gotcha for future developers}

## Change Table
| File | Action | What changed |
|------|--------|-------------|

## Walkthrough
{logical order explanation}
```

---

## Step 4: User Feedback [STOP:respond]

Ask user:

```
Anything to adjust or note before closing?
- Issues to fix → return to execute
- Decisions to reconsider → note in handoff
- All good → proceed to next stage
```

If user has feedback → update handoff with user's notes. If fix needed → return to execute.

---

## Completion

- Review covers all tasks from execute
- Key decisions documented with rationale
- Change table complete
- User feedback collected
- Handoff written
