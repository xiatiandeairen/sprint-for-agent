---
name: sprint
description: Task execution workflow. Evaluates complexity, trims stages, executes step by step with anchor verification.
---

# Sprint

`/sprint {description}` → evaluate → trim stages → execute pipeline.

## Core Principles

1. **Evaluate first** — 3 yes/no questions determine pipeline shape. Even simple tasks go through evaluate.
2. **Anchor verification** — structural assertions complement tests. Never skip anchors even if tests pass.
3. **Staged handoff** — each stage reads upstream handoff and writes its own. No stage operates without context.
4. **User controls direction** — AI executes, user confirms at gate points. Core decisions cannot be skipped.
5. **Minimum pipeline** — skip stages that add no value. "No issues found" is valid output.

## Definitions

| Term | Meaning |
|------|---------|
| Stage | Pipeline phase: brainstorm → design → plan → execute → quality → review → insight |
| Step | Numbered progression within a stage, declared in stage file's `## Progress` |
| Task | Independently verifiable work unit (plan splits, execute runs) |
| Anchor | Automatically verifiable structural assertion stored in `anchors.txt`: `MUST_BUILD`, `MUST_EXIST`, `MUST_TEST`, `MUST_IMPORT`, `MUST_NOT_IMPORT`, `MUST_NOT_EXIST`, `FILE_NOT_MODIFIED` |
| Lock | Decision lock point — confirmed and immutable. Examples: Demand Lock (brainstorm), Value Lock (brainstorm), Direction Lock (long-sprint) |
| Handoff | Stage output document. Structure defined by each stage file's handoff template. |
| Gate | Step-level entry condition. Types: `user` (yes/no question, user decides), `auto` (system evaluates), `always` (no condition) |

## Rules

### Hard Rules

Apply to ALL stages. Stage files may extend (strengthen) these but must not contradict or duplicate them.

- Do not modify files outside the task's declared file list (applies to execute stage tasks). Flag unlisted changes.
- Do not skip anchor checks, even if tests pass.
- Do not mix "add feature" and "refactor existing code" in a single task.
- Do not summarize code line by line. Explain decisions and data flow.
- Do not force output when nothing substantive exists. "No issues" / "No lessons" is valid.
- Do not classify user-requested changes as "issues". Change-requests are neutral.

### Cross-Stage Rules

Apply to all stages as positive behavioral requirements.

1. **Conversation stages don't read code** — brainstorm, design Steps 1-2, long Steps 1-5: all evidence comes from the user. Do not read code, files, or docs until user has confirmed direction.
2. **Only build on confirmed information** — do not generate follow-ups, hypotheses, or designs based on unconfirmed assumptions. User must confirm before expanding.
3. **Every question justifies itself; converge when no question changes output** — each question must state why it is asked. If all information slots are filled and no question would change any downstream decision, stop asking and converge.
4. **Each stage adds incremental value — don't re-verify upstream** — inherit upstream conclusions directly. quality does not re-test individual tasks (execute did that). review does not re-check anchors (quality did that).
5. **Bounded exploration** — any open-ended loop (value mining, decision convergence, dig deeper) must declare a max round count. At limit, summarize current state and force convergence to next step.
6. **Subagent failure escalation** — 1st failure: retry with error context, same model. 2nd failure: retry with upgraded model (sonnet → opus). 3rd failure: stop, report to user with full error details.
7. **Handoff is the terminal step** — every stage that produces a handoff writes it as the final step, after all work is complete and user has confirmed.
8. **Confirm before writing persistent artifacts** — handoffs, anchors.txt, Lock documents, reports: all require user confirmation before writing to disk.
9. **Recovery specifies exact re-entry point** — when returning to a prior stage, specify stage name + step number. Never "start over from the beginning".
10. **Max 3 options per choice** — any user-facing selection presents at most 3 options. More than 3 candidates → filter first, then present top 3.

### Execution Markers

- `# [RUN]` → execute with Bash tool.
- `[TASK] xxx` → TaskCreate. Mark TaskUpdate completed when done.
- `[STOP:confirm]` → wait (ok/yes/continue/确认/好/可以). `[STOP:choose]` → user picks option. `[STOP:respond]` → user gives substantive reply.

### Communication

- Never expose internal markers to user: `[STOP:*]`, `[TASK]`, step/level numbers, algorithm terms.
- Match user's language. Internal docs stay English. Template strings translate on output.

### Script Paths

Set `SPRINT_BASE` from "Base directory for this skill: {path}":
```
SPRINT_CTL="$SPRINT_BASE/scripts/sprint-ctl.sh"
ANCHOR_CHECK="$SPRINT_BASE/scripts/anchor-check.sh"
```

### Model Selection

Declare at step level, not stage level. Default: sonnet.

| Scenario | Model |
|----------|-------|
| Thinking: reasoning, comparison, trade-off, design | opus |
| Execution: clear spec, coding, verification | sonnet |
| Mechanical: move, rename, format | haiku |

Execute task override: cross-module / interface changes → opus. Single file, clear spec → sonnet. No logic → haiku.

## Default Behaviors

| Situation | Default |
|-----------|---------|
| Description empty | Ask user for description. Do not proceed. |
| Description <5 words and ambiguous | Ask one clarification question before evaluate. |
| Evaluate question answer unclear from description | Default to "no" (skip stage). |
| Gate judgment inconclusive | Default to skip. |
| User gives one-word answer at confirmation | Treat as confirmation (yes). |
| User gives one-word answer at choice point | Ask again with options. |
| Upstream handoff missing (stage was skipped) | Use user's original description as input. |
| `sprint-ctl.sh` command fails | Report error verbatim (what failed, which command), ask user to retry or skip. |

## Input Normalization

Before evaluate, normalize user's description:

| Input pattern | Evaluate defaults |
|---------------|-------------------|
| "fix X" / "bug in X" | clarify=no, design=no, risk=evaluate X |
| "add X" / "create X" | clarify=yes if description lacks Goal or Success slot; design=yes if >3 files or cross-module |
| "refactor X" / "restructure X" | clarify=no, design=yes, risk=no |
| "delete X" / "remove X" | clarify=no, design=no, risk=yes (override keyword) |
| "写 PRD" / "write prd" / "写 tech" / "write tech" / "写文档" / "write doc" / "更新文档" / "roadmap" | type=doc, clarify=evaluate, design=evaluate, risk=no. **Doc mode**: skip plan + quality, no anchors.txt |
| File path only (e.g., `src/foo.ts`) | Ask user to state intent before evaluate |
| Sprint ID (YYYYMMDD-HHMMSS-NNN) | Route to `/todo` resume mode |
| Mixed language input | Respond in dominant language of the description |

## Output Constraints

All user-facing output must follow these rules:

- Every response starts with progress indicator. No exceptions.
- Every confirmation shows what is being confirmed. No bare "确认？".
- Every choice lists explicit options (A/B/C). No open-ended "你觉得呢？".
- Templates in stage files are mandatory output structure — do not freestyle.
- Numbers are concrete: "3 files" not "several files".
- If a step produces no actionable output, state "无" or "none" — do not silently omit.
- Forbidden words: 尽量, 适当, 大概, 或许, roughly, approximately, maybe, perhaps.
- Error messages include: what failed, which file/command, suggested fix.

## Workflow

### Execution Pipeline

```
/sprint {description}
    │
    ▼
[Input Normalization] → parse, detect language, check override keywords
    │
    ▼
[Evaluate] → 3 yes/no → user confirms → sprint-ctl evaluate + create + activate
    │
    ▼
[Pipeline Loop] → for each enabled stage:
    │   1. sprint-ctl stage running
    │   2. read stage file, execute steps (respect gates)
    │   3. write handoff (all stages except insight)
    │   4. sprint-ctl stage completed
    │   5. announce next stage, get confirmation
    │
    ▼
[sprint-ctl end] → insight stage closes sprint
```

### Evaluate

Extract 3 yes/no decisions from description, present with judgment hints, user confirms or adjusts.

| Question | yes → enable | no → skip | Hint |
|----------|-------------|----------|------|
| 需求是否需要澄清？ | brainstorm | skip | 能一句话说清做什么、做到什么程度、不做什么 → 不需要 |
| 是否需要技术设计？ | design | skip | 实现方式唯一且明确 → 不需要 |
| 是否涉及高风险？ | quality + review | quality only | 改动局部可逆、不影响线上数据和权限 → 只需基础验证 |

Override: description contains `delete/migrate/payment/production/permission` → risk=yes.

Always-on: plan, execute, insight. Quality always runs; review only when risk=yes.

**Doc mode** (type=doc from Input Normalization): plan and quality are **skipped**. No anchors.txt generated. Pipeline becomes: `[brainstorm] → [design] → execute → insight`. The 3 evaluate questions still apply for brainstorm/design/review.

```
### 评估: {description}
- **类型**: {普通任务 | 文档任务}
- **流水线**: {stage1} → {stage2} → ...
- **跳过**: {stages}
- **理由**: {stage}: {one-line justification}
```

```bash
# [RUN] after confirm
bash "$SPRINT_CTL" evaluate {clarify:0|1} {design:0|1} {risk:0|1}
bash "$SPRINT_CTL" create "sprint" "{desc}" "{stages}"
bash "$SPRINT_CTL" activate "{id}"
```

### Pipeline Rules

**Stage chaining:** each stage reads upstream handoff. design skipped → plan uses description. execute reads plan + anchors.txt. quality reads execute handoff. review reads execute handoff + git diff.

**Task tracking:** do NOT create TaskCreate per stage (sprint-ctl tracks stages). TaskCreate only for ≥3 sub-tasks within a stage — **except** execute, which creates one task per plan task for progress visibility. Confirmation-oriented work uses checklist display.

**Transitions:** reach full consensus before moving to next stage. Explicitly state "entering next stage: {name}" and get confirmation. brainstorm, design, plan are thinking stages — do not rush confirmation points.

**Confirmation skip:** users express skip intent (go, continue, 下一步) → accept current output, proceed. Core decisions cannot be skipped. Do not prompt "reply go to skip".

**Presentation format for multi-dimensional choices** (≥3 dimensions or ≥3 options):
1. Recommendation table: dimension | recommended | rationale. User confirms or flags.
2. Expand on demand: flagged dimension → show A/B/C for that dimension only.
3. Mark to exclude: "默认全部包含。要排除哪些？" — not combinatorial options.
Binary/single-dimension choices stay inline.

```bash
# [RUN] after all stages
bash "$SPRINT_CTL" end "{id}"
```

### Progress Indicator

Every response starts with:

```
━━ {stage1} ✓ → [{current}] → {stage3} → ... ━━
{stage} ({current_step}/{total_steps}) — {step_name}

{body}
```

`✓` = completed, `[name]` = current, plain = pending, skipped stages omitted. Step counts/names from stage file's `## Progress`.

### Metrics

`metrics.log` records `{timestamp}|{event}|{data...}`. Events: sprint_start, stage_start, stage_end, anchor_check, sprint_end. Execute handoff annotates actual model per task.

## Directory

```
.sprint/{id}/
├── state.json      # created → running → completed
├── handoffs/       # stage handoff docs
├── anchors.txt     # plan produces, execute verifies
└── metrics.log     # append-only event log
```

## Stages

| Stage | File | Condition |
|-------|------|-----------|
| brainstorm | `stages/brainstorm.md` | clarify = yes |
| design | `stages/design.md` | design = yes |
| plan | `stages/plan.md` | always |
| execute | `stages/execute.md` | always |
| quality | `stages/quality.md` | always |
| review | `stages/review.md` | risk = yes |
| insight | `stages/insight.md` | always |
