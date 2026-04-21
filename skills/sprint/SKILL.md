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
| Auto mode | Hosted sprint mode (`--auto`). Core decision points auto-generate structured self-check blocks; user intervenes only at start and final summary. See Hosted Mode section. |
| Self-check | Mandatory structured block at a core decision point in auto mode: decision + bound principles + per-principle audit + G1 failure attribution + G2 rejected alternatives + G3 off-list blindspot. Defined in `skills/sprint/auto-principles.md`. |

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

**Q4 (conditional — only if `--auto` not passed and no keyword detected)**:

| Question | yes | no | Hint |
|----------|-----|-----|------|
| 是否启用托管模式？ | auto=1 | auto=0 (default) | 启用后核心决策点由原则自检推进，你只在开始和最终汇总时介入 |

See Hosted Mode section for details.

```
### 评估: {description}
- **类型**: {普通任务 | 文档任务}
- **流水线**: {stages}
- **跳过**: {stages} — {理由}
```

**HINTS**: evaluate outputs a `HINTS` section when historical trends or anomalies are detected from `.sprint/summary.json`. Present HINTS to user between evaluate output and confirmation. No HINTS = don't mention it.

```bash
# [RUN] after confirm
# Determine AUTO first (before calling evaluate):
#   - user typed `/sprint --auto {desc}` → AUTO=1
#   - desc contains 托管/hosted/委托/autopilot keyword → AUTO=1
#   - evaluate Q4 answered yes → AUTO=1
#   - otherwise → AUTO=0

# Then run:
if [ "$AUTO" = "1" ]; then
  bash "$SPRINT_CTL" evaluate {clarify} {design} {risk} auto=1
  bash "$SPRINT_CTL" create "sprint" "{desc}" "{stages}" "low" "1"
else
  bash "$SPRINT_CTL" evaluate {clarify} {design} {risk}
  bash "$SPRINT_CTL" create "sprint" "{desc}" "{stages}"
fi
bash "$SPRINT_CTL" activate "{id}"
```

**Auto propagation contract**: AUTO must be resolved **before** calling `evaluate` and `create`. If `evaluate` output includes `auto=1`, the corresponding `create` call MUST pass `"1"` as the 5th positional argument. Otherwise `state.json.auto` stays `false` and hosted-mode self-check triggers will not fire. The bash `if/else` above is mandatory — do NOT use a single-form invocation with unresolved `{auto_flag}` placeholder.

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
- Errors include: what failed, which command, suggested fix.
- Match user's language for all output; internal docs stay English.
- **User-facing interaction rules**: follow `~/.claude/rules/skill.md` §6 (no internal algorithm term leakage, language baseline, disclosure granularity). Sprint-specific term replacements: see `skills/sprint/interaction-terms.md`. When producing user-visible text: scan against the term table, drop forbidden fillers (尽量/适当/大概/或许/roughly/approximately/maybe/perhaps), and hide internal judgment process / raw state structures per §6.3.
- **Assumptions block** — The first substantive output of each thinking stage (brainstorm Step 1, design Step 2, plan Step 3-5 combined) must end with a `## Assumptions` block listing ≥3 load-bearing assumptions, each with evidence source. User refutes specific items (`A2 错，应该…`) instead of re-describing the need. Format:
  ```
  ## Assumptions（哪条错了告诉我）
  - [A1] {assumption} — 来源：{description phrase / prior handoff line / inferred from X}
  - [A2] ...
  - [A3] ...
  ```
  Skip only when the stage's own output already enumerates explicit decisions (e.g. Decision Register with `○ direction` / `✗ open` statuses), since those serve the same function.

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

## Hosted Mode (`--auto`)

托管模式：核心决策点由主 agent 按原则约束做结构化自检，主流程自动推进，用户完全旁观，sprint 结束时看汇总。

### 触发方式（三选一）

1. **参数**：`/sprint --auto {desc}`
2. **关键词**：`/sprint {desc}` 且描述含 `托管` / `hosted` / `委托` / `autopilot`
3. **评估问询**：前两者都没命中时，Evaluate 阶段出 Q4 询问

命中任一 → `state.json.auto = true`。

### 触发时的行为

**自动决策点**（由 `skills/sprint/auto-principles.md` §"决策点映射" 定义，当前 6 个）：
- brainstorm Step 1 末：需求锁定
- design Step 1 末：方案选择
- design Step 2 末：设计决策
- design Step 4 末：系统设计（若该子层触发）
- plan Step 4 末：任务切分
- review Step 6：Review Verdict

每个触发点，主 agent **必须**产出自检 block（结构见 `auto-principles.md` §"自检 block 模板"，含 G1/G2/G3 强制字段），写入该阶段 handoff 的 `## 自动审视` section。

**不等待用户确认**：核心决策产出 + 自检完成即进入下一步。handoff 写入、阶段切换均自动。

**唯一用户介入点**：
- sprint 开始（触发方式 1/2 无需任何交互；3 需要用户答 Q4 y/n）
- insight 阶段的"自动审视汇总"呈现后，用户回复 `approve` / `重跑 N[,M]` / `审视 N`

### 与现有 `如需对抗性审视，回复"审视"` 的关系

- **非 auto 模式**：保持原样（用户 on-demand 单点挑战）
- **auto 模式**：每决策点的自检 block 内置 G3（清单外盲点）提供发散挑战，**替代**现有机制；最终汇总阶段用户可用 `审视 N` 对某点做更深质疑

### Hosted Mode 的 Hard Rules

- auto 模式下，自检 block 的 G1/G2/G3 三字段**任一缺失**视为 handoff 不完整，流程阻断并报错
- 决策点所在步骤被 gate 跳过 → 不产出对应自检 block（不视为缺失）
- 非 auto 模式下任何 stage 文件必须保持原行为，自检相关代码路径静默

#### Auto mode hard rule: no soft-pause between stages

When `state.json.auto == true`, the main agent **must not end a response with a question, soft-wait prompt, or ambiguous "进入下一阶段?" phrasing**. Ending a response at a stage boundary is an **implicit pause** equivalent to asking for confirmation, which violates hosted-mode contract.

**Required behavior**: within the **same turn**, the main agent must:
1. Write the current stage's handoff
2. Run `sprint-ctl stage {current} completed`
3. Run `sprint-ctl stage {next} running`
4. Immediately begin executing the next stage's steps (produce output, run tools, etc.)

The only allowed pauses in auto mode are:
- **Sprint start**: after Q4 answer (if Q4 fired)
- **Final summary in insight**: user replies `approve` / `重跑 {ID}` / `审视 {ID}`
- **Hard failure**: a tool call or anchor-check failure that needs user input (with explicit error message)

Forbidden phrases at end of a response when `state.json.auto == true`:
- "进入 plan?" / "ready to continue?" / "确认吗？"
- "所有决策 ✓。进入 X" followed by stopping (this is a soft pause)
- Trailing bare question marks or menu offers unrelated to the final summary

Violation detection: if the last ≤2 lines of a response contain `?` / `？` / "确认" / "继续?" / "ready" / "ok?" AND the current sprint's `state.json.auto == true` AND no hard-failure occurred, the response is non-compliant.
