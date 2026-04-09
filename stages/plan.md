# plan

## Progress

- total: 7
- steps:
  1. Step 1: Execution Mode
  2. Step 2: Spec Preferences
  3. Step 3: Decision Points
  4. Step 4: Generate Anchors
  5. Step 5: Split Tasks
  6. Step 6: User Confirm
  7. Write Handoff

From design handoff to executable task list. Determine specs, identify risks, generate anchors, split tasks.

Model: sonnet

## Mode

- **plan=1:** Minimal. Skip Step 2-3. Directly split tasks from design, basic anchors.
- **plan=2:** Full Step 1-5.
- Mode determination criteria: see SKILL.md → Mode Determination section.

## Input

- design handoff: delivery form, design content, file structure, constraints
- User description + evaluate result (if design was skipped)

---

## Step 1: Execution Mode

Ask user to choose:

```
How to execute this sprint?

A) Step-by-step — tasks run one at a time in this session.
   You verify each task before the next one starts.

B) Subagent-driven — tasks split into parallel chunks,
   dispatched to subagents. You verify after all complete.

C) Deferred — save the plan and execute later.
   Choose a trigger: after another sprint, or manual.
```

Then ask:

```
Commit strategy:

A) Commit after each task completes
B) Commit all changes together after sprint completes
```

Record choice in plan handoff under "Commit Preference".

### Option C: Deferred Execution

If user picks C, collect trigger strategy:

```
When should this sprint resume?

A) /loop polling — resume within an active session (requires session to stay open)
B) Manual — run `/todo {sprint_id}` when ready (cross-session)
```

Then:
1. Complete remaining plan steps (anchors, tasks) as normal
2. Write trigger to `.sprint/triggers.json`:
   ```json
   {
     "sprint_id": "{id}",
     "type": "loop|manual",
     "spec": "{null or loop interval}",
     "resume_stage": "execute",
     "created_at": "{ISO timestamp}"
   }
   ```
3. For `type=loop`: start a `/loop` polling check within the active session.
4. For `type=manual`: no extra setup — user runs `/todo {sprint_id}` when ready.
5. Skip execute stage. Write plan handoff as normal, then end the pipeline at plan stage.

Output:
```
Sprint #{id} plan saved. Trigger: {type}
Resume with: /todo {id}
```

---

## Step 2: Spec Preferences (plan=2 only)

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

## Step 3: Decision Points (plan=2 only)

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

## Step 4: Generate Anchors

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

## Step 5: Split Tasks

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

### Step-by-step mode

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

### Subagent-driven mode

Split tasks, then further split into parallelizable chunks.

Per task → per chunk:
```
### 📋 Task {N}: {title}

- Chunk {N.1}: {subtitle} — parallel
- Chunk {N.2}: {subtitle} — parallel
- Chunk {N.3}: {subtitle} — sequential (depends on N.1)

---
```

Each chunk has same structure as step-by-step task: files, steps, model, verify.

### Expected Files

Aggregate all files from all tasks:

```
## Expected Files
- {path}
- {path}
```

---

## Step 6: User Confirm

Present summary overview first:

```
**Execution mode**: {step-by-step / subagent-driven / deferred}
**Commit preference**: {after each task / after sprint completes}
**Anchor**: {N} rules

- Task 1: {title} — {N} files
- Task 2: {title} — {N} files
- Task 3: {title} — {N} files

**Expected Files**: {total count}
```

Then ask:
```
Confirm the plan, or expand a specific task for details?
```

If user requests details on a specific task, show the full task block (files, steps, model, verify). Then re-confirm.

Wait for user confirmation before writing handoff.

---

## Write Handoff

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
Subagent-driven: all chunks parallel, then unified verify.
```

---

## Completion

- Execution mode confirmed
- Commit preference confirmed
- Specs confirmed (plan=2)
- Decision points reviewed (plan=2)
- Anchors confirmed by user, anchors.txt written
- All tasks satisfy splitting rules (no XL tasks)
- All tasks have: files, steps, model, AI verify, user verify
- Expected files listed
- User confirmed full plan

## Recovery

- Task too large → split further (XL → L or below)
- Missing verify criteria → add before execution
- Design gap found → return to design stage
