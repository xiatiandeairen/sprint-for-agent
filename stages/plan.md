---
name: plan
description: 锚定边界 + 暴露风险。转化为可执行序列，让用户在动手前知道哪里可能出问题
---

# Plan

核心价值：**锚定边界 + 暴露风险** — 把 design 的设计转化为可执行的 chunk 序列 + 可机器检查的 invariants + 显式的风险清单。阻止 execute 阶段 scope 漂移和风险意外爆发。

> 本文件是执行指令。必须按「步骤」段逐步执行，每步验证「完成标志」后才进下一步。

<HARD-RULE>
plan 的价值在于两件事：
1. execute 阶段的 gate 能直接用 anchor 的 invariants 做检查，不需要人工解读
2. 用户看完 plan 能回答「最可能出问题的地方在哪」
</HARD-RULE>

## 输入

| 字段 | 来源 | 必需 | 校验 |
|------|------|------|------|
| design handoff | design 阶段 | medium/complex 必需 | `{sprint}/handoffs/design.md` 存在 |
| design anchor | design 阶段 | medium/complex 必需 | `{sprint}/anchors/design.md` 存在 |
| 任务描述 | 用户输入 | simple 必需 | 非空 |
| sprint ID | entry.md | 是 | DB 中存在 |

## 输出

| 产出 | 路径 | 消费方 | 聚焦内容 |
|------|------|--------|---------|
| 约束 | `{sprint}/anchors/plan.md` | execute/quality 全程对照 | Intent Anchor（invariants + boundaries + baselines + 风险 + 假设） |
| 交接 | `{sprint}/handoffs/plan-chunks.md` | execute 逐 chunk 消费 | Chunk Plan（描述 + 预算 + 验证方式） |
| 摘要 | `{sprint}/reports/plan.md` | 人确认 | 执行计划概要 + 风险清单 |

## 步骤

### Step 1: 提取约束

**做什么**: 从上游产出收集 anchor 素材
**怎么做**:
- 读 design handoff：文件结构 -> chunk 边界，结构性约束 -> invariants
- 读 design anchor：不碰列表 -> boundaries，接口契约 -> invariants
- 读 brainstorm anchor（如有）：排除项 -> boundaries
- 读 research anchor（如有）：淘汰方案 -> 禁止方向
**完成标志**: 素材清单完成，每条 invariant 有对应的检查命令

### Step 2: 写 Intent Anchor

**做什么**: 生成 `{sprint}/anchors/plan.md`
**怎么做**: 按模板填充：

```markdown
# Intent Anchor -- {主题}

## Goal
{一句话目标}

## Invariants
| # | 描述 | 检查命令 | 预期 |
|---|------|---------|------|
| 1 | {描述} | `{命令}` | {预期} |

## Boundaries
### 不碰
- {目录/文件}
### 不做
- {排除项}
### 不引入
- {禁止的依赖方向}

## Baselines
| 指标 | 值 | 命令 |
|------|-----|------|

## Assumptions
- [ ] {待确认假设}

## Risks
### 风险 1: {标题}
可能性: 高/中/低
影响: {出了问题会怎样}
应对: {怎么预防或补救}
触发信号: {怎么发现它发生了}
```

**完成标志**: 文件存在 + invariants 每条有检查命令 + 风险 >= 1 条

### Step 3: 拆 Chunk

**做什么**: 生成 `{sprint}/handoffs/plan-chunks.md`
**怎么做**:
- 每个 chunk 独立可编译可测试
- 每个 chunk diff <= 预算
- chunk 间线性依赖
- 每个 chunk 标注验证方式

**完成标志**: 文件存在 + chunk >= 1 + 每个 chunk 有预算和验证方式

### Step 4: 记录基线

**做什么**: 执行基线命令记录当前值
**怎么做**:
```bash
bash "$SPRINT_PLUGIN/scripts/sprint-ctl.sh" set-baseline "{sprint-id}" test_count {N}
bash "$SPRINT_PLUGIN/scripts/sprint-ctl.sh" set-baseline "{sprint-id}" todo_count {N}
```
**完成标志**: 命令执行成功（失败则用默认值 0 + 记录警告）

### Step 5: 写摘要

**做什么**: 生成 `{sprint}/reports/plan.md`
**怎么做**:
```markdown
# Plan -- {主题}
> 状态: [ok]

## 执行计划
{N} 个 chunk，总预算 {M} 行

## 风险清单
| 风险 | 可能性 | 影响 | 应对 |
|------|--------|------|------|

## Assumptions
- [ ] {待确认}
```

**完成标志**: 文件存在

### Step 6: 用户确认 [GATE:must]

**做什么**: 呈现 anchor + chunks + 风险，用户确认
**怎么做**:
- 展示风险清单，问用户是否接受
- 展示 Assumptions，用户逐条确认（`[ ]` -> `[x]`）
- 展示 chunk 概要

**完成标志**: 用户确认 + Assumptions 全部 `[x]` + 风险已评估

## 提前终止

| 条件 | 行为 |
|------|------|
| design 约束过于模糊 | 回退 design 补充 |
| 任务只需 1 个 chunk | 正常继续 |

## 验证清单

- [ ] `{sprint}/anchors/plan.md` 存在 + invariants 每条有检查命令
- [ ] `{sprint}/handoffs/plan-chunks.md` 存在 + chunk >= 1
- [ ] `{sprint}/reports/plan.md` 存在 + `[ok]`
- [ ] 风险清单 >= 1 条
- [ ] Assumptions 全部 `[x]`
- [ ] 基线已记录
- [ ] [人工] 用户确认

## 排查指南

**1. chunk 粒度不对**
症状: execute 阶段 diff 持续超预算
处理: pivot 重拆

**2. 风险未识别**
症状: execute 阶段出现 plan 没预见的问题
处理: 下次 plan 增加风险分析维度
