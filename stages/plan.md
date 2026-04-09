# plan

## Progress

- total: 6
- steps:
  1. 确认实现偏好
  2. 识别风险点
  3. 设定验证规则
  4. 拆分任务
  5. 确认任务和执行方式
  6. 输出计划文档

From design handoff to executable task list. Determine specs, identify risks, generate anchors, split tasks.

Model: sonnet

## Mode

- **quick:** Minimal. Skip Step 1-2. Directly split tasks from design, basic anchors.
- **full:** Full Step 1-5.
- Mode determination criteria: see SKILL.md → Mode Determination section.

## Input

- design handoff: delivery form, design content, file structure, constraints
- User description + evaluate result (if design was skipped)

---

## Step 1: Spec Preferences (full only)

Read the design handoff content and extract 2-3 relevant preference questions based on what is actually ambiguous or undecided. Do not use fixed templates.

Rules:
- If the design already implies a preference (e.g., "minimal-diff approach", "pixel-perfect to mockup"), show the inferred preference and ask user to confirm rather than re-asking.
- Only ask about dimensions where genuine ambiguity exists.
- One round — user answers all at once.

Example output format:
```
Based on the design, I've inferred:
- Change strategy: Minimal diff (design specifies touch as few files as possible) ✓ confirm?

Open questions:
1. Compatibility: Must be backward compatible, or can internal APIs break if cleaner?
2. Test coverage: Add tests for new code only, or also cover adjacent touched code?
```

---

## Step 2: Decision Points (full only)

Based on specs + design, identify potential decision points in implementation:

- **Compatibility issues:** Will this break existing behavior?
- **Uncertainty:** Parts where the right approach isn't obvious until you try.
- **Risk items:** Data loss, performance regression, security surface.
- **Integration conflicts:** Where new code meets existing code.

Present to user:

```
### ⚠️ Decision Points

1. **{point}** — {why it matters}
   - Risk: {low/medium/high}
   - Mitigation: {proposed approach}

2. ...

---

Any additional risks or constraints I should know about?
```

Wait for user to confirm or add information.

---

## Step 3: Generate Anchors

### Systematic extraction

Auto-generate anchors from these sources in the design handoff:

| Source in design handoff | Auto-generated anchor |
|--------------------------|----------------------|
| File structure: create files | `MUST_EXIST {path}` |
| Constraints: do-not-touch files | `FILE_NOT_MODIFIED {path}` |
| Dependencies: forbidden imports | `MUST_NOT_IMPORT {target} {module}` |
| Project has tests | `MUST_TEST` |
| Project is buildable | `MUST_BUILD` |

Also extract from:
- Spec preferences (backward compat → `FILE_NOT_MODIFIED`)
- Decision points (risk mitigations → specific checks)

### User confirmation

Present the extracted anchor list to user:

```
Extracted anchors:
  MUST_BUILD
  MUST_TEST
  MUST_EXIST src/foo/bar.swift
  FILE_NOT_MODIFIED src/core/legacy.swift

Add, remove, or modify any anchors before I write them?
```

Wait for user response, then write final anchors to `.sprint/{id}/anchors.txt`.

---

## Step 4: Split Tasks

### Task Splitting Rules

**Independent verifiability:** Each task can be verified standalone — it builds, tests pass, and behavior is observable without completing other tasks.

**Single responsibility:** One task = one concern. Do not mix "add feature" + "refactor existing" in the same task.

**Token budget constraint:**

| Size | Files | Lines Changed | Model | Est. Tokens |
|------|-------|--------------|-------|-------------|
| S | 1 file | <50 lines | sonnet | ~5K |
| M | 2-3 files | 50-200 lines | sonnet | ~15K |
| L | 3-5 files | 200-500 lines | opus | ~30K |
| XL | 5+ files | 500+ lines | — | Must split further |

- XL tasks must be split to L or below before execution.
- S tasks may be merged only if merging does not break independent verifiability.

Split into tasks. Each task is the **smallest independently verifiable unit**.

Per task:
```
### 📋 Task {N}: {title}

**Files**
- create: {path}
- modify: {path}

**Steps**
1. Write test: {what to test}
2. Run test → expect FAIL
3. Implement: {what to write}
4. Run test → expect PASS
5. Commit

**AI verify**: {build + test + anchor-check}
**User verify**:
- [ ] {concrete check 1}
- [ ] {concrete check 2}

---
```

### Expected Files

Aggregate all files from all tasks:

```
## Expected Files
- {path}
- {path}
```

---

## Step 5: Confirm Tasks and Execution

Present task summary and execution options together:

```
**Tasks**:

- Task 1: {title} — {size} — {N} files
- Task 2: {title} — {size} — {N} files
- Task 3: {title} — {size} — {N} files

**Anchors**: {N} rules
**Expected Files**: {total count}

Execution mode:
A) Step-by-step — run tasks one at a time, verify each before next
B) Parallel — dispatch to subagents, verify after all complete
C) Deferred — save plan, execute later

Commit strategy:
A) Commit after each task
B) Commit all together after sprint
```

If user requests details on a specific task, show the full task block (files, steps, model, verify). Then re-confirm.

Wait for user confirmation before writing handoff.

### Option C: Deferred Execution

If user picks C, collect trigger strategy:

```
When should this sprint resume?

A) /loop polling — resume within an active session (requires session to stay open)
B) Manual — run `/todo {sprint_id}` when ready (cross-session)
```

Then:
1. Write trigger to `.sprint/triggers.json`
2. For `type=loop`: start a `/loop` polling check within the active session.
3. For `type=manual`: no extra setup.
4. Skip execute stage. Write plan handoff as normal, then end the pipeline at plan stage.

---

## Step 6: Write Handoff

Write `.sprint/{id}/handoffs/plan.md`:

```markdown
# plan Handoff

## Execution Mode
{step-by-step / subagent-driven / deferred}

## Commit Preference
{after each task / after sprint completes}

## Spec Preferences
- {preference 1}
- {preference 2}

## Decision Points
- {point}: {mitigation}

## Tasks

### Task 1: {title}
- Files: {list}
- Steps: {TDD steps with code}
- Model: {sonnet/opus}
- AI verify: {commands}
- User verify: {checklist}

### Task N: ...

## Expected Files
- {path}

## Downstream
Execute stage runs tasks in order.
Step-by-step: coding → anchor → test → review per task, wait for user verify.
Parallel: all tasks dispatched to subagents, then unified verify.
```

---

## Completion

- Specs confirmed (full only, Step 1)
- Decision points reviewed (full only, Step 2)
- Anchors confirmed by user, anchors.txt written (Step 3)
- All tasks satisfy splitting rules (no XL tasks) (Step 4)
- All tasks have: files, steps, model, AI verify, user verify (Step 4)
- Expected files listed (Step 4)
- Execution mode and commit strategy confirmed (Step 5)
- User confirmed full plan (Step 5)
- Handoff written (Step 6)

## Recovery

- Task too large → split further (XL → L or below)
- Missing verify criteria → add before execution
- Design gap found → return to design stage
