# 核心流水线 技术方案

## 1. 背景

sprint 的 M1 里程碑：完成核心流水线，任务从创建到完成可走通全流程。需要实现 3 个 skill 入口、7 个执行阶段、2 个 CLI 脚本、以及完整的状态管理和文件结构。

当前技术约束：anchor-check.sh 硬编码 Swift 路径（M2 解决），无项目级配置机制（M4 解决）。

## 2. 方案

### 整体结构

```
skills/sprint/SKILL.md          ← 主入口，evaluate + pipeline loop + 全局规则
skills/long-sprint/SKILL.md     ← 长任务编排，Phase A/B/C
skills/todo/SKILL.md            ← 快速任务，4 种模式路由
stages/brainstorm.md            ← 需求澄清（3 步）
stages/design.md                ← 技术设计（7 步）
stages/plan.md                  ← 任务拆分（6 步）
stages/execute.md               ← 代码实现（4 步 × 2 模式）
stages/quality.md               ← 回归验证（3 步）
stages/review.md                ← 风险审查（5 步）
stages/insight.md               ← 复盘总结（5 步）
stages/long.md                  ← long-sprint 准备阶段（6 步）
scripts/sprint-ctl.sh           ← 生命周期管理
scripts/anchor-check.sh         ← 锚点验证
```

### 核心流程

```
/sprint {description}
    │
    ▼
[Input Normalization] → 解析描述，检测语言，识别 override 关键词
    │
    ▼
[Evaluate] → 3 个 yes/no 问题（clarify/design/risk）
    │         用户确认 → sprint-ctl evaluate + create + activate
    │
    ▼
[Pipeline Loop] → 按启用阶段顺序执行：
    │   1. sprint-ctl stage {id} {stage} running
    │   2. 读取 stage file，逐步执行（遵循 gate 条件）
    │   3. 写 handoff（insight 除外）
    │   4. sprint-ctl stage {id} {stage} completed
    │   5. 公布下一阶段，获取确认
    │
    ▼
[sprint-ctl end] → insight 阶段关闭 sprint
```

### Evaluate 机制

| 问题 | yes → 启用 | no → 跳过 |
|------|-----------|----------|
| 需求是否需要澄清？ | brainstorm | skip |
| 是否需要技术设计？ | design | skip |
| 是否涉及高风险？ | quality + review | quality only |

Always-on: plan, execute, quality, insight。关键词 override：`delete/migrate/payment/production/permission` → risk=yes。

### 阶段链路

| 阶段 | 读取 | 产出 | Gate 类型 |
|------|------|------|----------|
| brainstorm | 用户描述 | demand frame + conclusion | clarify=yes |
| design | brainstorm handoff 或描述 | delivery form + decision register + file structure | design=yes |
| plan | design handoff 或描述 | task list + anchors.txt + execution mode | always |
| execute | plan handoff + anchors.txt | completed tasks + files changed | always |
| quality | execute handoff + anchors.txt | build/test/anchor 结果 | always |
| review | execute handoff + git diff | review report | risk=yes |
| insight | all handoffs + metrics.log | deviation analysis + process evaluation | always |

### Anchor 系统

plan 阶段从 design handoff 自动提取，写入 `.sprint/{id}/anchors.txt`：

| 类型 | 来源 | 验证方式 |
|------|------|---------|
| `MUST_EXIST {path}` | file structure: create | `test -f` |
| `MUST_BUILD` | 项目可构建 | `swift build`（当前硬编码） |
| `MUST_TEST` | 项目有测试 | `swift test`（当前硬编码） |
| `MUST_IMPORT {target} {module}` | 依赖要求 | `grep import` |
| `MUST_NOT_IMPORT {target} {module}` | 依赖禁止 | `grep import` 反向 |
| `MUST_NOT_EXIST {path}` | 删除确认 | `test -f` 反向 |
| `FILE_NOT_MODIFIED {path}` | 不动约束 | `git diff` 检查 |

execute 每个 task 后运行 `anchor-check.sh`，quality 全局再运行一次。

### sprint-ctl.sh 命令

| 命令 | 功能 | 状态变更 |
|------|------|---------|
| `evaluate {c} {d} {r}` | 计算阶段列表 | 无 |
| `create {type} {desc} {stages}` | 创建 sprint 目录和 state.json | → created |
| `activate {id}` | 设置 base_commit | → running |
| `stage {id} {stage} {status}` | 记录阶段开始/完成/跳过 | metrics.log 追加 |
| `end {id}` | 关闭 sprint，输出统计 | → completed |
| `list` | 列出所有 sprint | 无 |

### 状态管理

```json
{
  "id": "YYYYMMDD-HHMMSS-NNN",
  "type": "sprint|long|todo",
  "desc": "...",
  "stages": ["plan","execute","quality","insight"],
  "status": "created|running|completed",
  "current_stage": "execute",
  "base_commit": "abc1234",
  "created_at": "ISO8601"
}
```

### 目录结构

```
.sprint/{id}/
├── state.json          # 生命周期状态
├── handoffs/           # 各阶段 handoff 文档
│   ├── brainstorm.md
│   ├── design.md
│   ├── plan.md
│   ├── execute.md
│   └── review.md
├── anchors.txt         # plan 生成，execute/quality 验证
└── metrics.log         # 追加写入事件日志
```

### 子 skill 路由

| 入口 | 路由规则 | 执行阶段 |
|------|---------|---------|
| `/sprint {desc}` | 标准流水线 | evaluate → enabled stages |
| `/todo {desc}` | 1 file + <20 lines → 直接执行；多步 → execute + insight | 按路由决定 |
| `/todo {sprint_id}` | 恢复暂停的 sprint | 从断点阶段继续 |
| `/todo {path.md}` | 计划驱动执行 | execute + insight |
| `/long-sprint {desc}` | Phase A 准备 → Phase B 自动执行子 sprint → Phase C 总结 | long stage + N × (plan+execute+quality) |

### Execute 双模式

**Step-by-step**（默认）：顺序执行每个 task，每个 task 后 anchor check + AI test + user review。

**Parallel**：独立 task 并行（subagent），共享 worktree 隔离。全部完成后统一 review + rebase。

选择逻辑：全部 S/M + 无依赖 → Parallel；有依赖 → Step-by-step。

## 3. 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 状态管理 | JSON 文件 + metrics.log，不用数据库 | 零依赖，git 可追溯，bash 可操作 |
| 阶段裁剪 | 3 个 yes/no 问题 | 简单直观，覆盖需求澄清/设计/风险三个维度 |
| Anchor 机制 | 文本文件 + bash 脚本验证 | 可读、可扩展、不依赖特定语言工具链 |
| Handoff 机制 | Markdown 文件，每阶段独立 | 人可读、AI 可解析、阶段间松耦合 |
| 脚本语言 | Bash + python3（JSON 处理） | 跨平台、零安装依赖 |
| Model 选择 | 步骤级声明，非阶段级 | 同阶段不同步骤复杂度不同，精细控制成本 |
| Subagent 失败策略 | 3 级递进（retry → upgrade model → stop） | 平衡自动恢复与人工介入 |

## 4. 边界情况

| 场景 | 处理 |
|------|------|
| 描述为空 | 要求用户提供描述，不继续 |
| 描述 <5 词且含糊 | 追问一个澄清问题 |
| upstream handoff 缺失（阶段被跳过） | 使用用户原始描述作为输入 |
| sprint-ctl.sh 命令失败 | 报告原始错误信息，让用户重试或跳过 |
| execute 中发现需要改 plan 外的文件 | 停止报告，不自行继续 |
| anchor check 失败 | 修复后才能进入下一 task |
| Parallel 模式 subagent 失败 | 3 级递进：retry → upgrade model → stop 并报告 |
| worktree rebase 冲突 | 停止，报告给用户 |

## 5. 测试用例

| 场景 | 输入 | 预期输出 |
|------|------|---------|
| 标准 sprint 全流程 | `/sprint "add user profile"` | 7 阶段顺序执行，每阶段产出 handoff |
| 简单任务裁剪 | `/sprint "fix typo"` clarify=no, design=no, risk=no | 跳过 brainstorm/design/review，只走 plan→execute→quality→insight |
| 风险关键词触发 | `/sprint "migrate database"` | risk 自动设为 yes，启用 quality+review |
| anchor 失败阻断 | execute 中 MUST_BUILD 失败 | 停止当前 task，不进入下一 task |
| todo 直接执行 | `/todo "rename variable"` 1 file <20 lines | 直接执行，不走 plan |
| long-sprint 拆分 | `/long-sprint "重构 auth 模块"` | Phase A 拆分子 sprint → Phase B 顺序执行 → Phase C 总结 |

## 6. 风险与未决项

- anchor-check.sh 硬编码 `swift build` 和 `src/mac/Packages/` 路径，非 Swift 项目无法使用构建验证（M2 解决）
- `MUST_IMPORT` / `MUST_NOT_IMPORT` 同样硬编码 Swift 包路径（M2 解决）
- metrics.log 只写不读，无法量化 sprint 实际效果（v2 解决）
- 无项目级配置机制，接入新项目需要改源码（M4 解决）

## 7. 文件变更

| 操作 | 文件 | 说明 |
|------|------|------|
| create | `skills/sprint/SKILL.md` | 主 skill：evaluate、pipeline loop、全局规则 |
| create | `skills/long-sprint/SKILL.md` | 长任务编排 skill |
| create | `skills/todo/SKILL.md` | 快速任务 skill |
| create | `stages/brainstorm.md` | 需求澄清阶段（3 步） |
| create | `stages/design.md` | 技术设计阶段（7 步） |
| create | `stages/plan.md` | 任务拆分阶段（6 步） |
| create | `stages/execute.md` | 代码实现阶段（双模式） |
| create | `stages/quality.md` | 回归验证阶段（3 步） |
| create | `stages/review.md` | 风险审查阶段（5 步） |
| create | `stages/insight.md` | 复盘总结阶段（5 步） |
| create | `stages/long.md` | long-sprint 准备阶段（6 步） |
| create | `scripts/sprint-ctl.sh` | 生命周期管理脚本 |
| create | `scripts/anchor-check.sh` | 锚点验证脚本 |
