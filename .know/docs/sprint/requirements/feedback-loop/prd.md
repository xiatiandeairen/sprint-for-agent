# 反馈闭环

<!-- 核心问题: 需求到哪了、验收标准是什么？
     定位: 需求级进度跟踪
     不属于本文档: 产品全局规划（→ roadmap）、技术方案（→ tech）、系统架构（→ arch） -->

## 1. 问题

sprint 的 evaluate 和各阶段 gate 做出的判断（跳过/进入）缺乏反馈机制。当判断错误时（如 design=no 但 execute 阶段被迫退回 design），insight 阶段记录了偏差但下次 sprint 不会利用这个经验。判断失误导致的倒退在每次涉及跨模块改动的 sprint 中反复出现。现在 M1 完成后，流水线可用但不会自我优化，是提升决策质量的时机。

## 2. 目标用户

使用 sprint 驱动任务执行的开发者。当前在 evaluate 阶段依赖描述文本做判断，缺少历史数据支撑。替代方案是用户凭记忆手动调整 evaluate 答案，但随着 sprint 次数增多，记忆不可靠。

## 3. 核心假设

**采集决策偏差信号并跨 sprint 积累 → 用户在查询时能获得基于历史数据的推荐，减少 evaluate/gate 判断失误。**

验证方式：积累 ≥10 条信号后，query 输出的推荐与用户实际选择一致率 ≥70%。

## 4. 方案

- **Before**: evaluate 判断 design=no → execute 退回 design → insight 记录偏差 → 下次 sprint 无记忆，重复犯错
- **After**: 退回事件自动记录 → 用户查询时获得推荐"此类任务建议启用 design（历史倒退率 60%）" → 做出更准确的判断

### 任务

| 任务 | 文档 | 进度 |
|------|------|------|
| 反馈闭环实现 | [tech](impl/tech.md) | 0/0 |

## 5. 验收标准

- 阶段倒退时，`sprint-ctl feedback record` 写入信号到 `~/.config/sprint/feedback.json`
- gate 被用户否决推荐时，记录 gate_reject 信号
- insight 偏差分类完成时，记录 deviation 信号
- `sprint-ctl feedback query evaluate.design` 输出该决策点的信号统计和推荐
- `sprint-ctl feedback query --all` 输出所有有 pattern 的决策点摘要
- `sprint-ctl feedback config --enable` 开启功能，`--disable` 关闭，`--show` 查看状态
- 功能默认关闭，需用户主动开启
- 信号数 <3 时显示"数据不足，无推荐"
- 信号 dominant pattern 占比 <60% 时显示"信号分散，无明确推荐"

## 6. 排除项

- 倒退成本量化（记录倒退重做的步骤数和时间）— 推迟
- 信号衰减机制（旧信号降权）— 推迟
- 自动调整流水线行为（只做推荐，不自动改变 evaluate/gate 结果）
- 追踪用户主动变更需求导致的倒退（change-request 是中性的）
