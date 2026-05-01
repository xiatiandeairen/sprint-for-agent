# execute

## Progress

- total: 4
- steps:
  1. Set up tracking
  2. Build it step by step
  3. Build in parallel
  4. Record results

Run tasks from plan handoff. Each task: coding → build → anchor → test → review.

Default Model: sonnet (override to opus for cross-module / interface tasks)

## Hard Rules

- (extends SKILL.md file modification rule) Unlisted file needs change → **stop and report**, do not continue.
- Do not proceed to next task if current anchor check fails. Fix first.
- **Observer/Synthesizer 分离** (B rule): execute handoff **禁止包含 verdict / 结论性陈述 / keep-drop 表格 / recommendation**. 只允许: raw observations (引用 + 数据), 量化结果, open questions. Verdict 留给 insight stage 合成。
- **跨 sprint 信息不走 handoff** (B6-b): handoff 只对当前 sprint 内部 stage-to-stage 负责。有跨 sprint 价值的输出必须落到**项目 repo** (如 `*.md` 文档) 或 **memory 文件** (`feedback_*.md`)。Handoff 的 "Downstream" section 只描述下一 stage 要读什么，**不描述下一 sprint**。

## Default Anchors

If anchors.txt lacks `MUST_BUILD`, add it. For typed languages (Swift, Kotlin, TypeScript, Rust, Go, Java): build verification mandatory after each task.

## Input

- plan handoff: execution mode, task list, verify criteria, expected files
- anchors.txt

**Doc mode** (plan skipped, no anchors): treat design handoff or original description as a single task. No TDD, no anchor check. Write directly + format validation. Skip Step-by-step/Parallel mode selection — always step-by-step with 1 implicit task.

---

## Stage Start: Task Tracking

Model: sonnet

Before coding: TaskCreate per task from plan. Start → `in_progress`. Verified → `completed`.

---

## Step-by-step Mode

Model: per task from plan handoff `**Model**` field (fallback: sonnet default; opus for cross-module/interface)

For each task:

### 1. Coding

| Task type | Process |
|-----------|---------|
| Code | TDD: write test → run (FAIL) → implement → run (PASS) → build verify → commit |
| Doc/config | Write directly + format validation |
| Refactor | Run existing tests → refactor → run tests (no regression) |

### 2. Anchor Check

```bash
# [RUN]
bash "$ANCHOR_CHECK" "{sprint_id}"
```

Fail → read design handoff (`.sprint/{id}/handoffs/design.md`) Key Decisions section. Output which design decision the failure relates to as diagnostic context. Then fix before proceeding.

Unlisted file change → same backtracking: check design handoff for the relevant constraint before reporting to user.

### 3. AI Test

Run AI verify commands from task. Also check:
- Code matches design handoff approach (not freestyle)?
- Interfaces consistent with plan definitions?
- Changes outside plan scope?

### 4. User Review

```
### Task {N}: {title} — PASS ✓ / FAIL ✗

**自动检查**
- Build: ✓ | 验证清单: {N}/{N} ✓ | 实现一致性: 与规划一致 ✓

**文件变更**
- {path}: {what changed}

**需要你确认**
- [ ] {check 1}
- [ ] {check 2}
```

S-size tasks may batch consecutive completions into single confirmation. M/L get individual confirmation.

Confirmed → next task. Issues → fix and re-verify.

---

## Parallel Mode

Model: per task (sonnet default; opus for cross-module/interface)

### Worktree Isolation

1. `EnterWorktree` — create 1 shared worktree at start
2. All tasks execute in shared worktree (different files guaranteed by plan splitting)
3. Quality stage also runs in worktree
4. All pass → rebase onto trunk. Conflict → stop, report to user.
5. `ExitWorktree`

Step-by-step does NOT use worktree.

### 1. Dispatch

- Independent tasks → parallel subagents
- Dependent tasks → sequential after dependencies complete
- Upstream failure blocks downstream tasks

Each subagent: coding (same TDD rules) → anchor-check → AI test → self-review.

Display: `✓ complete | ● running | ○ waiting (depends on Task N)`

### 2. Collect Results

All complete → collect: files changed, anchor results, test results, errors/deviations.

### 3. Unified Review

```
### 全部完成 — PASS ✓ / FAIL ✗

**任务状态**
| Task | 状态 |

**自动检查**
- Build: ✓ | Tests: {N} pass / {N} fail | 验证清单: {N}/{N} ✓ | 实现一致性: ✓

**需要你确认**
- [ ] {checks from tasks}
- [ ] {integration check}
```

Issues → dispatch fix subagent, re-verify.

### Recovery (Subagent Failures)

1st failure → retry with error context. 2nd → upgrade model (sonnet → opus). 3rd → stop, report to user.

---

## Write Handoff

Model: sonnet

Write `.sprint/{id}/handoffs/execute.md`:

**Cooldown Check**: 若 execute 阶段产出 >10 个数据点 (subagent results / 样本 / readings) 或耗时 >1800s, **在写 handoff 前** flag 一句: "数据密集 execute, 合成 verdict 推到 insight, 此处只记观察"。

```markdown
## Summary
- Mode / Tasks completed (数量而非质量判断)
## Tasks
### Task N: {title}
- Status (done/fail) / Files changed / 完成的动作 (非评价)
## Raw Observations
- 引用, 量化数据, subagent 原话, scan 输出 — 不做 synthesis
## Open Questions
- 观察到但未解的模式 / 矛盾 / 边界情况
## Downstream (本 sprint 内 → insight stage)
- insight 需要 attention 的具体 observation id / question
```

**禁止** (B+D 规则):
- ❌ keep/drop/modify 表
- ❌ "V3→V4 建议 X"
- ❌ "Per-step verdict"
- ❌ "Recommendation" section
- ❌ 评价性形容词 (好/差/有效/冗余/仪式)
- ✅ 事实 ("reader 说 V3 没想关掉, V4 有点想关了")
- ✅ 数据 ("CV=0.3, 熵=1.5")
- ✅ 问题 ("V4 为什么退步?")

---

## Completion

- All tasks executed, anchors passed, AI tests passed, user verified
- Handoff written with test scope for quality

## Recovery

- Anchor failure → fix, re-check
- Test failure → debug, fix, re-test
- Subagent failure → see Recovery above
- User rejects → fix, re-present
