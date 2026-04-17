# 建立数据聚合 技术方案

<!-- 核心问题: 怎么实现、做到哪了？
     定位: 技术方案 + 实现进度跟踪（多次 sprint 迭代完善）
     不属于本文档: 产品需求（→ PRD）、系统架构（→ arch）、接口契约（→ schema） -->

## 1. 背景

<!-- 技术约束和前置依赖。回答"为什么要做这个方案"
  - EXCLUDE: 产品愿景、用户画像（→ PRD） -->

- v2 M1 里程碑要求：跨 sprint 读取和聚合 metrics 数据
- 技术约束：不引入持久化层，实时计算；python3 内联（与现有命令一致）
- 前置依赖：v1 已有 metrics.log 事件格式和 execute handoff 结构

## 2. 方案

<!-- 高层技术设计。回答"怎么实现"
  - EXCLUDE: 函数签名、算法伪代码、完整接口定义（→ schema） -->

### 文件结构

```
scripts/sprint-ctl.sh       # 新增 stats case（python3 内联）
tests/test-sprint-ctl.sh    # 新增 4 个 stats 测试用例
```

### 核心流程

```
sprint-ctl stats [--last N] [--status X]
  → 遍历 .sprint/*/state.json → 过滤 + 排序
  → 解析 metrics.log → sprint 耗时、stage 耗时、anchor 结果
  → 解析 handoffs/execute.md → task 完成率
  → 聚合 → 三段输出（Efficiency / Quality / Value）
```

### 数据结构

输入源：
- state.json: status, created_at（过滤排序）
- metrics.log: sprint_start/end（耗时）, stage_end（阶段分布）, anchor_check（通过率）
- handoffs/execute.md: "Tasks completed: N/M"（任务完成率）

输出：CLI 文本，三个 section，无持久化。

## 3. 关键决策

<!-- 技术选型及理由。回答"为什么这样做" -->

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 持久化 | 不存储，实时计算 | sprint <100 时足够快；拒绝 SQLite（增加依赖）和 JSON 缓存（需失效策略） |
| 数据位置 | 项目级 .sprint/ | 数据源就在这里；拒绝 XDG 跨项目聚合（信噪比低） |
| 配置开关 | 默认开启 | 只读查询无副作用；拒绝 config gate（增加摩擦） |
| 偏差分类 | 暂不支持 | insight 无持久化 handoff；标注 N/A |

## 4. 迭代记录

<!-- 每次 sprint 实现了什么，新增在前。 -->

### 2026-04-14

M1 完成。实现了 stats 子命令（效率/质量/价值三类指标 + --last/--status 过滤）。新增 4 个测试用例（18/18 全部通过）。
