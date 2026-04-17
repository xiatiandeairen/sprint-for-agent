# design 任务边界提示

<!-- 核心问题: 需求到哪了、验收标准是什么？
     定位: 需求级进度跟踪
     不属于本文档: 产品全局规划（→ roadmap）、技术方案（→ tech）、系统架构（→ arch） -->

## 1. 问题

design 产出 File Structure（哪些文件 create/modify/do-not-touch），但不提示"哪些文件适合合成一个任务"。plan 阶段拿到 handoff 后要重新思考任务边界——这是重复工作，design 阶段更接近决策现场，对边界判断更准。用户在 design+plan 都运行的 sprint 中会经历两次任务切分讨论（一次隐式在 design 的 File Structure，一次显式在 plan 的 Split Tasks）。

## 2. 目标用户

design 和 plan 都运行的 sprint 用户。期望任务边界在 design 阶段就得到建议，plan 拆分时可以直接采纳或调整。

## 3. 核心假设

**design Step 2 在 File Structure 之后增加"建议任务边界"子 section，按独立验证原则给出初步切分建议 → plan Split Tasks 步骤在多数情况下可直接采纳 design 建议，减少重复决策。**

验证方式：跑 3 个中等复杂度 sprint（5-10 个文件），对比 design 建议边界和 plan 最终切分的一致率，≥70% 视为成功。

## 4. 方案

- **Before**: design handoff 只列 File Structure，plan Step 4 从零思考任务边界 → **After**: design handoff 多一个"Suggested Task Boundaries"段，plan Step 4 先采纳建议再调整

### 任务边界建议格式

| 字段 | 内容 |
|------|------|
| 任务名 | 动词+名词 |
| 包含文件 | 引用 File Structure 中的路径 |
| 独立性依据 | 为什么可独立验证 |

### 任务

| 任务 | 文档 | 进度 |
|------|------|------|
| design 任务边界提示 | [tech](impl/tech.md) | 0/0 |

## 5. 验收标准

- design Step 2 完成 → handoff 中包含 Suggested Task Boundaries 段，列出 ≥1 个建议任务
- plan Step 4 开始 → 读取 design 的 Suggested Task Boundaries 作为初始方案
- 用户接受 design 建议 → plan 直接生成对应任务，无需二次讨论
- 用户调整建议 → plan 弹出差异对比，用户选择最终切分
- design 被跳过 → plan Step 4 按原逻辑从零拆分

## 6. 排除项

- 强制 plan 采用 design 建议（只是建议，plan 有权覆盖）
- 任务级依赖图（只给边界，不建模依赖）
- 并行/顺序执行策略建议（归属 plan Step 5）
