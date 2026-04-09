# review

Write a human-readable explanation of what changed, why, and what to watch out for. Only runs when guardrail=2.

## Input

- execute handoff: tasks completed, files changed
- `git diff {base_commit}` for actual diff

---

## Step 1: Generate Review

Read execute handoff and git diff. Write a single unified review:

- **Summary:** 1-2 sentences, what was done
- **Key decisions:** Each decision with "why A not B" rationale
- **Change table:** Every changed file with action type and 1-line description

```
| File | Action | What changed |
|------|--------|-------------|
| path | create | ... |
| path | modify | ... |
```

- **Walkthrough:** Explain changes following data flow / call chain order — entry point → intermediate processing → final output. NOT alphabetical file order, NOT git diff order. Focus on "why this approach" not "what the code does".
- **Watch out:** Gotchas for future developers touching this code

---

## Step 2: Design Alignment + Code Quality Scan

**Design Alignment** — compare final implementation against design handoff:
- Does implementation follow the chosen approach?
- Any deviations from design? If yes, are they justified?

**Code Quality Scan** — quick check within changed files:
- Naming consistency within changed files
- Obvious duplication in changed code
- Complexity concerns (deeply nested logic, overly long functions)

Output any deviations or concerns found. User decides if they need fixing.

---

## Step 3: Present

```
═══════════════════════════════════════
  📝 Review
═══════════════════════════════════════

  Summary: {1-2 sentences}

  Key Decisions:
  - {decision}: {why A not B}

  Changes:
  | File | Action | What |
  |------|--------|------|
  | ...  | ...    | ...  |

  Walkthrough:
  {data flow / call chain order: entry → processing → output}

  Watch Out:
  - {gotcha}

  Design Alignment:
  {deviations or "follows design"}

  Code Quality:
  {concerns or "no issues"}

═══════════════════════════════════════
```

---

## Step 4: Write Handoff

Write `.sprint/{id}/handoffs/review.md`:

```markdown
# review Handoff

## Summary
{1-2 sentences}

## Key Decisions
- {decision}: {why A not B}

## Change Table
| File | Action | What changed |
|------|--------|-------------|

## Walkthrough
{data flow / call chain order explanation}

## Watch Out
- {gotcha for future developers}

## Design Alignment
{deviations or "follows design"}

## Code Quality
{concerns or "no issues"}
```

---

## Step 5: User Feedback

Anything to adjust before closing? If there are issues to fix, I'll go back to execute.

If user has feedback → update handoff with user's notes. If fix needed → return to execute.

---

## Completion

- Review covers all tasks from execute
- Key decisions documented with rationale
- Change table complete
- Design alignment and code quality checked
- User feedback collected
- Handoff written
