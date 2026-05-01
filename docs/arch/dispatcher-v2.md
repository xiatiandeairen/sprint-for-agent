# Sprint v2 Dispatcher — Workflow Cookbook & Decision Tree

> 本文档定义 sprint v2 的 dispatcher（调度算法）：给定用户 prompt，输出可执行的 stage 编排流。**仅 arch 文档**，不含实现代码。与 [`stage-v2.md`](./stage-v2.md) 配合——stage-v2.md 定义原子集，本文定义如何选 + 如何拼。

---

## 1. 目标与定位

### 目标

把任意用户 prompt 转换为 v2 stage 编排流（含原语：`→` `∥` `↺` `⊢`），让用户拿到的不是抽象架构而是**直接可执行的工作流**。

### 与 stage-v2.md 的关系

| 文档 | 职责 |
|---|---|
| `stage-v2.md` | 16 个原子 stage + 4 个编排原语 + 18 子场景的定义 |
| `dispatcher-v2.md`（本文）| 调度算法：决策树 → 选工作流 → 用户微调 → 输出编排流 |

### 显式不覆盖

- dispatcher 实现代码 / 测试 / 集成（属后续实现 sprint）
- 跨 sprint 触发 / 异步编排
- 工作流自动学习 / 演化机制

---

## 2. Pipeline 总览

```
[用户 prompt]
   ↓
Phase 1: 决策树（8 问 yes/no + LLM/用户兜底）           §4
   ↓
Phase 2: 场景建议呈现（子场景 + 默认/备选工作流）      §5
   ↓
Phase 3: 用户确认 + 微调（5 操作）                     §6
   ↓
[最终 stage 编排流]
```

**核心思想**: dispatcher 不构造工作流，而是**在 9 个预制工作流中选 1 个**。复杂编排（迭代环 / 反馈分支 / 跨域桥）通过工作流内**可选编排原语**表达，不靠叠加生成。

---

## 3. 工作流库（9 个预制）

每个工作流是固定的 stage 编排。编排串中 `[...]` 标注**可选段**，按场景启用；未加 `[]` 的为必经 stage。

### 3.1 工程域（5 个）

| ID | 名称 | 完整编排 |
|---|---|---|
| **E-Quick** | 小需求 | `clarify → implement → verify` |
| **E-Standard** | 标准开发 | `clarify → explore → decide → specify → split → [∥] implement → verify → reflect` |
| **E-Iterate** | 迭代精修（重构 / 调优 / 性能） | `clarify → decide → specify → [split] → (implement → verify) [↺] [⊢ {pass: reflect \| fail: specify}] [↺ benchmark] → reflect` |
| **E-Bug** | bug 修复 | `[frame] → probe → analyze → [decide] → implement → verify → [reflect]` |
| **E-Doc** | 文档（PRD / TD / 使用文档）| `clarify → explore → decide → specify` |

### 3.2 分析域（4 个）

| ID | 名称 | 完整编排 |
|---|---|---|
| **A-RootCause** | 根因分析 | `frame → probe → analyze → conclude → learn` |
| **A-Multi** | 多源汇合（调研 / 审计 / 头脑风暴 / 洞察 / 周期回溯）| `frame → (probe∥ \| research∥) → [compare] → synthesize → conclude → learn` |
| **A-Selection-Land** | 选型 + 跨域落地 | `frame → (research∥) → compare → conclude ⊢ {ok: specify → implement → verify \| 不定: probe → conclude}` |
| **A-Retro** | 单事件复盘 | `frame → probe → analyze → reflect` |

---

## 4. 决策树（8 问）

LLM 基于 prompt 语义答 yes/no。每问独立可答。

```
Q1 输出可执行制品（代码 / 系统 / 制品）？
├ Y 工程域
│   Q2 修复已存在 bug / 异常？               → Y → E-Bug
│   Q3 仅产文档（PRD / TD / 使用文档）？      → Y → E-Doc
│   Q4 小需求（≤ 1 文件 / 一行改）？           → Y → E-Quick
│   Q5 改造现有代码（重构 / 迁移 / 性能）？    → Y → E-Iterate
│   否则                                      → E-Standard
└ N 分析域
    Q6 跨域含落地（调研 → 实现 / 选型 → 实现）？→ Y → A-Selection-Land
    Q7 追根因（"为什么 X" / 异常归因）？        → Y → A-RootCause
    Q8 单事件复盘（独立事件 reflect 终点）？    → Y → A-Retro
    否则                                      → A-Multi
```

### 4.1 兜底机制

| 场景 | 行为 |
|---|---|
| 单问 LLM confidence < high | 让用户答 yes/no |
| 连续 ≥ 3 问需用户答 | 提示"任务描述太模糊，可否补充具体信息" |
| 全树无命中 | 默认 E-Standard（工程）/ A-Multi（分析），由 Q1 决定 |

### 4.2 与原 12 问对比

合并掉的 4 问：

| 原问 | 处理 |
|---|---|
| 因明 / 因不明 | E-Bug 内部 `frame` 可选，由 prompt 含义决定 |
| 性能调优 | E-Iterate 启用 `↺ benchmark` |
| 设计反馈环 | E-Iterate 启用 `⊢ {pass / fail}` |
| 拆并行 | E-Standard split 后由 §6 微调触发 `∥ implement` |
| 分析类型（调研 / 审计 / 头脑风暴）| A-Multi 默认覆盖，输入源由 prompt 推断 |

---

## 5. 场景定制（基于模板完善实际流程）

工作流是模板，子场景的真实流程通过"模板 + 定制"得出。下表对每个子场景给出：选哪个模板、启用/关闭哪些可选段（含输入源选择）、最终落地到的具体 stage 编排。dispatcher 在 §6 微调前向用户呈现该行——让用户判断"模板是否合适 / 定制是否准确 / 是否要进一步调整"。

| 子场景 | 模板 | 定制 | 实际编排 |
|---|---|---|---|
| L1a 小需求 | E-Quick | — | `clarify → implement → verify` |
| L1b 长需求（串行）| E-Standard | 关 `[∥]` | `clarify → explore → decide → specify → split → implement → verify → reflect` |
| L1b 长需求（可并行）| E-Standard | 开 `[∥]`（split 后微调触发）| `... → split → ∥ implement → verify → reflect` |
| L1c bug（因明）| E-Bug | 关 `[frame]` `[decide]` `[reflect]` | `probe → analyze → implement → verify` |
| L1c bug（因不明）| E-Bug | 开 `[frame]` `[decide]` `[reflect]` | `frame → probe → analyze → decide → implement → verify → reflect` |
| L1d 重构（基本款）| E-Iterate | 开 `[↺]`；关其余 | `clarify → decide → specify → split → (implement → verify) ↺ → reflect` |
| L1d 重构（含设计反馈）| E-Iterate | 开 `[↺]` `[⊢]` | `... → split → (implement → verify ⊢ {pass: reflect \| fail: specify}) ↺ → reflect` |
| L1e 删除迁移 | E-Iterate | 开 `[↺]`；关其余 | 同 L1d 基本款 |
| L1f 性能优化 | E-Iterate | 开 `[↺]` `[↺ benchmark]` | `clarify → decide → specify → ((implement → verify) ↺) ↺ benchmark → reflect` |
| L2a PRD | E-Doc | — | `clarify → explore → decide → specify` |
| L2b TD/RFC | E-Doc | — | 同 L2a |
| L2c 使用文档 | E-Quick | — | `clarify → implement → verify` |
| L2d 汇报总结 | E-Standard | 关 `[∥]` | 同 L1b 串行款 |
| L3a 问题分析 | A-RootCause | — | `frame → probe → analyze → conclude → learn` |
| L3b 决策分析 | A-Multi | 输入 `research∥`；关 `[compare]` | `frame → research∥ → synthesize → conclude → learn` |
| L3c 现状审计 | A-Multi | 输入 `probe∥`；关 `[compare]` | `frame → probe∥ → synthesize → conclude → learn` |
| L4a 市场调研 | A-Multi | 输入 `research∥`；开 `[compare]` | `frame → research∥ → compare → synthesize → conclude → learn` |
| L4b 技术选型 | A-Selection-Land | — | `frame → (research∥) → compare → conclude ⊢ {ok: specify → implement → verify \| 不定: probe → conclude}` |
| L5a 头脑风暴 | A-Multi | 输入 `research∥`；关 `[compare]` | `frame → research∥ → synthesize → conclude → learn` |
| L5b 深度洞察 | A-Multi | 输入 `probe∥`；开 `[compare]` | `frame → probe∥ → compare → synthesize → conclude → learn` |
| L6a 单事件复盘 | A-Retro | — | `frame → probe → analyze → reflect` |
| L6b 周期回溯 | A-Multi | 输入 `probe∥`；关 `[compare]` | `frame → probe∥ → synthesize → conclude → learn` |

22 行覆盖 18/18 子场景（含 L1b / L1c / L1d 的双变体）。

呈现给用户：

```
基于 prompt → 落到 {子场景}（模板 {workflow}）
定制：{enabled / disabled / 输入源}
实际编排：{concrete chain}
```

用户基于此进入 §6 微调环节。

---

## 6. 用户确认 + 微调（Phase 3）

dispatcher 输出最终编排 + Phase 1 trace 后，用户可选 5 操作：

| 操作 | 语法示例 | 约束 |
|---|---|---|
| **确定** | `ok` | — |
| **换工作流** | `换 E-Iterate` | 候选必须在 9 工作流之内 |
| **换 stage** | `换 explore 为 research` | 必须在该位置候选内（如 α 位 clarify ↔ frame）|
| **加 / 减 stage** | `在 verify 后加 reflect` / `去掉 split` | v2 16 stage 集内；不能减完整编排串中**未加 `[]`** 的必经 stage |
| **重答 Q** | `重答 Q5=Y` | 重跑该问之后子树 |

必经 stage 约束：完整编排串中未加 `[]` 的 stage 不可移除（移除会破坏工作流的核心定位）。

---

## 7. Walkthrough（6 个示例）

| # | Prompt | 决策路径 | 工作流 | 最终编排 |
|---|---|---|---|---|
| 1 | `修登录态过期没刷新的 bug（原因不明）` | Q1=Y, Q2=Y | E-Bug | `frame → probe → analyze → decide → implement → verify → reflect` |
| 2 | `加 dark mode 切换按钮` | Q1=Y, Q2=N, Q3=N, Q4=Y | E-Quick | `clarify → implement → verify` |
| 3 | `重构 logger 模块成 structured log` | Q1=Y, Q2=N, Q3=N, Q4=N, Q5=Y | E-Iterate | `clarify → decide → specify → split → (implement → verify) ↺ → reflect` |
| 4 | `优化数据库慢查询，benchmark 对比` | Q1=Y, Q2=N, Q3=N, Q4=N, Q5=Y | E-Iterate（`↺ benchmark`）| `clarify → decide → specify → ((implement → verify) ↺) ↺ benchmark → reflect` |
| 5 | `调研选 winston / pino，选完落地` | Q1=N, Q6=Y | A-Selection-Land | `frame → (research∥) → compare → conclude ⊢ {ok: specify → implement → verify \| 不定: probe → conclude}` |
| 6 | `分析为什么我们 brainstorm 占比过高` | Q1=N, Q6=N, Q7=Y | A-RootCause | `frame → probe → analyze → conclude → learn` |

6 walkthrough 覆盖 6 工作流（E-Bug / E-Quick / E-Iterate / A-Selection-Land / A-RootCause）+ E-Iterate 双路径示例。其余 3 工作流（E-Standard / E-Doc / A-Multi / A-Retro）映射规则在 §4 给出。

---

## 附录 A：与 v1 dispatcher 关系

v1 SKILL.md 的 dispatcher 由 Input Normalization + Evaluate Q1-Q3（clarify / design / risk）+ override keywords 构成，输出 v1 6-stage 流水线（含 skip）。

| 维度 | v1 | v2 |
|---|---|---|
| 输入处理 | 关键词归类 + 模式匹配 | 决策树 8 问 + LLM 语义判 |
| 决策粒度 | 3 个 yes/no | 8 个 yes/no |
| 输出 | 6-stage 子集（skip 部分）| 9 工作流之一的完整编排（含 ∥ / ↺ / ⊢）|
| 编排能力 | 仅顺序 + skip | 顺序 / 并行 / 迭代 / 分支 / 反馈 / 跨域 |
| 用户微调 | 仅 evaluate 改答案 | 5 操作（含换工作流 / 重答 Q）|

v2 dispatcher 是 v1 评估机制的**完全重写**，对应 v2 stage 模型（16 atomic stage 而非 6 stage）。

---

## 附录 B：演进规则

### 新增工作流

走 [`stage-v2.md` §6 粒度判据](./stage-v2.md#6-粒度判据)：
1. 上限 U1-U3 验证：是否真有现工作流无法表达的编排形态
2. 下限 L1-L3 验证：是否在 ≥ 2 子场景独立调用，是否单一编排形态

满足全部 → 加入工作流库 + 同步更新决策树（在合适分支增加问题）+ 更新子场景反查表。

### 新增决策问

仅在新增工作流时同步增加。**不为单个 prompt 增加 Q**——决策树需要保持稳定。

### 修改决策树

修改决策树需要回归测试 walkthrough（§7 6 个 + design 内 9 全覆盖）。
