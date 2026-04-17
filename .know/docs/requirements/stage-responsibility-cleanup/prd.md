# stage 职责收敛

<!-- 核心问题: 需求到哪了、验收标准是什么？
     定位: 需求级进度跟踪
     不属于本文档: 产品全局规划（→ roadmap）、技术方案（→ tech）、系统架构（→ arch） -->

## 1. 问题

两处职责不纯：
1. brainstorm Step 2 Value Mining（发散发现新价值）与 brainstorm 的 ONE JOB（验证需求可执行）不符。当前 Gate 默认 skip，但仍作为独立 Step 存在，文档结构误导
2. insight Step 5 Uncommitted Changes 是 git 清理动作，与 insight 的 ONE JOB（从偏差中学习）无关，混在学习步骤里

读文档的人（包括 agent）会按 stage 名推断职责，职责不纯的 stage 会让新 contributor 困惑。所有 sprint 用户间接受影响（通过 agent 行为的可预测性）。

## 2. 目标用户

sprint skill 的维护者、基于 sprint 做二次开发的 agent 编写者。期望每个 stage 的 Steps 都服务于该 stage 的 ONE JOB，读文档能快速对齐心智模型。

## 3. 核心假设

**将 Value Mining 重新表述为"用户主动触发的可选能力"、将 Uncommitted Changes 迁移到 stage 外的 hook → stage 文档与 ONE JOB 一一对应，职责清晰。**

验证方式：对 brainstorm.md 和 insight.md 的每个 Step 重做 ONE JOB 映射检查，所有 Step 均能标 ✓。

## 4. 方案

- **Before**: brainstorm 文档结构隐含"Value Mining 是标准流程" → **After**: Value Mining 降级为"用户主动触发的扩展"，Step 2 重写为"Optional: Value Mining（用户触发）"
- **Before**: insight Step 5 做 git uncommitted 检查 → **After**: Uncommitted Changes 移到 sprint-ctl end hook 或独立 stage-end hook，insight 只做学习

### 改动对照

| 项 | 当前位置 | 新位置 |
|----|---------|--------|
| Value Mining | brainstorm Step 2（Gate default skip） | brainstorm 附录"Optional Extensions"，用户主动触发 |
| Uncommitted Changes | insight Step 5 | sprint-ctl end 流程中，或 sprint 退出 hook |

### 任务

| 任务 | 文档 | 进度 |
|------|------|------|
| stage 职责收敛 | [tech](impl/tech.md) | 0/0 |

## 5. 验收标准

- 读 brainstorm.md → 所有标准 Step 均服务于"验证需求可执行"，Value Mining 清晰标记为"可选扩展"
- 读 insight.md → 所有 Step 均服务于"从偏差中学习"，不含 git 清理
- sprint 结束流程 → uncommitted changes 检查仍然被触发，但由 sprint-ctl end 处理
- 用户显式要求"挖掘价值" → Value Mining 仍可被触发，行为不变

## 6. 排除项

- 删除 Value Mining 能力（只重新归位，不删除）
- 改变 uncommitted changes 检查时机（仍在 sprint 结束时执行，只是归属不同）
- 修改其他 stage 的 Step 结构
