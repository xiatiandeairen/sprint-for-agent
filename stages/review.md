# review

## Progress

- total: 5
- steps:
  1. Analyze the changes
  2. Does it match the design?
  3. Here's what I found
  4. Record review results
  5. Your call on the findings

Explain what changed, why, and what to watch out for. Only runs when risk = yes.

## Hard Rules

- Do not flag style issues outside changed files.

## Input

- execute handoff: tasks completed, files changed
- `git diff {base_commit}`

---

## Step 1: Generate Review

Model: opus

Gate (auto): execute handoff 中 completed tasks >0 → 执行。否则跳过整个 review。

Read execute handoff + git diff. Write unified review:

- **Summary**: 1-2 sentences
- **Key decisions**: each with "why A not B"
- **Change table**: every changed file with action + 1-line description
- **Walkthrough**: follow data flow / call chain (entry → processing → output), not alphabetical or diff order. Focus on "why this approach".
- **Watch out**: gotchas for future developers

## Step 2: Design Alignment + Code Quality

Model: opus

**Design alignment**: does implementation follow chosen approach? Deviations justified?

**Code quality checklist** — report only failures within changed files:
- [ ] New public function/type missing docs?
- [ ] Function >50 lines or >3 nesting levels?
- [ ] Duplicated block >5 lines?
- [ ] Inconsistent naming within changed files?
- [ ] TODO/FIXME/HACK without tracking issue?

"All checks pass" if none fail.

## Step 3: Present

Model: sonnet

```
### Review

**Summary**: {1-2 sentences}
**Key Decisions**: {decision}: {why A not B}
**Changes**: | File | Action | What |
**Walkthrough**: {data flow order}
**Watch Out**: {gotchas}
**Design Alignment**: {deviations or "follows design"}
**Code Quality**: {concerns or "no issues"}
```

## Step 4: Write Handoff

Model: sonnet

Write `.sprint/{id}/handoffs/review.md`:
```markdown
## Summary
## Key Decisions
## Change Table
## Walkthrough
## Watch Out
## Design Alignment
## Code Quality
```

## Step 5: User Feedback

Model: sonnet

"有需要调整的地方吗？"

- No issues → complete
- Code issue → update handoff, return to execute to fix
- Handoff-only change → update directly

---

## Completion

- Review covers all tasks, key decisions documented, change table complete
- Design alignment and code quality checked
- User feedback collected, handoff written

## Recovery

- Design deviation → return to execute to fix or document as intentional
- Code quality issue (>50-line function, >3 nesting) → return to execute to refactor
- User requests changes → return to execute, fix, re-run from Step 1
