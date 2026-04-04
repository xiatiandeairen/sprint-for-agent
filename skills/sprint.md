---
name: sprint
description: 完整链路长时任务引擎。/sprint 默认走 brainstorm→design→plan→execute 全流程
disable-model-invocation: true
---

# Sprint — 长时任务执行引擎

Brainstorm → Design → Plan → Execute 完整链路。
Intent Anchor + Chunk Gate + Decision Review 三层防线。

## 命令路由

根据 `$ARGUMENTS` 分发：

| 参数 | 命令 | 说明 |
|------|------|------|
| `<描述>` | /sprint | **默认完整链路**：brainstorm → design → plan → go |
| `brainstorm <描述>` | /sprint brainstorm | 只做脑爆 |
| `design` | /sprint design | 只做设计（基于脑爆产出） |
| `plan` | /sprint plan | 只做 anchor + chunks（基于设计产出） |
| `go` | /sprint go | 带人工检查执行 |
| `auto` | /sprint auto | 自动执行（门禁兜底，失败停止） |
| `status` | /sprint status | 当前进度 + 指标 |
| `check` | /sprint check | 手动跑一次门禁 |
| `pivot` | /sprint pivot | 中途修改计划 |
| `end` | /sprint end | 结束 sprint |

**默认行为**：`/sprint <描述>` 走完整链路，每个阶段结束暂停确认后自动进入下一阶段。

---

## 通用规则

1. **不预加载项目上下文**。按需读取 anchor/chunks/state 文件。
2. **所有 subagent 必须注入 Anchor Boundaries + Invariants**。读取 `${CLAUDE_PLUGIN_ROOT}/prompts/` 下的模板，填充后 dispatch。
3. **每个 chunk 开始前重新读取 anchor.md**（re-anchor，防 context 压缩丢失）。
4. **发现改进机会但不在 scope 内** → 追加到 `.sprint/observations.md`，不动手。
5. **禁止"先跳过后面处理"**。每个 chunk 独立达标。
6. **门禁失败时不继续下一个 chunk**。修复 → `/sprint check` → 通过后继续。

---

## /sprint brainstorm <描述>

### 输入
用户提供一句话任务描述。

### 步骤

1. **读取相关代码**（按需，不全量扫描）
2. **Dispatch brainstormer subagent**：
   - 读取 `${CLAUDE_PLUGIN_ROOT}/prompts/brainstormer.md`
   - 替换：TASK_DESCRIPTION, CODE_CONTEXT
   - Model: sonnet
3. **产出**：写入 `.sprint/brainstorm.md`
4. **呈现给用户**：
   - 展示方案对比 + 推荐
   - 等待用户确认方向：✅ 采纳推荐 / 🔄 选其他方案 / 💡 补充需求
   - 用户确认后在 brainstorm.md 中标注已确认方案

### 产出文件

`.sprint/brainstorm.md`（gitignore，过程产物）：
- 需求重述
- 多视角分析（用户体验 / 维护者 / 架构 / 性能）
- 方案对比表
- 推荐方案 + 理由
- 明确排除项

---

## /sprint design

### 输入
`.sprint/brainstorm.md` 中已确认的方案。如果没有 brainstorm.md，提示先跑 `/sprint brainstorm`。

### 步骤

1. **读取 brainstorm.md** 获取确认方案 + 排除项
2. **读取相关源码**（基于 brainstorm 确认方案涉及的模块）
3. **Dispatch designer subagent**：
   - 读取 `${CLAUDE_PLUGIN_ROOT}/prompts/designer.md`
   - 替换：CONFIRMED_APPROACH, EXCLUSIONS, CODE_CONTEXT
   - Model: sonnet（默认）/ opus（跨 3+ 模块的架构设计）
4. **产出**：写入 `.sprint/design.md`
5. **呈现给用户**：
   - 展示文件结构 + 接口契约 + 依赖方向
   - 重点标注结构性约束（会成为 Anchor Invariants）
   - 等待用户确认：✅ 通过 / 🔄 调整

### 产出文件

`.sprint/design.md`（gitignore，过程产物）：
- 文件结构（新建/修改/不碰）
- 接口契约（public API 签名）
- 依赖方向图
- 结构性约束（每条带检查命令）
- 测试策略

### 关键价值

Design 阶段把**结构性决策前置**。不留给 implementer 在执行时 improvise。
Design 的产出直接驱动 Plan 阶段：

```
design.文件结构.不碰   → anchor.Boundaries
design.排除项         → anchor.不做的事
design.结构性约束     → anchor.Invariants
design.文件结构       → chunks.文件边界
design.测试策略       → chunks.完成标准 + 审查级别
```

---

## /sprint plan

### 输入
`.sprint/design.md`。如果没有 design.md，提示先跑 `/sprint design`。
也可以直接 `/sprint plan <描述>` 跳过 brainstorm + design（适用于简单/明确的任务）。

### 步骤

1. **读取 design.md**（如果有）或读取相关源码

2. **生成 Intent Anchor**（从 design.md 自动推导）：
   - 读取模板 `${CLAUDE_PLUGIN_ROOT}/templates/anchor.md`
   - 写入 `docs/versions/{当前版本}/anchor.md`
   - **关键**：Invariants 每条必须有可执行的 shell 检查命令 + 预期结果
   - 自动填写 Baselines：执行每条 baseline 命令获取当前值

3. **生成 Chunk Plan**：
   - 读取模板 `${CLAUDE_PLUGIN_ROOT}/templates/chunks.md`
   - 写入 `docs/versions/{当前版本}/chunks.md`
   - 切割原则：**状态迁移**（不是文件/行数）
   - 每个 chunk 中间状态必须可编译、可测试
   - 标注审查节奏：🔴 深度（Chunk 1 + 每 3-4 个 + 最后）/ 🟡 快速
   - 标注需人工验证的 chunk

4. **呈现给用户确认**：
   - 展示 Anchor 全文，重点标注 Assumptions
   - 用户逐条确认 Assumptions（将 `[ ]` 改为 `[x]`）
   - 用户确认后执行初始化：

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/sprint-ctl.sh" init "{anchor_path}" "{chunks_path}" "{mode}"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/sprint-ctl.sh" set-baseline test_count {N}
bash "${CLAUDE_PLUGIN_ROOT}/scripts/sprint-ctl.sh" set-baseline todo_count {N}
```

5. **询问执行模式**：
   - `/sprint go` — 带人工检查（推荐用于高风险任务）
   - `/sprint auto` — 自动执行（适用于确定性高的任务）

---

## /sprint go

### 对每个 Chunk 循环

**Step 1: Re-anchor**
重新读取 anchor.md 和 chunks.md，获取当前 chunk 信息。

**Step 2: 推进 chunk**
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/sprint-ctl.sh" advance
```

**Step 3: Dispatch implementer**
- 读取 `${CLAUDE_PLUGIN_ROOT}/prompts/implementer.md`
- 替换模板变量：CHUNK_DESCRIPTION, ANCHOR_BOUNDARIES, ANCHOR_INVARIANTS, CHUNK_COMPLETION_CRITERIA
- Model 选择：sonnet（默认）/ opus（当 chunk 涉及跨 3+ 文件接口变更或架构判断时）
- 使用 Agent tool dispatch

**Step 4: 自动门禁**
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/gate.sh" "{anchor_path}" {chunk_number}
```
- FAIL → 停止。输出门禁报告，要求 implementer 修复。修复后重跑门禁。
- WARN → 输出警告，记录但继续。
- PASS → 继续。

**Step 5: Dispatch anchor-reviewer**
- 读取 `${CLAUDE_PLUGIN_ROOT}/prompts/anchor-reviewer.md`
- 替换：FULL_ANCHOR_CONTENT, IMPLEMENTER_REPORT
- Model: sonnet
- ❌ → implementer 修复 → re-review
- ✅ → 继续

**Step 6: 生成 Decision Summary**
格式（给人看的，不是给 AI 看的）：

```markdown
### Chunk {N} — {一句话}

**决策点**: {Y/N 问题列表，如果有。没有就写"无"}
**门禁**: {G1-G9 状态摘要}
**观察**: {implementer 报告的 observations}
**下一步**: {下一个 chunk 的预告}
```

**Step 7: 人审查**

根据 chunks.md 中标注的审查级别：

🔴 **深度审查**（Chunk 1 + 每 3-4 个 + 最后）：
- 展示 Decision Summary
- 展示当前代码状态快照（关键文件当前内容，不是 diff）
- 建议用户跑 app（`open src/mac/Loppy.xcworkspace`，⌘R）
- 等待用户选择：✅ 继续 / 🔄 调整 / ⏪ 回退

🟡 **快速审查**（其余）：
- 展示 Decision Summary（30 秒可读）
- 等待用户选择：✅ 继续 / 🔄 调整 / ⏪ 回退

**Step 8: Commit + 更新状态**
- 确保代码已 commit
- 更新 chunks.md 中当前 chunk 状态为 ✅

### 回退处理

如果用户选择 ⏪：
1. `git revert HEAD`
2. 更新 chunks.md 状态为 ❌
3. 讨论：重做 / 调整 / `/sprint pivot`

### 循环结束

所有 chunk 完成后：
1. 运行全量测试
2. 输出最终指标摘要（`sprint-ctl.sh status`）
3. 展示 `.sprint/observations.md`
4. 建议用户做最终 review
5. 执行 `sprint-ctl.sh end`

---

## /sprint auto

和 `/sprint go` 相同流程，以下区别：

1. **去掉 Step 7（人审查）**
2. **新增 quality-reviewer**：anchor-reviewer 通过后 dispatch
   - 读取 `${CLAUDE_PLUGIN_ROOT}/prompts/quality-reviewer.md`
   - Model: sonnet
   - NEEDS_CHANGES → implementer 修复 → re-review
3. **门禁更严**：
   - diff 预算 × 0.8
   - 连续 2 个 WARN → 停止等人
4. **失败自动处理**：
   - 门禁 FAIL → `git revert HEAD` → 重新 dispatch implementer（重试 1 次）
   - 重试 FAIL → 停止等人
5. **最终交付**：必须有人做 final review

---

## /sprint status

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/sprint-ctl.sh" status
```

展示结果。如果有衰减警告，一并展示：
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/chunk-metrics.sh" --decay-check
```

---

## /sprint check

手动运行门禁（修复后重新检查）：

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/gate.sh" "{anchor_path}" {chunk_number}
```

展示结构化门禁报告。如果 PASS，更新 state.json 的 last_gate。

---

## /sprint pivot

1. 暂停执行
2. 用户说明调整原因
3. AI 提出修改方案（对 anchor 和/或 chunks 的具体变更）
4. 用户确认
5. 更新 anchor.md 和/或 chunks.md
6. 如果 Invariants 变了 → 重新跑 baseline 命令更新 state.json
7. 如果 Assumptions 新增了 → 等用户确认后再继续
8. 从当前位置继续执行

---

## /sprint end

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/sprint-ctl.sh" end
```

展示：
- 最终指标摘要
- 观察日志（`.sprint/observations.md`）内容
- 建议后续处理的改进项

---

## 默认完整链路：/sprint <描述>

当用户直接 `/sprint <描述>` 时，按顺序执行全部阶段：

```
1. Brainstorm → 🧑 确认方向
2. Design     → 🧑 确认设计
3. Plan       → 🧑 确认假设 + 不变量
4. Go         → chunk 循环（每个 chunk 有门禁 + 审查）
5. End        → 最终指标 + 观察日志
```

每个阶段结束后暂停等用户确认。用户确认后自动进入下一阶段。
任何阶段用户可以说"停"，后续用对应子命令单独继续。

### 跳过阶段

- 简单明确的任务：`/sprint plan <描述>` 直接从 plan 开始
- 已经知道怎么做：`/sprint go` 直接从执行开始（需要已有 anchor + chunks）
- 只需要探索：`/sprint brainstorm <描述>` 只做脑爆不继续
