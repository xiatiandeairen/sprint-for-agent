---
name: plan
description: 创建 Intent Anchor + Chunk Plan。从 design.md 推导不变量和分块，或直接从描述创建
---

# Sprint Plan

## 输入

`.sprint/design.md`（如果有）。也可带描述直接创建（跳过 brainstorm + design）。

## 通用规则

- 不预加载项目上下文，按需读取
- Invariants 每条必须有可执行的 shell 检查命令 + 预期结果
- 禁止散文式不变量

## 步骤

1. **读取 design.md**（如果有）或读取相关源码

2. **生成 Intent Anchor**（从 design.md 自动推导）：
   - 读取模板 `src/plugins/sprint/templates/anchor.md`
   - 写入 `docs/versions/{当前版本}/anchor.md`
   - 自动填写 Baselines：执行每条 baseline 命令获取当前值

3. **生成 Chunk Plan**：
   - 读取模板 `src/plugins/sprint/templates/chunks.md`
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
bash "src/plugins/sprint/scripts/sprint-ctl.sh" init "{anchor_path}" "{chunks_path}" "{mode}"
bash "src/plugins/sprint/scripts/sprint-ctl.sh" set-baseline test_count {N}
bash "src/plugins/sprint/scripts/sprint-ctl.sh" set-baseline todo_count {N}
```

5. **询问执行模式**：
   - `sprint:go` — 带人工检查（推荐用于高风险任务）
   - `sprint:auto` — 自动执行（适用于确定性高的任务）
