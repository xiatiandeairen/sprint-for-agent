---
name: sprint
description: Use when task spans multiple files or modules, involves architectural decisions, or has unclear requirements needing brainstorming. Also use when user explicitly says /sprint or describes a large initiative.
---

# Sprint Skill

任务执行引擎。按任务复杂度路由到合适的执行流水线。

**文档约定**：
- `> [标签] ...` — 输出给用户。标签：`[评估]` `[启动]` `[完成]` `[警告]`
- ` ```bash` 块中含 `# [RUN]` — 必须用 Bash 工具真正执行
- `[TASK] xxx` — 必须调用 TaskCreate

---

## 1. 参数解析

- **无参数** → 列出所有 sprint：
  ```bash
  # [RUN]
  bash scripts/sprint-ctl.sh list
  ```

- **`simple`/`medium`/`complex`/`long` + 描述** → 跳过评估，直接使用指定类型，进入创建流程。

- **Sprint ID**（格式 `YYYYMMDD-HHMMSS-NNN`）→ 恢复已有 sprint：
  ```bash
  # [RUN]
  bash scripts/sprint-ctl.sh activate {id}
  ```
  然后直接进入 Pipeline Executor，从未完成的阶段继续。

- **其他描述** → 进入评估流程（见第 2 节）。

---

## 2. 评估

三个维度（各 low/high）：
- **信息密度**：需要理解/收集的上下文量
- **决策密度**：有多少方案选择点
- **不确定性**：需求是否模糊

七个阶段，按需选用：

| 阶段 | 何时需要 |
|------|---------|
| brainstorm | 不确定性高，需求模糊 |
| design | 决策密度高，存在多条可行路径 |
| plan | 信息密度中等以上，多文件多依赖 |
| execute | 有产出物 |
| quality | 改动影响范围广 |
| review | 复杂逻辑或架构决策 |
| insight | 始终包含 |

类型判断：

| 类型 | 条件 | 流水线 |
|------|------|--------|
| skip sprint | 一步完成，三维皆低 | 直接执行，不建 sprint |
| simple | 需要 plan + execute | plan → execute → [quality] → insight |
| medium | 需要 design | [design] → plan → execute → [quality] → insight |
| complex | 需要 brainstorm | brainstorm → design → plan → execute → quality → review → insight |
| long | 方向性探索 | 见 brainstorm 说明 |

括号 `[]` = 按评估可跳过。

输出格式，等待用户确认：
```
> [评估] {任务描述}
> 类型: medium
> 流水线: design → plan → execute → quality → insight
> 跳过: brainstorm, review
```

用户确认后，创建并激活 sprint：
```bash
# [RUN]
bash scripts/sprint-ctl.sh create {type} "{desc}" "{stage1,stage2,...}"
bash scripts/sprint-ctl.sh activate {id}
```

> [启动] Sprint #{id} | 类型: {type} | 流水线: {stages}

---

## 3. 阶段定义

### brainstorm（想法）

纯对话，**禁止读代码或文档**。每次只问一个问题，多轮对齐。

目标：明确范围和成功标准。

Handoff（写入对话，不写文件）：
- **结论**：一句话描述要做什么
- **Scope In / Scope Out / 成功标准**
- **产出物**：预期交付列表

long 模式：任务是方向性探索，在 brainstorm 充分对齐方向和边界后，再决定是否进入后续阶段。

---

### design（方案）

**Step 1 — Research**：调研行业方案 + 当前代码状态 + insight 报告。可用 subagent 并行调研多个方向。

**Step 2 — Modeling**：
- UI 需求 → 产品模型 + UI 设计
- 逻辑需求 → 需求模型 + 接口设计
- 架构需求 → 架构图 + 组件职责

优先使用图表/表格，避免大段文字。

输出：`handoffs/design.md`

---

### plan（细节）

读取 `handoffs/design.md`（如有）。

将任务拆解为 Task（TDD 节奏：写测试 → 运行失败 → 实现 → 运行通过 → commit）。

每个 Task 包含：标题、文件列表（create/modify/delete）、步骤（含实际代码）。

确定执行模式：
- **step-by-step**：task = chunk，串行，当前 session 执行
- **subagent-driven**：task → chunks，独立 chunk 并行，每个 chunk 指定模型

输出：
- `handoffs/plan.md`（含 `## Expected Files` 节，列出预期变更文件）
- `.sprint/{id}/anchors.txt`（写入约束断言）

---

### execute（执行）

读取 `handoffs/plan.md` + `.sprint/{id}/anchors.txt`。

**Mode A（step-by-step）**：当前 session 串行执行每个 Task，每个 Task 完成后运行 anchor-check：
```bash
# [RUN]
bash scripts/anchor-check.sh {id}
```

**Mode B（subagent-driven）**：按 chunk 分发 subagent，独立 chunk 并行，每个 Task 完成后运行 anchor-check。

输出：`handoffs/execute.md`（完成 task 列表、变更文件、anchor 结果、quality 测试范围）。

---

### quality（验证）

纯工具验证。读取 `handoffs/execute.md` 获取测试范围。运行 swift build、swift test、anchor-check。

通过则继续。失败则回到 execute 修复。

---

### review（复审）

读取 `handoffs/execute.md` + `git diff {base_commit}`。

输出 `handoffs/review.md`：
- **自用**：摘要、关键决策（为何选 A 而非 B）、踩坑点
- **团队**：变更表（文件|类型|描述）、代码讲解（按逻辑顺序，聚焦"为什么"）

简单任务可跳过。

---

### insight（沉淀）

```bash
# [RUN]
bash scripts/sprint-ctl.sh end {id}
```

逐阶段一句话评价：是否必要，下次保留还是跳过。直接打印给用户，无文件输出。

---

## 4. Pipeline Executor

对流水线中每个阶段依次执行：

1. [TASK] {stage} — 创建追踪任务
2. 标记阶段开始：
   ```bash
   # [RUN]
   bash scripts/sprint-ctl.sh stage {id} {stage} running
   ```
3. 执行上方对应阶段的规则
4. 写入 handoff 文件（如适用）
5. 标记阶段完成：
   ```bash
   # [RUN]
   bash scripts/sprint-ctl.sh stage {id} {stage} completed
   ```
6. 标记任务完成

所有阶段完成后：
```bash
# [RUN]
bash scripts/sprint-ctl.sh end {id}
```

> [完成] Sprint #{id} 已完成。
