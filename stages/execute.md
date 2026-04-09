# execute

## Progress

- total: 4
- steps:
  1. Stage Start: Task Tracking
  2. Step-by-step Mode
  3. Subagent-driven Mode
  4. Write Handoff

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

## Stage Start: Task Tracking

At the start of execute stage, before any coding begins:

1. Create a `TaskCreate` for each task from the plan handoff
2. When starting a task → `TaskUpdate` status: `in_progress`
3. When a task completes and is verified → `TaskUpdate` status: `completed`

This gives the user live visibility into overall sprint progress throughout execution.

---

## Step-by-step Mode

For each task in plan handoff:

### 1. Coding

Adapt by task type:

- **Code tasks** → TDD:
  - Write test
  - Run test → confirm FAIL
  - Implement
  - Run test → confirm PASS
  - Build verify (if typed language: run project build command, must pass before proceeding)
  - Commit
- **Doc/config tasks** → write directly + format validation (no TDD cycle needed)
- **Refactor tasks** → run existing tests first → refactor → run tests again (confirm no regression)

Use the model specified in the task (sonnet/opus).

### 2. Anchor Check

```bash
# [RUN]
bash "$ANCHOR_CHECK" "{sprint_id}"
```

If any anchor fails → fix before proceeding. Do not skip.

### 3. AI Test

Run the AI verify commands specified in the task (build, test, lint, etc).

Also check implementation consistency:
- Does the code match the design handoff's stated approach (not freestyle)?
- Are interfaces consistent with the definitions in the plan?
- Are there changes outside the plan's stated scope?

Output: build/test results + implementation consistency check + deviations (if any).

### 4. User Review

Output the task's user verify checklist. For **S-size tasks**, multiple consecutive S-size completions may be batched into a single confirmation prompt. M/L tasks always get individual confirmation.

```
### ✅ Task {N} Complete: {title}

**Files changed**
- {path}: {what changed}

**AI verify**: PASS ✓
**Anchor**: {N} pass / {N} fail
**Implementation**: consistent with plan ✓ (or: deviation — {detail})

**User verify**:
- [ ] {concrete check 1}
- [ ] {concrete check 2}
- [ ] {concrete check 3}

---
```

Wait for user to confirm all checks pass. If issues found → fix and re-verify. Confirmed → next task.

### Loop

Repeat 1-4 for each task until all tasks complete.

---

## Subagent-driven Mode

### Worktree Isolation

Execute creates exactly **1 worktree** at the start of subagent-driven mode. All subagent chunks work within this single shared worktree — they must operate on different files, which is guaranteed by the plan's task splitting strategy.

1. Create worktree via `EnterWorktree`
2. **All** chunks execute inside this worktree (no per-chunk isolation)
3. Quality stage also runs inside the worktree
4. After all chunks pass quality → rebase worktree onto trunk for linear history
   - Rebase conflict → stop, report to user with conflict details
5. `ExitWorktree` to clean up

This allows the user to start a new `/sprint` in the main trunk while this sprint executes in the background.

Step-by-step mode does NOT use worktree — it runs directly on trunk.

### 1. Dispatch

For each chunk in plan handoff:
- Independent chunks → dispatch in parallel as subagents
- Dependent chunks → dispatch sequentially after dependencies complete
- **Upstream failure blocks downstream:** if a chunk fails, all chunks that depend on it are paused and not dispatched until the upstream is fixed and verified
- Each subagent prompt includes: chunk files, steps, code, model specification

Subagent TDD adaptation follows the same rules as step-by-step mode (code → TDD, doc/config → direct write, refactor → test-refactor-test).

After dispatching, show the initial status of all chunks:
```
- chunk 1.1 ✓ complete
- chunk 1.2 ● running
- chunk 2.1 ○ waiting (depends on 1.1)
```

Update this display as each chunk completes. After ALL chunks complete, proceed to Collect Results.

Subagent execution per chunk: coding → anchor-check → AI test (including implementation consistency check) → self-review.

### 2. Collect Results

Wait for all subagents to complete. Collect:
- Changed files per chunk
- Anchor check results
- Test results (build/test/lint + implementation consistency)
- Any errors, deviations, or concerns raised by subagents

### 3. Unified Review

Output combined verification:

```
### ✅ All Chunks Complete

**Task 1**: {title}
- Chunk 1.1: {status} ✓
- Chunk 1.2: {status} ✓
- Chunk 1.3: {status} ✓

**Task 2**: {title}
- Chunk 2.1: {status} ✓
- Chunk 2.2: {status} ✓

**Anchor**: {N} pass / {N} fail
**Build**: PASS ✓
**Tests**: {N} pass / {N} fail
**Implementation**: consistent with plan ✓ (or: deviations — {list})

**User verify**:
- [ ] {check from task 1}
- [ ] {check from task 2}
- [ ] {overall integration check}

---
```

Wait for user to confirm. Issues → dispatch fix subagent for specific chunk, re-verify.

### Recovery (Subagent Failures)

When a subagent chunk fails:

1. **1st failure** → retry with same model, include full error context in the prompt
2. **2nd failure** → upgrade model (sonnet → opus), retry
3. **3rd failure** → stop, report to user with error details for decision

If the failed chunk is upstream of other chunks, those downstream chunks remain paused until the upstream chunk succeeds.

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
- Implementation: consistent with plan
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
- All AI tests passed (build/test/lint + implementation consistency)
- User verified each task (step-by-step) or all tasks (subagent-driven)
- Handoff written with test scope for quality stage

## Recovery

- Anchor failure → fix in current task, re-check
- Test failure → debug, fix, re-test
- Subagent failure → see Recovery section under Subagent-driven Mode
- User rejects verification → identify issue, fix, re-present verification
