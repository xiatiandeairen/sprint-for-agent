# 建立学习闭环

<!-- 核心问题: 需求到哪了、验收标准是什么？
     定位: 需求级进度跟踪
     不属于本文档: 产品全局规划（→ roadmap）、技术方案（→ tech）、系统架构（→ arch） -->

## 1. 问题

insight 阶段会把教训写入 auto memory（feedback 类型），但 evaluate 阶段只读 `summary.json` 的 HINTS 统计数据，不读 memory 条目——学到的教训要等下次 brainstorm/design 阶段 recall 才可能命中，反馈链路过长。同时复发性偏差（连续多次在同一 stage 漏同一类问题）当前需要人工回看 insight 才能发现，agent 看不见模式。所有频繁使用 sprint 的用户都会积累教训但不能在下一次 sprint 起点被提醒。

## 2. 目标用户

频繁使用 sprint 的开发者。sprint 启动阶段想立刻知道"过去有没有踩过相关坑"，当前只能靠后续 stage 的 recall 或手动翻 memory 文件，起点盲区明显。

## 3. 核心假设

**evaluate 阶段直接读 memory feedback 条目，同时 insight 自动检测复发偏差 → 用户在 sprint 起点就看到相关历史教训，连续出现的偏差会被升级为强提示。**

验证方式：故意创造"连续 3 次 sprint 在 design 阶段漏并发风险"的场景，第 4 次 sprint 的 evaluate 输出应包含该教训提示。

## 4. 方案

- **Before**: sprint 启动时 evaluate 只看到"过去 3 次 duration 趋势"这类统计 HINTS → **After**: evaluate 还显示相关 memory 教训（按描述关键词匹配）+ 复发偏差警告
- **Before**: 同类偏差连续发生在多个 sprint 没人知道 → **After**: insight 自动对比最近 N 个 sprint 的 deviation，连续出现则输出"复发偏差"告警

### 对比维度

| 类别 | 改进点 |
|------|-------|
| 起点 | evaluate HINTS 扩展：summary.json 统计 + memory feedback 条目（关键词匹配） |
| 闭环 | insight 新增复发偏差检测：对比最近 3-5 次 sprint 的 deviation 分类 |

### 任务

| 任务 | 文档 | 进度 |
|------|------|------|
| 学习闭环实现 | [tech](impl/tech.md) | 0/0 |

## 5. 验收标准

- 用户启动 sprint 且描述关键词与某 memory feedback 条目匹配 → evaluate HINTS 包含该教训
- 最近 3 次 sprint 在相同 stage 出现同类偏差 → 当前 insight 输出"复发偏差"告警
- memory 无匹配条目 → HINTS 不提 memory 部分（保持沉默，不强行输出）
- 只有 1 次历史 sprint → 不做复发检测（样本不足）

## 6. 排除项

- 跨项目学习共享（当前 memory 是项目级）
- 教训自动应用到 stage 决策（只提示，用户决定是否采纳）
- 非 feedback 类型的 memory（user/project/reference 不进 HINTS）
