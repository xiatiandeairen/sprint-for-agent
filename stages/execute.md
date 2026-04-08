# execute

Run tasks from plan handoff. Each unit follows: coding → build verify → anchor → test → review.

Model: sonnet (default for coding; opus for integration/interface changes)

## Default Anchors

Every sprint automatically includes these anchors unless explicitly removed:

- `MUST_BUILD` — full project build must pass after each task

For typed languages (Swift, Kotlin, TypeScript, Rust, Go, Java): build verification is mandatory after each task, not optional.

## Input

- plan handoff: execution mode, task list, verify criteria, expected files
- anchors.txt

## Mode

Determined in plan stage by user choice:
- **step-by-step:** Run tasks serially in current session. Verify each with user before next.
- **subagent-driven:** Dispatch chunks to subagents in parallel. Unified verification after all complete.

---

## Step-by-step Mode

For each task in plan handoff:

### 1. Coding

Execute the task's TDD steps:
- Write test
- Run test → confirm FAIL
- Implement
- Run test → confirm PASS
- Build verify (if typed language: run project build command, must pass before proceeding)
- Commit

Use the model specified in the task (sonnet/opus).

### 2. Anchor Check

```bash
# [RUN]
bash "$ANCHOR_CHECK" "{sprint_id}"
```

If any anchor fails → fix before proceeding. Do not skip.

### 3. AI Test

Run the AI verify commands specified in the task (build, test, lint, etc).

### 4. User Review

Output the task's user verify checklist:

```
═══════════════════════════════════════
  ✅ Task {N} Complete: {title}
═══════════════════════════════════════

  Files changed:
  - {path}: {what changed}

  AI verify: PASS ✓
  Anchor: {N} pass / {N} fail

  User verify:
  - [ ] {concrete check 1}
  - [ ] {concrete check 2}
  - [ ] {concrete check 3}

═══════════════════════════════════════
```

Wait for user to confirm all checks pass. If issues found → fix and re-verify. Confirmed → next task.

### Loop

Repeat 1-4 for each task until all tasks complete.

---

## Subagent-driven Mode

### Worktree Isolation (subagent-driven only)

When subagent-driven mode is selected, execute automatically enters a worktree for isolation:

1. Create worktree via `EnterWorktree`
2. All chunks execute inside the worktree
3. Quality stage also runs inside the worktree
4. On quality pass → rebase worktree onto trunk for linear history
   - Rebase conflict → stop, report to user with conflict details
5. `ExitWorktree` to clean up

This allows the user to start a new `/sprint` in the main trunk while this sprint executes in the background.

Step-by-step mode does NOT use worktree — it runs directly on trunk.

### 1. Dispatch

For each chunk in plan handoff:
- Independent chunks → dispatch in parallel as subagents
- Dependent chunks → dispatch sequentially after dependencies complete
- Each subagent prompt includes: chunk files, steps, code, model specification

Output model selection per chunk at dispatch time:
```
[dispatch] chunk {N.M} — model: {model}
```

If a chunk involves cross-module integration or interface changes, upgrade to opus and note the reason:
```
[dispatch] chunk {N.M} — model: opus (cross-module integration)
```

Subagent execution per chunk: coding → anchor-check → AI test → self-review.

### 2. Collect Results

Wait for all subagents to complete. Collect:
- Changed files per chunk
- Anchor check results
- Test results
- Any errors or concerns raised by subagents

### 3. Unified Review

Output combined verification:

```
═══════════════════════════════════════
  ✅ All Chunks Complete
═══════════════════════════════════════

  Task 1: {title}
  ├─ Chunk 1.1: {status} ✓
  ├─ Chunk 1.2: {status} ✓
  └─ Chunk 1.3: {status} ✓

  Task 2: {title}
  ├─ Chunk 2.1: {status} ✓
  └─ Chunk 2.2: {status} ✓

  Anchor: {N} pass / {N} fail
  Build: PASS ✓
  Tests: {N} pass / {N} fail

  User verify:
  - [ ] {check from task 1}
  - [ ] {check from task 2}
  - [ ] {overall integration check}

═══════════════════════════════════════
```

Wait for user to confirm. Issues → dispatch fix subagent for specific chunk, re-verify.

---

## Write Handoff

After all tasks verified, write `.sprint/{id}/handoffs/execute.md`:

```markdown
# execute Handoff

## Summary
- Mode: {step-by-step / subagent-driven}
- Tasks completed: {N}
- Commits: {N}

## Tasks
### Task 1: {title}
- Status: complete
- Files changed: {list}
- Anchor: pass
- User verified: yes

### Task N: ...

## Anchor Results
- {N} pass / {N} fail
- Details: {any notable results}

## Test Scope for Quality
- Build: full rebuild needed
- Tests: {which test suites to run}
- Additional checks: {any manual verification}

## Files Changed
- {path}
- {path}
```

---

## Completion

- All tasks/chunks executed
- All anchor checks passed
- All AI tests passed
- User verified each task (step-by-step) or all tasks (subagent-driven)
- Handoff written with test scope for quality stage

## Recovery

- Anchor failure → fix in current task, re-check
- Test failure → debug, fix, re-test
- Subagent failure → dispatch fix subagent with specific error context
- User rejects verification → identify issue, fix, re-present verification
