# 反馈闭环 技术方案

<!-- 核心问题: 怎么实现、做到哪了？
     定位: 技术方案 + 实现进度跟踪（多次 sprint 迭代完善）
     不属于本文档: 产品需求（→ PRD）、系统架构（→ arch）、接口契约（→ schema） -->

## 1. 背景

- M5 里程碑要求：跨 sprint 积累决策偏差信号，用户查询时输出推荐
- 技术约束：存储使用 XDG 目录结构（`~/.config/sprint/`），基于文件的 JSON 格式，与 metrics.log 模式一致
- 前置依赖：无。sprint-ctl.sh 已有 evaluate/stage 等子命令模式，新增 feedback 子命令即可

## 2. 方案

### 文件结构

```
~/.config/sprint/
├── config.json         # 功能开关
└── feedback.json       # 反馈信号存储
```

```
scripts/sprint-ctl.sh   # 新增 feedback 子命令
stages/insight.md        # 新增 deviation 信号写入指令
skills/sprint/SKILL.md   # 新增倒退/gate 打回写入规则 + 查询入口
```

### 核心流程

```
[信号产生]                         [存储]                      [消费]

阶段倒退（SKILL.md 规则触发）──┐
                               │
gate 打回（stage 文件触发）────┼──→ sprint-ctl feedback record ──→ feedback.json
                               │
insight 偏差（insight.md 触发）─┘

                                  sprint-ctl feedback query ──→ 读取 → 聚合 → 推荐
                                    （用户主动调用）
```

### 数据结构

**config.json:**
```json
{
  "feedback": {
    "enabled": false
  }
}
```

**feedback.json:**
```json
{
  "version": 1,
  "entries": [
    {
      "type": "regression | gate_reject | deviation",
      "decision_point": "evaluate.design | brainstorm.step2.gate | ...",
      "expected": "skip",
      "actual": "needed",
      "context": "cross-module change",
      "sprint_id": "20260413-133947-744",
      "timestamp": "2026-04-13T13:39:47Z"
    }
  ]
}
```

### 信号触发点

| 信号类型 | 触发位置 | decision_point 格式 |
|---------|---------|-------------------|
| regression | SKILL.md Pipeline Rules — 倒退时 | `{from_stage}→{to_stage}` |
| gate_reject | 各 stage 文件 Gate 判断 — 用户否决推荐时 | `{stage}.step{N}.gate` |
| deviation | insight.md Step 2 — 偏差分类时 | `{stage}.{deviation_type}` |

### CLI 接口

```bash
# 记录信号
sprint-ctl feedback record <type> <decision_point> <expected> <actual> [--context "..."] [--sprint "id"]

# 查询
sprint-ctl feedback query [decision_point] [--all] [--limit N]

# 配置
sprint-ctl feedback config [--enable|--disable|--show]
```

### 推荐算法

```
输入: 某 decision_point 的所有 entries

Step 1: 计数
  total = 该 point 的信号总数
  dominant_pattern = 出现最多的 (expected → actual) 对

Step 2: 是否形成 pattern？
  total >= 3？ 否 → "数据不足，无推荐"
  dominant_pattern 占比 >= 60%？ 否 → "信号分散，无明确推荐"

Step 3: 生成推荐
  是 → "此类任务建议 {actual}（历史 {total} 次中 {count} 次 {expected} 后需要 {actual}，占 {pct}%）"
```

## 3. 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 存储位置 | 全局 XDG `~/.config/sprint/` | 跨项目积累；项目级存储会丢失跨项目的学习价值 |
| 触发方式 | 用户主动查询 | 避免增加常规流程的交互负担；自动推荐可能干扰用户判断 |
| 信号格式 | JSON 结构化 | 可查询、可聚合；与现有 state.json 模式一致 |
| 功能开关 | config 控制，默认关闭 | 新功能不影响现有用户；需主动 opt-in |
| 推荐阈值 | ≥3 条 + ≥60% dominant | 避免样本不足的噪声推荐；60% 是"明显倾向"的最低标准 |
| 不自动调整 | 只推荐不改行为 | 保持用户对流水线的完全控制权 |

## 4. 迭代记录

### 2026-04-13

设计阶段完成。确定了信号 schema（7 字段）、3 类信号源、CLI 接口（record/query/config）、推荐算法（计数 + 阈值过滤）。
