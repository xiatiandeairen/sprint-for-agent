---
name: execute
description: 可控执行。每步有门禁，每步能回退
---

# Execute

核心价值：**可控执行** — 不是一口气写完再检查，而是每个 chunk 完成后自动验证，发现问题立即停下。阻止质量衰减和不可回退。

> 本文件是执行指令。必须按「步骤」段逐步执行，每步验证「完成标志」后才进下一步。

<HARD-RULE>
每个 chunk 完成后必须用 Bash 工具执行 gate.sh，不是口头说通过。
gate FAIL 时不继续下一个 chunk。
scope 外发现记录到 observations，不在当前 sprint 执行。
</HARD-RULE>

## 输入

| 字段 | 来源 | 必需 | 校验 |
|------|------|------|------|
| plan anchor | plan 阶段 | 是 | `{sprint}/anchors/plan.md` 存在 |
| plan chunks | plan 阶段 | 是 | `{sprint}/handoffs/plan-chunks.md` 存在 |
| sprint ID | entry.md | 是 | DB 中 running |

## 输出

| 产出 | 路径 | 消费方 | 聚焦内容 |
|------|------|--------|---------|
| 交接 | `{sprint}/execute/observations.md` | insight 消费 | scope 外发现 |
| 指标 | DB sprint_chunks + sprint_gates | quality/insight | chunk 级指标 + gate 详情 |

## 步骤（每个 Chunk 循环）

### Step 1: Re-anchor

**做什么**: 重新读 anchor + chunks，获取当前 chunk
**怎么做**: 读 `{sprint}/anchors/plan.md` + `{sprint}/handoffs/plan-chunks.md`
**完成标志**: 当前 chunk 的描述、预算、验证方式已明确

### Step 2: 实现

**做什么**: 写代码
**怎么做**: 按 chunk 描述实现，遵守 anchor boundaries
- scope 外发现 -> 追加 `{sprint}/execute/observations.md`
**完成标志**: 代码写完，可编译

### Step 3: Gate [用 Bash 执行]

**做什么**: 跑质量门禁
**怎么做**:
```bash
bash "$SPRINT_PLUGIN/scripts/gate.sh" "{anchor_path}" {chunk_num}
```
**完成标志**: gate JSON 输出，返回码已知

### Step 4: 处理 Gate 结果 [BRANCH]

**做什么**: 根据 gate 结果决定下一步

| 条件 | 路径 |
|------|------|
| gate 返回码 0 (PASS) | → 继续下一步 |
| gate 返回码 2 (WARN) 且本 sprint WARN 累计 < 3 | → [INFO:warn] 输出警告，继续 |
| gate 返回码 2 (WARN) 且累计 >= 3 | → [STOP:confirm] 等用户介入 |
| gate 返回码 1 (FAIL) 且 auto 模式 | → [RETRY:1] revert 当前变更后重试，再 FAIL → [STOP:confirm] |
| gate 返回码 1 (FAIL) 且 checked 模式 | → [STOP:confirm] 暂停等修复 |

**完成标志**: PASS/WARN 继续，FAIL 已处理

### Step 5: 人审查 [BRANCH]

**做什么**: 呈现 chunk 摘要，等用户决定

| 条件 | 路径 |
|------|------|
| review=none | → [SKIP: review=none] |
| review=sampled 且非采样点 | → [SKIP: 非采样点] |
| review=sampled 且采样点（首 + 每 3-4 个 + 末尾） | → [STOP:choose] 输出变更概要 + gate 结果，用户选 [ok] / [调整] / [回退] |
| review=every | → [STOP:choose] 输出变更概要 + gate 结果，用户选 [ok] / [调整] / [回退] |

**完成标志**: 跳过/用户选择完成

### Step 6: Commit

**做什么**: 提交代码 + 记录指标
**怎么做**: git commit + 通过 DB 记录 chunk 指标
**完成标志**: commit 存在 + DB 中 chunk 记录更新

## 提前终止

| 条件 | 行为 |
|------|------|
| 全部 chunk 完成 | 进 quality |
| 用户说「够了」 | 标记剩余 skipped，进 quality |

## 验证清单 [CHECKLIST]

- [ ] 所有 chunk 完成（或标记 skipped）
- [ ] 每个 completed chunk 在 DB 有 gate 记录且 overall != FAIL
- [ ] observations 已记录（或无 scope 外发现）
- [ ] [人工] checked 模式下用户审查过

## 排查指南

**1. 门禁 FAIL**
症状: gate.sh 返回码 1
确认: 查 DB sprint_gate_items 看哪个 G 项失败
处理: checked 等修复重跑；auto revert + 重试

**2. diff 持续超预算**
症状: 连续 chunk 的 diff > budget
确认: 查 DB sprint_chunks.diff_lines vs budget
处理: pivot 重拆剩余 chunk
