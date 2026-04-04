---
name: brainstorm
description: 需求脑爆。多视角发散分析，方案对比，输出方向决策 + 排除项
---

# Sprint Brainstorm

## 输入

用户提供任务描述。如有 $ARGUMENTS 则为描述。

## 步骤

1. **读取相关代码**（按需，不全量扫描）
2. **Dispatch brainstormer subagent**：
   - 读取 `src/plugins/sprint/prompts/brainstormer.md`
   - 替换：TASK_DESCRIPTION, CODE_CONTEXT
   - Model: sonnet
3. **产出**：写入 `.sprint/brainstorm.md`
4. **呈现给用户**：
   - 展示方案对比 + 推荐
   - 等待用户确认方向：✅ 采纳推荐 / 🔄 选其他方案 / 💡 补充需求
   - 用户确认后在 brainstorm.md 中标注已确认方案

## 产出文件

`.sprint/brainstorm.md`（gitignore，过程产物）：
- 需求重述
- 多视角分析（用户体验 / 维护者 / 架构 / 性能）
- 方案对比表
- 推荐方案 + 理由
- 明确排除项
