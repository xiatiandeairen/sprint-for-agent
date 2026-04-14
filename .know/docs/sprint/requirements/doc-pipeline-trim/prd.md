# 文档任务流水线精简

## 1. 问题

文档类任务（写 PRD、tech spec、更新文档）走完整 sprint 流水线时，plan 和 quality 阶段产出低价值。plan 拆分的结果永远是"1 个文档 + 1 个索引更新"，quality 检查的内容只是"文件存在"。每次文档任务浪费 2 个阶段 + 2 轮确认。

在 v1 的 M3/M4 实施过程中，4 个 PRD/tech 文档 sprint 均出现此问题。

## 2. 目标用户

使用 sprint 驱动文档编写的开发者。当前替代方案是手动跳过确认（说 continue），但 plan 和 quality 阶段仍然会执行和输出，增加不必要的交互轮次。

## 3. 核心假设

**在 Input Normalization 中识别文档类任务并自动跳过 plan + quality → 文档任务减少 2 个阶段和 2 轮确认，且不丢失必要的质量保障。**

验证方式：文档类描述触发精简流水线（无 plan/quality）；代码类描述不受影响。

## 4. 方案

- **Before**: `/sprint 写 M4 PRD` → evaluate → brainstorm → plan（拆"1 PRD + 1 索引"）→ execute → quality（检查文件存在）→ insight — 6 个阶段
- **After**: `/sprint 写 M4 PRD` → evaluate 识别文档任务 → brainstorm → execute → insight — 3 个阶段

### 识别关键词

`prd`、`tech`、`文档`、`doc`、`docs`、`roadmap`、`更新索引`、`write doc`、`写文档`

### 精简规则

- plan → 跳过（文档拆分显而易见）
- quality → 跳过（execute 内验证文件存在）
- anchor → 不生成（plan 跳过）
- brainstorm/design/review → 正常由 evaluate 3 个问题决定

### 任务

| 任务 | 文档 | 进度 |
|------|------|------|
| 流水线精简实现 | — | 1/1 |

## 5. 验收标准

- 描述包含文档关键词时，evaluate 输出"类型: 文档任务"，流水线不含 plan 和 quality
- 描述不含文档关键词时，流水线与之前完全一致
- 文档任务的 sprint 不生成 anchors.txt
- 代码类任务的回归测试通过（test-sprint-ctl.sh、test-anchor-check.sh）

## 6. 排除项

- 通用任务类型感知裁剪（只处理文档类）
- 文档模板/脚手架工具
- stage 文件内部逻辑变更
