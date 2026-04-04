# Intent Anchor — {TASK_NAME}

> 创建时间: {TIMESTAMP}
> Sprint 模式: {MODE}

## Goal

{一句话：做什么 + 为什么做}

## Invariants

| # | 描述 | 检查命令 | 预期 |
|---|------|---------|------|
| 1 | {描述} | `{可执行命令}` | {= N / ≤ N / ≥ N / PASS / CONTAINS text} |

> 每条不变量必须有可执行的检查命令。散文式描述会被 anchor-verify.sh 忽略。
> 预期格式：= N（精确）| ≤ N（上限）| ≥ N（下限）| PASS（命令返回0）| CONTAINS text（输出包含）

## Boundaries

### 不触碰的模块/目录
- {path/to/forbidden/}

### 不做的事
- 不 {X}

### 不引入的依赖
- 不引入 {A} → {B} 的依赖

## Assumptions（需人确认后打勾）

- [ ] {AI 的假设，如：MetricsCollector 是线程安全的}

> pre-chunk hook 检查此列表。有未确认假设 → 阻塞执行。
> 人确认后将 [ ] 改为 [x]。

## Red Flags（出现即停）

- 任何 Chunk diff > {N} 行
- 触碰 Boundaries 中"不触碰"的模块
- 测试数量下降
- AI 使用"顺便""先跳过""后面再"等表述

## Baselines（plan 阶段自动填写）

| 指标 | 基线值 | 记录命令 |
|------|--------|---------|
| test_count | {N} | `{命令}` |
| todo_count | {N} | `grep -rE 'TODO\|TEMP\|HACK\|FIXME' src/ \| wc -l` |
| {自定义} | {N} | `{命令}` |
