---
name: pivot
description: 中途修改 anchor 或 chunk plan。正式的计划变更流程，避免 plan 变牢笼
---

# Sprint Pivot

中途修改计划的正式流程。

## 步骤

1. 暂停执行
2. 用户说明调整原因
3. AI 提出修改方案（对 anchor 和/或 chunks 的具体变更）
4. 用户确认
5. 更新 anchor.md 和/或 chunks.md
6. 如果 Invariants 变了 → 重新跑 baseline 命令更新 state.json
7. 如果 Assumptions 新增了 → 等用户确认后再继续
8. 从当前位置继续执行
