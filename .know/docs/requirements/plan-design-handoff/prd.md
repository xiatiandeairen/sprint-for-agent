# plan-design 衔接清理

<!-- 核心问题: 需求到哪了、验收标准是什么？
     定位: 需求级进度跟踪
     不属于本文档: 产品全局规划（→ roadmap）、技术方案（→ tech）、系统架构（→ arch） -->

## 1. 问题

plan 阶段的 Spec Preferences（Q1 scope / Q2 depth / Q3 transition / Q4 compatibility）本质是设计决策。当 design 阶段存在时，这些决策已经在 design 中确定（Solution Approach + Decision Register），plan 再问一次是冗余交互，用户需要重复回答。同时当 design 被跳过时，plan Q1-Q4 作为 fallback 兜底，但这个"兜底"角色在文档中是隐式的，用户不知道此时 plan 在做 design 的职责。所有 design + plan 都运行的 sprint 用户（估算占 60% 以上）都面临重复提问。

## 2. 目标用户

design 和 plan 都触发的 sprint 用户。期望决策只在该决策的阶段做一次，下游直接继承。

## 3. 核心假设

**plan Step 1 检测 design handoff 中对应决策，已有则直接继承、跳过 Q1-Q4；design 被跳过时显式标注"plan 承担 fallback 职责" → 用户不再被重复问同一决策，同时知道决策在哪个阶段产生。**

验证方式：
1. 跑一个 design + plan 都开启的 sprint，plan Step 1 应自动跳过（或以确认模式呈现 design 已确定的值），不产生新提问
2. 跑一个 design 跳过的 sprint，plan Step 1 输出应包含"design 跳过，以下 Q1-Q4 作为 fallback 兜底"标记

## 4. 方案

- **Before**: design 确定 scope=precise 后 plan 再次问 Q1 scope → **After**: plan 读 design handoff 的 Decision Register，已有决策直接继承，可选确认
- **Before**: design 被跳过时 plan 的 Q1-Q4 看起来和普通步骤一样 → **After**: plan Step 1 头部显示"design 阶段跳过，此步承担 fallback 设计决策"

### 决策映射

| plan 字段 | design handoff 来源 |
|----------|-------------------|
| Q1 scope | Decision Register 中 scope 相关 core 条目 |
| Q2 depth | Decision Register 中 depth 相关 core 条目 |
| Q3 transition | Solution Approach 中过渡策略 |
| Q4 compatibility | Decision Register 中兼容性相关 core 条目 |

### 任务

| 任务 | 文档 | 进度 |
|------|------|------|
| plan-design 衔接 | [tech](impl/tech.md) | 0/0 |

## 5. 验收标准

- design + plan 都运行 → plan Step 1 自动继承 design 决策，Q1-Q4 不再弹出
- design 跳过 → plan Step 1 头部显示"fallback 模式"标记，Q1-Q4 按原逻辑弹出
- design 部分决策缺失 → plan 只问缺失项，已有项继承
- 用户希望覆盖 design 决策 → 可显式触发"重新决策"，plan 弹出 Q1-Q4

## 6. 排除项

- 删除 plan Q1-Q4（保留作为 design 跳过时的 fallback）
- 反向传递（plan 决策回写到 design handoff）
- 跨 sprint 决策模板继承
