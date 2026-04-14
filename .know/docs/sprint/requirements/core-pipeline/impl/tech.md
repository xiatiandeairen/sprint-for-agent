# 核心流水线 技术方案

<!-- 核心问题: 怎么实现、做到哪了？
     定位: 技术方案 + 实现进度跟踪（多次 sprint 迭代完善）
     不属于本文档: 产品需求（→ PRD）、系统架构（→ arch）、接口契约（→ schema） -->

## 1. 背景

<!-- 技术约束和前置依赖。回答"为什么要做这个方案"
  - 技术约束列表（影响方案选择的硬限制）、前置依赖（必须先完成的任务/模块）
  - EXCLUDE: 产品愿景、用户画像（→ PRD） -->

- M1 里程碑要求：3 个 skill 入口、7 个执行阶段、2 个 CLI 脚本、完整状态管理
- 技术约束：纯 bash + python3（JSON 处理），零外部依赖
- 前置依赖：无（M1 是第一个里程碑）

## 2. 方案

<!-- 高层技术设计，随 sprint 迭代更新。回答"怎么实现"
  - 文件/模块结构: 树形或表格，每项标注职责（1 句话）
  - 核心流程: 关键路径的步骤序列（A → B → C），不展开每步实现
  - 数据结构: 只列公开接口级的结构定义（字段名+类型+用途）
  - 突出关键点，细节在 sprint 中处理
  - EXCLUDE: 函数签名、算法伪代码、完整接口定义（→ schema） -->

### 文件结构

```
skills/sprint/SKILL.md          ← 主入口，evaluate + pipeline loop + 全局规则
skills/long-sprint/SKILL.md     ← 长任务编排
skills/todo/SKILL.md            ← 快速任务，4 种模式路由
stages/{brainstorm,design,plan,execute,quality,review,insight,long}.md ← 阶段定义
scripts/sprint-ctl.sh           ← 生命周期管理（create/activate/stage/end/evaluate/list）
scripts/anchor-check.sh         ← 锚点验证（7 种 anchor 类型）
```

### 核心流程

```
/sprint {description}
    → Input Normalization（解析描述，检测关键词）
    → Evaluate（3 个 yes/no → 裁剪阶段列表）
    → Pipeline Loop（逐阶段：读 stage file → 执行步骤 → 写 handoff）
    → sprint-ctl end（insight 关闭 sprint）
```

阶段链路：brainstorm → design → plan → execute → quality → review → insight。每阶段读取上游 handoff，产出自己的 handoff。跳过的阶段，下游使用用户原始描述。

### 数据结构

state.json：id, type, desc, stages[], status(created→running→completed), current_stage, base_commit, created_at

anchors.txt：每行一条断言（MUST_EXIST, MUST_BUILD, MUST_TEST, MUST_IMPORT, MUST_NOT_IMPORT, MUST_NOT_EXIST, FILE_NOT_MODIFIED）

metrics.log：追加写入，格式 `{timestamp}|{event}|{data}`

## 3. 关键决策

<!-- 技术选型及理由，每次 sprint 后积累。回答"为什么这样做"
  - 每行 1 个技术选型点，"为什么"包含被拒方案及拒绝原因（1 句话）
  - EXCLUDE: 产品方向决策 -->

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 状态管理 | JSON 文件 + metrics.log | 零依赖，git 可追溯；拒绝 SQLite（增加依赖） |
| 阶段裁剪 | 3 个 yes/no 问题 | 简单直观；拒绝评分模型（AI 打分不稳定） |
| Anchor 机制 | 文本文件 + bash 脚本 | 可读可扩展；拒绝语言特定工具链（限制通用性） |
| Handoff 格式 | Markdown | 人可读 AI 可解析；拒绝 JSON（可读性差） |
| 脚本语言 | Bash + python3 | 跨平台零安装；拒绝 Node.js（额外依赖） |
| Model 选择粒度 | 步骤级 | 同阶段不同复杂度；拒绝阶段级（粒度太粗） |
| Execute 模式 | 双模式（step-by-step / parallel） | 覆盖有依赖和无依赖两种场景 |

## 4. 迭代记录

<!-- 每次 sprint 实现了什么，新增在前。回答"做到哪了"
  - 每条: sprint 日期 + 做了什么 + 关键变更
  - 追踪实现进度，体现渐进完善过程 -->

### 2026-04-10

M1 完成。实现了 3 个 skill 入口（sprint/long-sprint/todo）、7 个阶段文件、sprint-ctl.sh（6 个子命令）、anchor-check.sh（7 种断言类型）。端到端可用。
