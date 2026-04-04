---
name: design
description: 架构设计。文件结构 + 接口契约 + 依赖方向 + 结构性约束，前置结构决策
---

# Sprint Design

## 输入

`.sprint/brainstorm.md` 中已确认的方案。如果没有 brainstorm.md，提示先跑 `sprint:brainstorm`。

## 步骤

1. **读取 brainstorm.md** 获取确认方案 + 排除项
2. **读取相关源码**（基于 brainstorm 确认方案涉及的模块）
3. **Dispatch designer subagent**：
   - 读取 `src/plugins/sprint/prompts/designer.md`
   - 替换：CONFIRMED_APPROACH, EXCLUSIONS, CODE_CONTEXT
   - Model: sonnet（默认）/ opus（跨 3+ 模块的架构设计）
4. **产出**：写入 `.sprint/design.md`
5. **呈现给用户**：
   - 展示文件结构 + 接口契约 + 依赖方向
   - 重点标注结构性约束（会成为 Anchor Invariants）
   - 等待用户确认：✅ 通过 / 🔄 调整

## 产出文件

`.sprint/design.md`（gitignore，过程产物）：
- 文件结构（新建/修改/不碰）
- 接口契约（public API 签名）
- 依赖方向图
- 结构性约束（每条带检查命令）
- 测试策略

## 关键价值

Design 把结构性决策前置，不留给 implementer 在执行时 improvise。
Design 的产出直接驱动 Plan 阶段：

```
design.文件结构.不碰   → anchor.Boundaries
design.排除项         → anchor.不做的事
design.结构性约束     → anchor.Invariants
design.文件结构       → chunks.文件边界
design.测试策略       → chunks.完成标准 + 审查级别
```
