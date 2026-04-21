# insight

## Progress

- total: 5
- steps:
  1. Close the sprint
  2. What went differently than planned?
  3. Did the process work well?
  4. What to remember next time?
  5. Auto review summary (auto mode only)

Metrics summary + deviation analysis + process evaluation. Last stage, always runs.

## Hard Rules

- Do not force lessons when nothing notable happened.

## Input

- metrics.log
- All handoffs from completed stages
- plan handoff (expected vs actual)
- execute handoff (task completion details)

---

## Step 1: End Sprint

Model: sonnet

```bash
# [RUN]
bash "$SPRINT_CTL" end "{id}"
```

Prints: per-stage duration, anchor results, scope creep count.

## Step 2: Deviation Analysis

Model: opus

Compare plan vs actual. Classify each deviation:
- `improvement` — found better approach
- `issue` — missed requirement, rework, scope creep
- `change-request` — user changed requirements (neutral)

```
### Plan vs Actual
- **Tasks**: {planned} → {completed} completed, {skipped} skipped
- **Files**: {expected} → {actual} changed
- **Rework**: {count} tasks needed fix

**Deviations**
| Description | Classification |
|-------------|---------------|

**Skipped**: {task, reason}
```

Significant deviation (>30% rework or unexpected files > planned):
- Mostly `issue` → suggest finer task splitting
- `issue` with design gaps → suggest including design stage
- Mostly `change-request` → suggest locking requirements earlier
- Mostly `improvement` → no structural change needed

## Step 3: Process Evaluation

Model: sonnet

Per-stage duration from metrics.log. Calculate time share.

**Time flags**: >40% → `too heavy`. <5% → `too light`.

**Output-value questions** (for unflagged stages):
- Output changed downstream decision? → `essential`
- Confirmed assumption without change? → `helpful`
- Output ignored or redundant? → `could skip`

```
### Process Evaluation
| Stage | Duration | Share | Verdict | Reason |

**Recommendation**: {1 sentence — pipeline for next time}
```

Then run historical comparison:

```bash
# [RUN]
bash "{project_root}/scripts/sprint-insight-stats.sh" "{sprint_id}"
```

If output contains a comparison table, present it to user. If insufficient data, skip silently.

## Step 4: Lessons (optional)

Model: opus

Answer each. "No" → skip. "Yes" → record as lesson.

1. Task needed >1 attempt? → What went wrong first?
2. Execution discovered constraint not in design/plan?
3. Tool/command failed unexpectedly? Workaround?
4. Should a skipped stage have been included?
5. Task took significantly longer than estimate?

No findings = no lessons. Do not force output.

### Lesson → Memory Pipeline

After lessons are identified, filter each for cross-sprint value:

1. Does the lesson reference a specific task number or specific file modification? → **discard** (task-specific)
2. Would this lesson still hold if the task description changed? → **no** → **discard**
3. Pass both filters → **persist to auto memory**

Write each qualifying lesson to memory:
```markdown
---
name: sprint-lesson-{topic}
description: {one-line summary}
type: feedback
---
{lesson content}
**Why:** {from deviation analysis or process evaluation}
**How to apply:** {when this pattern appears in future sprints}
```

Update MEMORY.md index with a one-line pointer.

No qualifying lessons → skip silently. Do not force memory writes.

## Step 5: 自动审视汇总（仅 Auto mode）

Model: sonnet

Gate (auto): `state.json.auto == true` → 执行；否则跳过整个 Step 5。

**Aggregate**: 遍历 `.sprint/{id}/handoffs/*.md`，提取每个文件的 `## 自动审视` section 中的所有 `### 自动审视 — \`{decision-id}\`：...` block。按 `auto-principles.md` §决策点映射 中的 ID 顺序（D1→D2→…→D6）排序。

**Render**:

```
## 自动审视汇总

| ID | Stage | 决策 | 绑定原则 | 对照 | G1 风险 | G2 拒选 | G3 盲点 |
|----|-------|------|---------|------|---------|---------|---------|
| D1-demand-lock | brainstorm | 需求锁定 | {principles} | {✓/partial/weak 汇总} | {G1 一句} | {G2 一句} | {G3 一句或 "已穷尽"} |
| ... |

**总计**: {N_fired} 决策点触发 / {N_all_pass} 全 ✓ / {N_partial} 含 partial 或 weak / {N_blindspot} G3 未穷尽
**说明**: G3 未穷尽的决策点已识别清单外盲点，重跑或审视可收敛

请选择：
- `approve` — 全部通过，关闭 sprint
- `重跑 N` / `重跑 N,M` — 对指定决策点重新产决策 + 自检
- `审视 N` — 对指定决策点做第一性原理深度挑战（比重跑更强）
```

**Command handling**:

| 回复 | 行为 |
|------|------|
| `approve` / `ok` / `确认` | 汇总落盘到 `.sprint/{id}/handoffs/insight.md`，继续 Step 6 lessons |
| `重跑 {ID}` 或 `重跑 {ID},{ID}` | 参数可为决策 ID (如 `D2-solution-approach`) 或短号 (`D2` / `2`)；对每个：读取对应 stage 的上游 handoff 和当前决策 → 主 agent 重新产出决策 + 自检 block → 覆盖 handoff 的对应 block → 重刷汇总表 → 再次呈现 |
| `审视 {ID}` | 参数同上；切换 challenger 角色 + 同 `重跑` 的操作（区别：system prompt 强制质疑"问题是否真实、是否有更简方案、决策是否应逆转"），输出更新的自检 block |
| 其他 | 视作反馈，跟进询问用户意图 |

**User verify (auto mode)**: 
- [ ] 汇总表覆盖所有触发的决策点（未被 gate 跳过的）
- [ ] G3 已穷尽的决策点无后续追问
- [ ] `重跑 N` 或 `审视 N` 的产出写回 handoff，不覆盖其他 block

## Completion

- Sprint ended, metrics printed
- Deviation analysis with classification
- Process evaluation with time ratios
- Lessons noted; qualifying lessons persisted to auto memory
- No handoff (insight is terminal output only)
- **Auto mode**: 自动审视汇总已呈现，用户已 approve 或完成所有重跑 / 审视 请求

## Recovery

- metrics.log missing → skip deviation/process evaluation
- sprint-ctl end fails → proceed with available handoff data
