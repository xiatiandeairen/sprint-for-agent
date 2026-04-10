# review

## Progress

- total: 5
- steps:
  1. Analyze the changes
  2. Does it match the design?
  3. Here's what I found
  4. Record review results
  5. Your call on the findings

Write a human-readable explanation of what changed, why, and what to watch out for. Only runs when guardrail=2.

## Hard Rules

- Do not flag style issues in files outside the changed file list.
- Do not summarize what each line of code does. Focus on decisions and data flow.

## Input

- execute handoff: tasks completed, files changed
- `git diff {base_commit}` for actual diff

---

## Step 1: Generate Review

Model: opus

Gate: execute handoff 是否包含已完成的任务？

💡 如果 execute 没有完成任何任务，跳过整个 review stage。

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

Model: opus

**Design Alignment** — compare final implementation against design handoff:
- Does implementation follow the chosen approach?
- Any deviations from design? If yes, are they justified?

**Code Quality Checklist** — check each item within changed files, report only failures:
- [ ] Any new public function/type missing documentation?
- [ ] Any function >50 lines or >3 nesting levels?
- [ ] Any duplicated block (>5 lines identical or near-identical)?
- [ ] Any inconsistent naming within the changed files (mixed camelCase/snake_case, abbreviated vs full)?
- [ ] Any TODO/FIXME/HACK comment added without a tracking issue?

Output: list of failed checks with file:line references. "All checks pass" if none fail.

---

## Step 3: Present

Model: sonnet

```
### 📝 Review

**Summary**: {1-2 sentences}

**Key Decisions**
- {decision}: {why A not B}

**Changes**

| File | Action | What |
|------|--------|------|
| ...  | ...    | ...  |

**Walkthrough**
{data flow / call chain order: entry → processing → output}

**Watch Out**
- {gotcha}

**Design Alignment**
{deviations or "follows design"}

**Code Quality**
{concerns or "no issues"}

---
```

---

## Step 4: Write Handoff

Model: sonnet

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

Model: sonnet

Present review to user and ask: "有需要调整的地方吗？"

- User confirms no issues → mark review complete
- User identifies issue → update handoff with user's notes, return to execute to fix
- User requests handoff change only (no code fix) → update handoff directly

---

## Completion

- Review covers all tasks from execute
- Key decisions documented with rationale
- Change table complete (every changed file has an entry)
- Design alignment checked against design handoff
- Code quality checklist run on changed files, failures listed with file:line
- User feedback collected
- Handoff written

## Recovery

- Design alignment finds deviation → return to execute to fix or document as intentional in handoff
- Code quality finds >50-line function or >3 nesting levels → return to execute to refactor
- User requests changes → return to execute, fix, re-run review from Step 1
