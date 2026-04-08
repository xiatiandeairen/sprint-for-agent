# plan

From design handoff to executable task list. Determine specs, identify risks, generate anchors, split tasks.

Model: sonnet

## Mode

- **plan=1:** Minimal. Skip Step 2-3. Directly split tasks from design, basic anchors.
- **plan=2:** Full Step 1-5.

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
   Choose a trigger: specific time, after another sprint, or manual.
```

### Option C: Deferred Execution

If user picks C, collect trigger strategy:

```
When should this sprint resume?

A) At a specific time — e.g. "tomorrow 10am", "2026-04-09 14:00"
B) After sprint {id} completes — chain with another sprint
C) Manual — run `/todo {sprint_id}` when ready
```

Then:
1. Complete remaining plan steps (anchors, tasks) as normal
2. Write trigger to `.sprint/triggers.json`:
   ```json
   {
     "sprint_id": "{id}",
     "type": "at|after|manual",
     "spec": "{ISO time or sprint id or null}",
     "resume_stage": "execute",
     "created_at": "{ISO timestamp}"
   }
   ```
3. For `type=at`: create macOS launchd plist at `~/Library/LaunchAgents/com.loppy.trigger-{id}.plist` to invoke `claude` CLI at the scheduled time. If in an active session, also start a `/loop` polling check.
4. For `type=after`: no extra setup — `sprint-ctl.sh end` checks triggers.json automatically.
5. For `type=manual`: no extra setup — user runs `/todo {sprint_id}` when ready.
6. Skip execute stage. Write plan handoff as normal, then end the pipeline at plan stage.

Output:
```
> Sprint #{id} plan saved. Trigger: {type} {spec}
> Resume with: /todo {id}
```

---

## Step 2: Spec Preferences (plan=2 only)

Present 3 groups of multi-choice preference questions based on delivery form. One round, user answers all at once.

### Question templates by type

**Development tasks:**
```
1. Priority ranking (pick top 2):
   □ Minimize blast radius
   □ Architecture cleanliness
   □ Production stability
   □ Development speed
   □ Test coverage

2. Change strategy:
   □ Minimal diff — touch as few files as possible
   □ Clean cut — refactor if it makes the change cleaner
   □ Future-proof — design for next iteration too

3. Compatibility:
   □ Must be backward compatible
   □ Can break internal APIs if cleaner
   □ Full rewrite acceptable
```

**Design/UI tasks:**
```
1. Priority ranking (pick top 2):
   □ Visual polish
   □ Interaction smoothness
   □ Consistency with existing UI
   □ Development speed
   □ Accessibility

2. Scope:
   □ Pixel-perfect to mockup
   □ Close enough, polish later
   □ Functional first, style second

3. Platform:
   □ Light mode only
   □ Dark mode only
   □ Both modes
```

**Strategy/Policy tasks:**
```
1. Priority ranking (pick top 2):
   □ Accuracy of decisions
   □ Explainability
   □ Performance/latency
   □ Configurability
   □ Simplicity

2. Edge cases:
   □ Handle all known edges now
   □ Handle common cases, log rare ones
   □ Fail safe on unknowns

3. Tuning:
   □ Hardcode good defaults
   □ User-configurable parameters
   □ Auto-tuning
```

Select the template matching the delivery form from design. Adapt questions to specific context.

---

## Step 3: Decision Points (plan=2 only)

Based on specs + design, identify potential decision points in implementation:

- **Compatibility issues:** Will this break existing behavior?
- **Uncertainty:** Parts where the right approach isn't obvious until you try.
- **Risk items:** Data loss, performance regression, security surface.
- **Integration conflicts:** Where new code meets existing code.

Present to user:

```
═══════════════════════════════════════
  ⚠️ Decision Points
═══════════════════════════════════════

  1. {point} — {why it matters}
     Risk: {low/medium/high}
     Mitigation: {proposed approach}

  2. ...

═══════════════════════════════════════

Any additional risks or constraints I should know about?
```

Wait for user to confirm or add information.

---

## Step 4: Generate Anchors

Extract verifiable assertions from:
- Design constraints (do-not-touch files, dependency rules)
- Spec preferences (backward compat → FILE_NOT_MODIFIED)
- Decision points (risk mitigations → specific checks)

Write to `.sprint/{id}/anchors.txt`:

```
MUST_BUILD
MUST_TEST
MUST_NOT_IMPORT {target} {module}
MUST_EXIST {path}
FILE_NOT_MODIFIED {path}
...
```

---

## Step 5: Split Tasks

### Step-by-step mode

Split into tasks. Each task is the **smallest independently verifiable unit**.

Per task:
```
═══════════════════════════════════════
  📋 Task {N}: {title}
═══════════════════════════════════════

  Files:
  - create: {path}
  - modify: {path}

  Steps:
  1. Write test: {what to test}
  2. Run test → expect FAIL
  3. Implement: {what to write}
  4. Run test → expect PASS
  5. Commit

  Model: {sonnet / opus}
  AI verify: {build + test + anchor-check}
  User verify:
  - [ ] {concrete check 1}
  - [ ] {concrete check 2}

═══════════════════════════════════════
```

### Subagent-driven mode

Split tasks, then further split into parallelizable chunks.

Per task → per chunk:
```
═══════════════════════════════════════
  📋 Task {N}: {title}
  ├─ Chunk {N.1}: {subtitle}  model={sonnet}  parallel=yes
  ├─ Chunk {N.2}: {subtitle}  model={sonnet}  parallel=yes
  └─ Chunk {N.3}: {subtitle}  model={opus}    parallel=no (depends on N.1)
═══════════════════════════════════════
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

Present full plan to user:
- Execution mode
- Spec preferences summary
- Decision points
- Anchor rules
- Task/chunk list with verify criteria
- Expected files

Wait for user confirmation before writing handoff.

---

## Write Handoff

Write `.sprint/{id}/handoffs/plan.md`:

```markdown
# plan Handoff

## Execution Mode
{step-by-step / subagent-driven}

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
- Specs confirmed (plan=2)
- Decision points reviewed (plan=2)
- anchors.txt written
- All tasks have: files, steps, model, AI verify, user verify
- Expected files listed
- User confirmed full plan

## Recovery

- Task too large → split further
- Missing verify criteria → add before execution
- Design gap found → return to design stage
