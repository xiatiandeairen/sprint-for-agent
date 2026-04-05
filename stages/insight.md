---
name: insight
description: 经验沉淀。记录教训，让下次 sprint 更好
---

# Insight

核心价值：**经验沉淀** — 如果跳过，这次 sprint 的教训（哪里返工了、哪里预估偏了）不会被记录，下次 sprint 重复踩同样的坑。

> 本文件是执行指令。必须按「步骤」段逐步执行，每步验证「完成标志」后才进下一步。

<HARD-RULE>
insight 的价值在于改进建议指向具体阶段的具体改进。
「下次注意质量」不是有效建议。「下次 plan 阶段的 chunk 预算从 150 调到 100」是有效建议。
</HARD-RULE>

## 输入

| 字段 | 来源 | 必需 | 校验 |
|------|------|------|------|
| quality handoff | quality 阶段 | 有则读 | `{sprint}/handoffs/quality.md` |
| review handoff | review 阶段 | 有则读 | `{sprint}/handoffs/review.md` |
| execute observations | execute 阶段 | 有则读 | `{sprint}/execute/observations.md` |
| DB 指标 | sprint_chunks + sprint_gates | 有则查 | -- |
| sprint ID | entry.md | 是 | DB 中 running |

## 输出

| 产出 | 路径 | 消费方 | 聚焦内容 |
|------|------|--------|---------|
| 交接 | `{sprint}/handoffs/insight.md` | 下次 sprint 参考 | 改进建议（可操作） |
| 摘要 | `{sprint}/reports/insight.md` | 人看 | 指标 + 返工分析 + 根因 + 建议 |

## 步骤

### Step 1: 指标汇总

**做什么**: 聚合执行数据
**怎么做**: 查 DB sprint_chunks 和 sprint_gates 表
- chunk 数（完成/跳过/失败）
- 总 diff
- gate 统计（PASS/WARN/FAIL）
- 阶段耗时

**完成标志**: 指标表输出

### Step 2: 预估 vs 实际

**做什么**: 对比 plan 的预估和实际结果
**怎么做**: 读 quality handoff 的偏差分析 + DB 数据
- 每个 chunk: 预算 diff vs 实际 diff
- 总工作量: 预估 chunk 数 vs 实际（含重试）
- 风险: 预见的 vs 实际发生的

**完成标志**: 偏差表完成

### Step 3: 返工分析

**做什么**: 找出哪里返工了、为什么
**怎么做**:
- 查 DB sprint_gates 找 FAIL 记录（哪些 chunk 重跑了）
- 查 DB sprint_errors 找失败点
- 查 sprint_events 找 rollback/pivot 事件
- 每个返工点追溯根因：是 plan 拆分不对？design 遗漏？执行偏差？

**完成标志**: 返工点列表 + 每个有根因（指向具体阶段）

### Step 4: 改进建议

**做什么**: 基于根因给出可操作的改进
**怎么做**:
- 每个根因对应一条改进建议
- 建议格式：「下次 {阶段} 阶段 {做什么具体的事}」
- 不接受泛泛的「提高质量」「多注意」

**完成标志**: >= 1 条改进建议指向具体阶段 + 具体动作

### Step 5: Observations 处理

**做什么**: 展示 scope 外发现，讨论后续处理
**怎么做**: 读 `{sprint}/execute/observations.md`，逐条问用户：
- 创建新 sprint？
- 记录到项目知识库？
- 忽略？

**完成标志**: observations 每条有处置

### Step 6: 写两份产出 + 完成后操作 [GATE:must]

**交接文件** `{sprint}/handoffs/insight.md`:
```markdown
# Insight -- {主题}

## 改进建议
| 阶段 | 建议 | 根因 |
|------|------|------|

## Observations 处置
| 发现 | 处置 |
|------|------|
```

**摘要文件** `{sprint}/reports/insight.md`:
```markdown
# Insight -- {主题}
> 状态: [ok]

## 指标
{chunk/diff/gate 统计}

## 偏差
{预估 vs 实际}

## 返工
{返工点 + 根因}

## 改进
{具体建议}

## Observations
{处置结果}
```

写完后问用户：
- A. 合并到 main / 创建 PR
- B. 保留分支，稍后处理
- C. 其他

**完成标志**: 两份文件存在 + 用户选择了后续操作

## 提前终止

| 条件 | 行为 |
|------|------|
| 无 DB 指标（sprint 中途终止） | 跳过 Step 1-3，只做 Step 4-6 |
| 用户说「直接结束」 | 跳到 Step 6 |

## 验证清单

- [ ] 两份文件存在 + reports 状态 `[ok]`
- [ ] 预估 vs 实际有偏差表
- [ ] 返工点有根因（指向具体阶段）
- [ ] 改进建议 >= 1 条指向具体阶段 + 具体动作
- [ ] observations 每条有处置
- [ ] [人工] 用户选择了后续操作

## 排查指南

**1. 无返工数据**
症状: sprint 一切顺利没有 FAIL/rollback
处理: 不是问题。改进建议可以聚焦「哪里可以更高效」而非「哪里出了错」

**2. 用户对改进建议不认同**
症状: Step 6 用户否定建议
处理: 记录用户理由，不强推。用户有 AI 不知道的上下文
