# insight

## Progress

- total: 5
- steps:
  1. 结束 sprint
  2. 与计划相比有什么不同？
  3. 流程跑得顺吗？
  4. 下次要记住什么？
  5. 自动审视汇总（仅托管模式）

指标汇总 + 偏差分析 + 流程评估。**最后一个阶段，始终运行**。

## 1. 硬规则

1. 没有值得记的事情时，不要硬凑教训

## 2. 输入

- metrics.log
- 所有已完成阶段的 handoff
- plan handoff（预期 vs 实际）
- execute handoff（任务完成详情）

---

## 3. Step 1：结束 sprint

Model: sonnet

```bash
# [RUN]
bash "$SPRINT_CTL" stage {id} insight completed
bash "$SPRINT_CTL" end "{id}"
```

打印：每阶段耗时、anchor 结果、范围蔓延次数。

---

## 4. Step 1.5：Counter-Evidence 识别（D 规则，强制）

Model: opus

**在合成任何 verdict 前**，必须从 execute handoff 的 `Raw Observations` + `Open Questions` 里**列 ≥2 条反例**——与主结论冲突 / 表面矛盾 / 反直觉的数据点。

### 4.1 模板

```
### 反例（against 主结论候选 X）
反例 1: {具体 observation 或 quote} — 与 X 冲突的原因: {1 句}
反例 2: {具体 observation 或 quote} — 与 X 冲突的原因: {1 句}
```

### 4.2 处理规则

- 列不出 → insight 标记 "verdict tentative, 反例未识别"，**不得下 strong claim**
- 列得出 → 每条反例必须在后续 verdict 中被**显式处理**（修正主结论 / 限制 scope / 列为 open）
- **本 step 是 Step 2-4 的前置**——跳过 = handoff 不完整

### 4.3 fewshot

Good：
```
反例 1: "execute 末说 V3 已收敛，但 reader 在第 3 轮明确说 V3 信号不清" — 与 verdict "V3 通过" 冲突
反例 2: "anchor 全 PASS，但 user verify 列了 3 条未勾" — 与 verdict "全部完成" 冲突
```

Bad：
```
反例 1: 可能存在反例
反例 2: 理论上有边界情况
```

### 4.4 背景

sprint 20260422-190035（step-by-step ablation）在 execute 末合成的 verdict 有 5 条被 sprint 20260422-211644 重读时修正。这 5 条都是当时 reactions 里明摆着的反例但没停下来想。D 规则机械化"停下来想"。

---

## 5. Step 2：偏差分析

Model: opus

对比 plan vs 实际。给每条偏差分类：

- `improvement` — 找到了更好的做法
- `issue` — 漏了需求 / 返工 / 范围蔓延
- `change-request` — 用户改了需求（中性）

### 5.1 模板

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

### 5.2 显著偏差处理（返工 >30% 或意外文件 > 计划）

- 主要是 `issue` → 建议把任务拆得更细
- `issue` 来自设计缺口 → 建议 design 阶段加回来
- 主要是 `change-request` → 建议更早锁定需求
- 主要是 `improvement` → 不需结构性改动

---

## 6. Step 3：流程评估

Model: sonnet

从 metrics.log 取每阶段耗时。算时间占比。

**时间标记**：>40% → `too heavy`；<5% → `too light`。

**产出价值问题**（未被打标的阶段）：

- 产出改变了下游决策？→ `essential`
- 确认了某假设但没改动？→ `helpful`
- 产出被忽略或冗余？→ `could skip`

**模板**:

```
### Process Evaluation
| Stage | Duration | Share | Verdict | Reason |

**Recommendation**: {1 句 — 下次的流水线}
```

**历史对比**:

```bash
# [RUN]
bash "{project_root}/scripts/sprint-insight-stats.sh" "{sprint_id}"
```

输出含对比表 → 呈现给用户。数据不足 → 静默跳过。

---

## 7. Step 4：教训（可选）

Model: opus

逐条回答。"否" → 跳过。"是" → 记为教训。

1. 任务需要 >1 次尝试？→ 第一次错在哪？
2. 执行中发现了 design / plan 里没有的约束？
3. 工具 / 命令意外失败？怎么绕过的？
4. 被跳过的某个阶段其实应该保留？
5. 任务耗时显著超出估计？

**没有发现 = 没有教训**。不要硬凑输出。

**教训 → Memory 管道**：教训识别完后，逐条过滤跨 sprint 价值：

1. 教训是否引用了具体任务编号或文件改动？→ **丢弃**（任务专属）
2. 任务描述变了之后这条教训还成立吗？→ **不成立** → **丢弃**
3. 两道过滤都过 → **写入 auto memory**

**Memory 模板**：

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

更新 `MEMORY.md` 索引，加一行指针。

**没有合格教训** → 静默跳过。不要硬写 memory。

---

## 8. Step 5：自动审视汇总（仅 Auto 模式）

Model: sonnet

**Gate (auto)**：`state.json.auto == true` → 执行；否则跳过整个 Step 5。

### 8.1 Aggregate

遍历 `{sprint_dir}/handoffs/*.md`，提取每个文件的 `## 自动审视` section 中的所有 `### 自动审视 — \`{decision-id}\`：...` block。按 `auto-principles.zh.md` §决策点映射的 ID 顺序（D1→D2→…→D6）排序。

### 8.2 Render 模板

```
## 自动审视汇总

### 人话版（先读这段）

本 sprint 的核心决策 N 个, 简述如下:
- **D1 {决策点名}**: {用户视角 1 句 — AI 选了什么 / 为什么 / 代价}
- **D2 ...**: 同上
- ...

**总的来说**: {1-2 句 — 主线走向}

### 表格版（detail, 想挑就挑）

| ID | Stage | 决策 | 绑定原则 | 对照 | G1 风险 | G2 拒选 | G3 盲点 |
|----|-------|------|---------|------|---------|---------|---------|
| D1-demand-lock | brainstorm | 需求锁定 | {principles} | {✓/partial/weak 汇总} | {G1 一句} | {G2 一句} | {G3 一句或 "已穷尽"} |

**总计**: {N_fired} 决策点触发 / {N_all_pass} 全 ✓ / {N_partial} 含 partial 或 weak / {N_blindspot} G3 未穷尽

请选择：
- `approve` — 全部通过，关闭 sprint
- `重跑 N` / `重跑 N,M` — 对指定决策点重新产决策 + 自检
- `审视 N` — 对指定决策点做第一性原理深度挑战（比重跑更强）
```

### 8.3 人话版要求（B2 规则）

- 每条决策 1 句话，禁术语（principles id、G1/G2/G3 代号不出现）
- 三段结构："AI 选了 X / 因为 Y / 代价 Z"
- 总结 1-2 句说明本 sprint 主线，不罗列决策
- 人话版在前、表格版在后（允许用户只读人话不读表）

### 8.4 Command handling

- `approve` / `ok` / `确认` → 汇总落盘到 `{sprint_dir}/handoffs/insight.md`，继续 Step 6 lessons
- `重跑 {ID}` 或 `重跑 {ID},{ID}` → 参数可为决策 ID（如 `D2-solution-approach`）或短号（`D2` / `2`）；对每个：读对应 stage 的上游 handoff 和当前决策 → 主 agent 重新产出决策 + 自检 block → 覆盖 handoff 对应 block → 重刷汇总 → 再呈现
- `审视 {ID}` → 参数同上；切换 challenger 角色 + 同 `重跑` 的操作；system prompt 强制质疑"问题是否真实 / 是否有更简方案 / 决策是否应逆转"；输出更新的自检 block
- 其他 → 视作反馈，跟进询问用户意图

### 8.5 User verify（auto 模式）

- [ ] 汇总表覆盖所有触发的决策点（未被 gate 跳过的）
- [ ] G3 已穷尽的决策点无后续追问
- [ ] `重跑 N` 或 `审视 N` 的产出写回 handoff，不覆盖其他 block

---

## 9. 完成条件

- Sprint 已结束，metrics 已打印
- 偏差分析含分类
- 流程评估含时间占比
- 教训已记录；合格教训已写入 auto memory
- 无 handoff（insight 是终端输出）
- **托管模式**：自动审视汇总已呈现，用户已 approve 或完成所有重跑 / 审视 请求

## 10. 恢复

- metrics.log 缺失 → 跳过偏差 / 流程评估
- sprint-ctl end 失败 → 用现有 handoff 数据继续
