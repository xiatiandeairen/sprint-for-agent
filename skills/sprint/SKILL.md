---
name: sprint
description: Task execution workflow. Evaluates complexity, trims stages, executes step by step with anchor verification.
---

# Sprint

`/sprint {description}` → evaluate → trim stages → execute pipeline.

## Core Principles

1. **Evaluate first** — 3 yes/no questions determine pipeline shape. Every task goes through evaluate.
2. **Staged handoff** — each stage reads upstream handoff and writes its own. No stage operates without context.
3. **Anchor verification** — structural assertions complement tests. Never skip anchors even if tests pass.
4. **User controls direction** — AI executes, user confirms at gate points. Core decisions cannot be skipped.
5. **Minimum pipeline** — skip stages that add no value. "No issues found" is valid output.

## Definitions

| Term | Meaning |
|------|---------|
| Stage | Pipeline phase: brainstorm → design → plan → execute → review → insight |
| Step | Numbered progression within a stage (from stage file `## Progress`) |
| Task | Independently verifiable work unit (plan splits, execute runs) |
| Anchor | Structural assertion in `anchors.txt`: `MUST_BUILD`, `MUST_EXIST`, `MUST_TEST`, `MUST_IMPORT`, `MUST_NOT_IMPORT`, `MUST_NOT_EXIST`, `MUST_CONTAIN`, `MUST_NOT_CONTAIN`, `FILE_NOT_MODIFIED` |
| Lock | Immutable decision point: Demand Lock, Value Lock (brainstorm) |
| Handoff | Stage output document, structure defined by each stage file's template |
| Gate | Step entry condition: `user` (yes/no), `auto` (system evaluates), `always` |

## Rules

### Hard Rules

Stage files may strengthen but not contradict these.

- Do not modify files outside the task's declared file list. Flag unlisted changes.
- Do not skip anchor checks, even if tests pass.
- Do not mix "add feature" and "refactor" in a single task.
- Do not force output when nothing substantive exists. "No issues" / "No lessons" is valid.
- Do not classify user-requested changes as "issues". Change-requests are neutral.

### Behavioral Rules

1. **Conversation stages don't read code** — brainstorm, design Step 1, long Steps 1-5: all evidence from user. No code/file reads until direction confirmed.
2. **Only build on confirmed information** — no follow-ups or designs based on unconfirmed assumptions.
3. **Justify questions; converge when complete** — each question states why. All slots filled + no question changes output → stop asking.
4. **Incremental value per stage** — inherit upstream directly. quality doesn't re-test tasks. review doesn't re-check anchors.
5. **Bounded exploration** — open loops declare max rounds. At limit, force convergence.
6. **Subagent escalation** — 1st fail: retry same model. 2nd: upgrade (sonnet→opus). 3rd: stop, report.
7. **Handoff is terminal** — written as final step, after all work + user confirmation.
8. **Confirm before persisting** — handoffs, Locks, reports: user confirms before write. (anchors.txt: auto-extracted in plan, presented for additions — see plan Step 3.)
9. **Precise recovery** — return to stage + step number. Never "start over".
10. **Max 3 options** — >3 candidates → filter first, present top 3.
11. **Gate merge** — when Gates skip early steps in a stage, merge remaining steps into one combined output with one confirmation. Do not present intermediate artifacts (e.g. anchors) without surrounding context (e.g. task split).

### Internal Markers

| Marker | Action |
|--------|--------|
| `# [RUN]` | Execute with Bash |
| `[TASK] xxx` | TaskCreate; TaskUpdate completed when done |
| `[STOP:confirm]` | Wait for ok/yes/continue/确认/好/可以 |
| `[STOP:choose]` | User picks option |
| `[STOP:respond]` | User gives substantive reply |

Never expose markers, step numbers, or algorithm terms to user. Match user's language; internal docs stay English.

### Script Paths

From "Base directory for this skill: {path}", strip `skills/sprint/` to get project root.
```
SPRINT_CTL="{project_root}/scripts/sprint-ctl.sh"
ANCHOR_CHECK="{project_root}/scripts/anchor-check.sh"
```

### Model Selection

Declare per step. Default: sonnet.

| Scenario | Model |
|----------|-------|
| Reasoning, comparison, design | opus |
| Clear spec, coding, verification | sonnet |
| Mechanical: move, rename, format | haiku |

Execute override: cross-module → opus. Single file → sonnet. No logic → haiku.

## Defaults

| Situation | Action |
|-----------|--------|
| Empty description | Ask for description |
| <5 words + ambiguous | Ask one clarification question |
| Evaluate answer unclear | Default "no" (skip) |
| Gate inconclusive | Skip |
| One-word at confirmation | Treat as yes |
| One-word at choice | Re-ask with options |
| Upstream handoff missing | Use original description |
| sprint-ctl fails | Report error verbatim, ask retry or skip |

## Workflow

### Pipeline

```
/sprint {description}
    → [Input Normalization] → detect pattern, language, keywords
    → [Evaluate] → 3 yes/no → user confirms → sprint-ctl evaluate + create + activate
    → [Pipeline Loop] → per enabled stage:
        1. sprint-ctl stage running
        2. read stage file, execute steps (respect gates)
        3. write handoff (except insight)
        4. sprint-ctl stage completed
        5. announce next stage, confirm
    → [sprint-ctl end] → insight closes sprint
```

### Input Normalization

| Pattern | Defaults |
|---------|----------|
| "fix X" / "bug in X" | clarify=no, design=no, risk=evaluate |
| "add X" / "create X" | clarify=yes if Goal/Success unclear; design=yes if >3 files or cross-module |
| "refactor X" | clarify=no, design=yes, risk=no |
| "delete X" / "remove X" | clarify=no, design=no, risk=yes |
| doc keywords: prd/tech/文档/doc/roadmap/写文档/write doc | **Doc mode**: skip plan + quality, no anchors |
| File path only | Ask intent first |

### Evaluate

3 yes/no → user confirms or adjusts:

| Question | yes | no | Hint |
|----------|-----|-----|------|
| 需求是否需要澄清？ | brainstorm | skip | 能一句话说清 → 不需要 |
| 是否需要技术设计？ | design | skip | 实现方式唯一且明确 → 不需要 |
| 是否涉及高风险？ | review | skip | 局部可逆、不影响线上 → 跳过 |

- Override keywords `delete/migrate/payment/production/permission` → risk=yes
- Always-on: plan, execute, insight. Review: risk=yes OR (tasks >1 AND cross-module)
- **Doc mode**: skip plan. Pipeline: `[brainstorm] → [design] → execute → insight`

```
### 评估: {description}
- **类型**: {普通任务 | 文档任务}
- **流水线**: {stages}
- **跳过**: {stages} — {理由}
```

**HINTS**: evaluate outputs a `HINTS` section when historical trends or anomalies are detected from `.sprint/summary.json`. Present HINTS to user between evaluate output and confirmation. No HINTS = don't mention it.

```bash
# [RUN] after confirm
bash "$SPRINT_CTL" evaluate {clarify:0|1} {design:0|1} {risk:0|1}
bash "$SPRINT_CTL" create "sprint" "{desc}" "{stages}"
bash "$SPRINT_CTL" activate "{id}"
```

### Pipeline Rules

- **Chaining**: each stage reads upstream handoff. Skipped stage → downstream uses description.
- **Task tracking**: no TaskCreate per stage (sprint-ctl tracks). TaskCreate only for ≥3 sub-tasks — except execute (1 task per plan task).
- **Transitions**: handoff confirmed = auto-enter next stage (no "确认继续？"). Only pause between stages if there is new information to present that the user hasn't seen. Thinking stages (brainstorm/design/plan) — don't rush within the stage.
- **Skip intent**: go/continue/下一步 → accept current, proceed. Core decisions cannot be skipped.
- **Multi-choice** (≥3 dimensions): recommendation table → user flags → expand flagged only. Binary stays inline.

```bash
# [RUN] after all stages
bash "$SPRINT_CTL" end "{id}"
```

### Progress Indicator

Every response starts with:

```
━━ {stage1} ✓ → [{current}] → {stage3} ━━
{stage} ({step}/{total}) — {step_name}
```

`✓`=done, `[x]`=current, plain=pending. Skipped stages omitted.

### Output Rules

- Progress indicator on every response. No exceptions.
- Confirmations show content. No bare "确认？".
- Choices list options (A/B/C). No open "你觉得呢？".
- Stage file templates are mandatory structure.
- Numbers concrete: "3 files" not "several".
- Empty output → "无". Never silently omit.
- Forbidden: 尽量/适当/大概/或许/roughly/approximately/maybe/perhaps.
- Errors include: what failed, which command, suggested fix.
- Match user's language for all output; internal docs stay English.

### Metrics

`metrics.log`: `{timestamp}|{event}|{data}`. Events: sprint_start, stage_start, stage_end, anchor_check, sprint_end.

## Directory

```
.sprint/{id}/
├── state.json      # created → running → completed
├── handoffs/       # stage output docs
├── anchors.txt     # plan produces, execute verifies
└── metrics.log     # append-only events
```

## Stages

| Stage | File | Condition |
|-------|------|-----------|
| brainstorm | `stages/brainstorm.md` | clarify=yes |
| design | `stages/design.md` | design=yes |
| plan | `stages/plan.md` | default on; doc mode: skip |
| execute | `stages/execute.md` | always |
| review | `stages/review.md` | risk=yes OR (tasks >1 AND cross-module) |
| insight | `stages/insight.md` | always |
