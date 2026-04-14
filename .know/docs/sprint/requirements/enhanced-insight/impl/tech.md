# 增强用户 insight 技术方案

<!-- 核心问题: 怎么实现、做到哪了？
     定位: 技术方案 + 实现进度跟踪（多次 sprint 迭代完善）
     不属于本文档: 产品需求（→ PRD）、系统架构（→ arch）、接口契约（→ schema） -->

## 1. 背景

<!-- 技术约束和前置依赖。回答"为什么要做这个方案"
  - EXCLUDE: 产品愿景、用户画像（→ PRD） -->

- v2 M2 里程碑要求：insight 阶段展示跨 sprint 趋势
- 技术约束：不依赖 sprint-ctl stats（当前 sprint 包含/排除歧义），用独立 python3 脚本直接解析
- 前置依赖：M1 已验证 metrics.log + handoff 解析可行

## 2. 方案

<!-- 高层技术设计。回答"怎么实现"
  - EXCLUDE: 函数签名、算法伪代码、完整接口定义（→ schema） -->

### 文件结构

```
stages/insight.md              # Step 3 扩展：新增 Historical Comparison 输出模板 + python3 脚本指令
scripts/sprint-insight-stats.sh # 独立脚本：解析历史数据，输出对比表（排除当前 sprint）
```

### 核心流程

```
insight Step 3 (Process Evaluation)
    │
    ├─ 现有：阶段耗时分布 + verdict
    │
    └─ 新增：bash sprint-insight-stats.sh {current_sprint_id}
              → 遍历 .sprint/*/ 排除当前 ID
              → 计算历史平均（耗时、完成率、anchor、task）
              → 与当前 sprint 对比
              → 输出对比表 + 趋势指示器
```

### 输出模板

```
### Historical Comparison
| 指标 | 本次 | 历史平均 | 趋势 |
|------|------|---------|------|
| 总耗时 | {N}m | {M}m | ↑/↓/= |
| Anchor 通过率 | {N}% | {M}% | ↑/↓/= |
| Task 完成率 | {N}% | {M}% | ↑/↓/= |
```

趋势：本次优于历史 → ↑，劣于 → ↓，差异 <5% → =。历史 <2 次 → 不展示。

## 3. 关键决策

<!-- 技术选型及理由。回答"为什么这样做" -->

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 数据获取 | 独立脚本，不复用 sprint-ctl stats | stats 无法排除当前 sprint；独立脚本更精确 |
| 插入位置 | Step 3 追加 | 不增加步骤数，与 Process Evaluation 自然衔接 |
| 最少样本 | 历史 <2 次不展示 | 1 次无法算"平均" |
| 趋势阈值 | 差异 <5% 视为持平 | 避免噪声 |

## 4. 迭代记录

### 2026-04-14

设计完成。确定了独立脚本方案、Step 3 集成、对比表模板。
