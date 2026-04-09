---

## name: sprint
description: Task execution workflow. Evaluates complexity, trims stages, executes step by step with anchor verification.

# Sprint

`/sprint {description}` → evaluate → trim stages → execute pipeline.

## Rules

- When `/sprint` is explicitly invoked, the full sprint flow is mandatory: evaluate → confirm → create → pipeline. No shortcuts, no "just do it". Even if the task looks simple, the evaluate step decides whether to skip stages — not the executor.
- Bash commands marked `# [RUN]` must be executed with Bash tool, not described verbally.
- `[TASK] xxx` triggers TaskCreate. Mark TaskUpdate completed when done.
- Wait for user at `[STOP:confirm]` (only proceed on: ok/yes/continue/确认/好/可以), `[STOP:choose]` (user picks one option), `[STOP:respond]` (user gives substantive reply).
- Questions that ask user to choose must always list explicit options (A/B/C). Never ask a choice question without options.
- Questions that ask user to confirm must always show the content being confirmed. Never ask "confirm?" without showing what to confirm.
- Never expose internal concepts to user: mark names, layer/step/level numbers, evidence levels, algorithm terms, execution mode names. User sees natural conversation and formatted output blocks only.
- Match user's language. Chinese input → Chinese response. English input → English response. Internal docs (skill files, handoffs) stay in English.
- Script paths are relative to this skill's base directory (provided by Claude Code as "Base directory for this skill: {path}"). Set `SPRINT_BASE` to that path, then: `SPRINT_CTL="$SPRINT_BASE/scripts/sprint-ctl.sh"`, `ANCHOR_CHECK="$SPRINT_BASE/scripts/anchor-check.sh"`, stage files at `$SPRINT_BASE/stages/{stage}.md`.

---

## Model Selection

Every stage and subagent task must declare its model. Selection is based on the evaluate level for that stage.

### Per-Stage Rules

Model follows the stage's evaluate level:

| Stage      | quick  | full              |
| ---------- | ------ | ----------------- |
| brainstorm | sonnet | opus              |
| design     | sonnet | opus              |
| plan       | sonnet | sonnet            |
| execute    | sonnet | (per-task below)  |
| quality    | sonnet | sonnet            |
| review     | sonnet | opus              |
| insight    | sonnet | sonnet            |

**Execute per-task rules** (full only):

| Task characteristic                         | Model  |
| ------------------------------------------- | ------ |
| Single file, clear spec from plan           | sonnet |
| Cross-module, interface changes, new API    | opus   |
| Mechanical only (move, rename, formatting)  | haiku  |

**Decision criteria for task model:**
- Does this task change a public interface or API boundary? → opus
- Does this task touch files in 3+ different modules? → opus
- Is the change a direct translation of plan spec? → sonnet
- Is the change purely mechanical (no logic)? → haiku

### Override

Stage files may override the default with:

- File-level: `Model: {opus/sonnet/haiku}` at the top of the stage file
- Step-level: `Step N — Model: opus (reason: ...)` inline

### Logging

- `metrics.log` stage_start event: `{timestamp}|stage_start|{stage}`
- Execute handoff: each task result annotated with actual model used

---

## Evaluate

Extract 4 dimensions from user description, run evaluate command.


| Dimension             | 0                       | 1                       | 2                                    |
| --------------------- | ----------------------- | ----------------------- | ------------------------------------ |
| goal_clarity          | Actionable              | Directional             | Vague                                |
| scope_size            | Point                   | Module                  | System                               |
| risk_level            | Low (local, reversible) | Medium (module impact)  | High (data/auth/prod/delete/migrate) |
| validation_difficulty | Easy (automated)        | Medium (partial manual) | Hard (subjective/complex)            |


Override keywords from description: `delete/migrate/payment/production/permission` → risk=2. `optimize/explore` → clarify≥1. `system/architecture` → design≥1, plan≥1.

```bash
# [RUN]
bash "$SPRINT_CTL" evaluate {gc} {ss} {rl} {vd} {keywords...}
```

### Decision → Stage Mapping


| Decision  | quick            | full                | Stage           |
| --------- | ---------------- | ------------------- | --------------- |
| clarify   | light            | deep                | brainstorm      |
| design    | quick            | research+model      | design          |
| plan      | split tasks      | tasks+deps+anchor   | plan            |
| guardrail | basic verify     | full+review         | quality, review |


execute and insight: always.

### Mode Determination

Evaluate also determines the mode level for each stage that has modes:

| Mode | Determines | quick | full |
|------|-----------|-------|------|
| clarify | brainstorm depth | Goal clear, uncertainty is "how" not "what" | Strategic/exploratory description + new Object + no clear exclusions |
| design | design depth | Direction already clear from brainstorm | Multiple technical paths need comparison |
| plan | plan depth | Small scope or few files | Cross-module changes + risk points exist |

Mode levels are output alongside stage trimming in the evaluate result.

### Evaluate Output

Render evaluate result in formatted block. Wait for user confirmation before creating sprint.

Evaluate output format:
```
### 评估: {description}

- **流水线**: {stage1} → {stage2} → ...
- **跳过**: {stages}
- **理由**:
  - {stage}: {one-line justification}
  - ...
```

```bash
# [RUN] after confirm
bash "$SPRINT_CTL" create "{desc}" "{stages}"
bash "$SPRINT_CTL" activate "{id}"
```

---

## Directory

```
.sprint/{id}/
├── state.json      # created → running → completed
├── handoffs/       # stage handoff docs
├── anchors.txt     # plan produces, execute verifies
└── metrics.log     # append-only event log
```

Handoff minimum: `## Conclusion` + `## Downstream` + `## Output`. Plan adds `## Expected Files`. Each stage file defines its specific template.

Anchor format: `MUST_NOT_IMPORT`, `MUST_IMPORT`, `MUST_NOT_EXIST`, `MUST_EXIST`, `MUST_BUILD`, `MUST_TEST`, `FILE_NOT_MODIFIED` — one assertion per line.

Metrics: `{timestamp}|{event}|{data...}` — sprint_start, stage_start, stage_end, anchor_check, sprint_end.

---

## Stages


| Stage      | File                   | When          |
| ---------- | ---------------------- | ------------- |
| brainstorm | `stages/brainstorm.md` | clarify ≥ 1   |
| design     | `stages/design.md`     | design ≥ 1    |
| plan       | `stages/plan.md`       | always        |
| execute    | `stages/execute.md`    | always        |
| quality    | `stages/quality.md`    | guardrail ≥ 1 |
| review     | `stages/review.md`     | guardrail ≥ 2 |
| insight    | `stages/insight.md`    | always        |


---

## Pipeline

For each stage in trimmed pipeline:

1. `bash "$SPRINT_CTL" stage "{id}" "{stage}" running`
2. Read `stages/{stage}.md`, execute by level from evaluate output
3. Write handoff if applicable
4. `bash "$SPRINT_CTL" stage "{id}" "{stage}" completed`

### Stage Task Rules

- Do NOT create a TaskCreate for each stage. Stage progress is tracked by sprint-ctl.
- Within a stage, create TaskCreate only when the stage has multi-step procedural work that benefits from progress tracking (e.g., design Step 5 detail decisions, execute implementation tasks).
- For confirmation-oriented work within a stage, use checklist display instead of tasks.

### Stage Transition Rules

- Each stage must reach full consensus with user on all discussion items before moving to next stage.
- When presenting issues/improvements for discussion, go through each item and reach agreement before declaring the stage complete.
- Explicitly tell user "entering next stage: {name}" and get confirmation before proceeding.

### User-Facing Communication

- All internal markers (`[STOP:confirm]`, `[STOP:choose]`, `[STOP:respond]`, `[TASK]`, stage/level/step numbers) must NEVER appear in user-facing output.
- Use natural language prompts instead:
  - Confirmation: "以上理解是否准确？有需要调整的地方请指出。"
  - Choice: "请选择一个方向：" followed by A/B/C options
  - Response: "你觉得呢？" or context-appropriate question
- SKILL.md and stage files still use these markers as AI behavior instructions internally.

### Confirmation Skip

Users can skip confirmation points by expressing skip intent (go, ok, continue, 下一步, 跳过, etc.). AI judges by intent, no specific keywords required:

- Skip intent → accept current output, move to next step
- Discussion intent (question, objection, modification) → continue discussing current step
- core decisions in Decision Register cannot be skipped

Do not prompt "reply go to skip" — let the interaction flow naturally.

### Pace Principle

brainstorm, design, and plan stages are thinking stages. Their value comes from thorough alignment and deliberation, not speed. Confirmation points in these stages are necessary quality gates — do not rush through them.

### Progress Indicator

Every AI response to user must start with progress context, separated from body by a blank line.

**Layer 1: Stage progress bar** — show when entering a new stage OR on first interaction of a stage:

```
━━ {stage1} ✓ → [{current}] → {stage3} → ... ━━
```

Rules:
- `✓` after completed stages
- `[name]` for current stage (brackets highlight)
- Plain text for pending stages
- Skipped stages are omitted from the bar

**Layer 2: Step progress** — show on every interaction within a stage:

```
{stage} ({current_step}/{total_steps}) — {step_name}
```

Step counts and names come from each stage file's `## Progress` metadata.

**Layer 3: Task tracking** — when a step contains ≥3 sub-tasks, use TaskCreate to create a task list. Update via TaskUpdate as each completes. When <3 sub-tasks, discuss inline without creating tasks.

**Display**: Layer 1 on first line, Layer 2 on second line, blank line, then body content. Example:

```
━━ brainstorm ✓ → [design] → plan → execute → quality → insight ━━
design (4/7) — Solution Alignment

{body content here}
```

### Chaining

Each stage reads upstream handoff. design skipped → plan uses user description. execute reads plan + anchors.txt. quality reads execute handoff. review reads execute handoff + git diff.

```bash
# [RUN] after all stages
bash "$SPRINT_CTL" end "{id}"
```

