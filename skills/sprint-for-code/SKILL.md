---
name: sprint-for-code
description: 编程任务的工作流。/sprint-for-code {desc} 选 flow 编排 stage 执行，归档到 XDG sprint 目录。
---

# Sprint for Code

## 1. Overview

做编程任务，输出代码或代码审查结果。

### 1.1 接受

以**代码改动或代码评价**为主体的任务。

举例：加功能 / 修 bug / 重构 / 迁移 / hotfix / spike / 代码审查（PR）。

### 1.2 不接受

- 非代码产出（产物不是代码）
- 度量驱动的循环型(反复 profile-改-度量直到达标)
- 调研 / 调查型（分析判断是主体，不是代码改动）

举例：写文章 / 数据分析 / UI 设计 / 性能 profile / 系统调研 / 技术选型 / 调试日志分析。

## 2. Hard Rules

- 范围守恒：只做用户授权范围内的事；原任务外的发现提示用户，等授权再做。不静默改 task 声明文件清单外的文件。
- 用户控方向：关键决策（做什么 / 做多大 / 风险取舍）AI 提候选，用户拍板。
- 决策门禁：凡是需要用户选择、确认、授权或改变任务边界的内容，必须先停下来等用户回复；用户未回复前不得继续执行后续 stage、不得写文件、不得把默认判断当成确认。只有用户明确说"你决定 / 默认即可 / 不用确认"时，AI 才可代为选择并继续。
- 不跳验证：每步该做的检查（anchor / 测试 / build）做完才算完成；前一步过了不代表当前步可省。
- 失败明示：做不到就明说原因；不假装成功，不糊弄"差不多"。
- 不混任务：单 sprint 内不混"加功能"和"重构既有代码"——拆开走两个 sprint。
- 不强行产出：本步无实质内容时直接说"无"，不为占位写废话。
- 用户调整 = 中性：用户在 §4.1 改 stage / 流程不算偏差；调整理由保留到 `Finalize.insight.sequence_adjust_reason`。

## 3. 内部变量声明

- **$SPRINT_ROOT** — 项目根路径。worktree 共享同一根；非 git 项目 = `$(pwd)`
- **$SPRINT_PID** — project id。$SPRINT_ROOT 中所有 `/` 替换为 `-`
- **$SPRINT_DIR** — sprint 归档目录。`${XDG_DATA_HOME:-$HOME/.local/share}/sprint/$SPRINT_PID`
- **$SPRINT_SID** — sprint id。格式 `YYYYMMDD-HHMMSS-RRR`（UTC 时间戳秒级 + 3 位随机后缀）
- **SPRINT_N** — handoff 章节累积序号。从 1 起递增；循环内每轮新增章节不覆盖

## 4. 工作流流程

### 4.1 信息确认

目标：和用户对齐 stage 执行流程 + 归档位置。

#### 步骤

1. 理解用户输入 desc。
2. 根据用户输入判定 stage 挂载，不输出提示。
  - **clarify** — 需求是否需要澄清？一句话能说清目的就不用
  - **explore** — 是否要先发散方案？实现路径唯一就不用
  - **design** — 是否要设计架构，写规格约束？单模块内变更就不用
  - **plan** — 是否要拆解任务？单文件改动就不用
  - **implement** — 是否要写代码？评审 / 调研 / 思考类任务不用
  - **verify** — 是否要外部验证？改动可逆、局部、不影响线上就不用
  - **review** — 是否要给用户验收说明？影响面 / 验收场景 / 重要变更不明显就需要
  - **reflect** — 是否要复盘？一次性小活不用
3. 评估流程模式（基于 step 2 挂载结果）：
  - 特殊流程模式只处理两类：`parallel` 和 `loop`
  - 先判 `parallel`：当implement阶段工作量明显较大时，命中 `parallel`
  - 命中 `parallel` 时，按任务形态推荐以下模式之一：
    - `plan → parallel(implement) → verify`
    - `plan → parallel(implement) → review → reflect`
    - `plan → parallel(implement → verify) → reflect`
  - 若未命中 `parallel`，再判 `loop`：当任务形态需要多次迭代时，命中 `loop`
  - 命中 `loop` 时，按起点推荐以下模式之一：
    - `loop(implement → verify) max=3`
    - `loop(plan → implement → verify) max=5`
    - `loop(design → plan → implement → verify) max=5`
    - `loop(explore → design → plan → implement → verify) max=5`
  - 都不命中时，按普通顺序执行
4. 解析 §3 变量：
  ```bash
   COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null || true)
   if [ -z "$COMMON_DIR" ]; then SPRINT_ROOT="$(pwd)"
   else SPRINT_ROOT=$(dirname "$(cd "$COMMON_DIR" && pwd)"); fi
   SPRINT_PID="$(echo "$SPRINT_ROOT" | sed 's|/|-|g')"
   SPRINT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/sprint/$SPRINT_PID"
   mkdir -p "$SPRINT_DIR"
   while :; do
     SPRINT_SID="$(date -u +%Y%m%d-%H%M%S)-$(printf '%03d' $((RANDOM % 1000)))"
     [ ! -f "$SPRINT_DIR/$SPRINT_SID.md" ] && break
   done
  ```
5. 渲染任务确认模板：
  ```
   ━━ 任务确认 ━━

   任务: {一句话总结}

   执行流程: {单行 stage 序列}

   开始？(yes / 想调整直接说)
  ```
   单行 stage 序列格式：
  - 顺序段：`stageA → stageB → ...`
  - 循环段：`loop(stageX → stageY → ...) max=N`
  - 并行段：`parallel(stageX)` 或 `parallel(stageX → stageY)`
  - 混合：`stageA → loop(stageX → stageY) max=3 → stageZ`
  - 混合：`stageA → parallel(stageX) → stageZ`
  - 混合：`stageA → parallel(stageX → stageY) → stageZ`
  - stage 用英文名（clarify / explore / design / plan / implement / verify / review / reflect）
6. 展示模板，等用户回复（确认即同意全部安排，调整只能是 stage 或流程两类之一）：
  - yes / 确认 / ok → 进 §4.2；累积的 adjustments 列表保留在内存，供 `§4.4` 直接修改最后一段内容
  - 调整 stage（如"加 verify"、"不用 plan"）或调整流程（如"开 plan-起点循环"、"关写-验证"、"循环改为从 design 起"、"开 implement 并行"、"关并行"）：

#### few shot示例

```
[示例 1: 极简，仅 implement]

━━ 任务确认 ━━

任务: 在 user.ts 加一行 console.log 看请求体

执行流程: implement

开始？(yes / 想调整直接说)
```

```
[示例 2: 常规，写-验证循环默认开]

━━ 任务确认 ━━

任务: 修登录失败 bug

执行流程: plan → loop(implement → verify) max=3

开始？(yes / 想调整直接说)
```

```
[示例 3: 复杂，AI 推荐 design-起点循环]

━━ 任务确认 ━━

任务: 把 auth 中间件从 sessionStore 切到 JWT

执行流程: clarify → explore → loop(design → plan → implement → verify) max=5 → reflect

开始？(yes / 想调整直接说)
```

### 4.2 创建归档

目标：建立 sprint handoff 文件，写入元数据。

步骤：

1. 在 `$SPRINT_DIR` 下创建 `$SPRINT_SID.md`，内容按 [templates/handoff.md](./templates/handoff.md) 的初始化结构写入。
2. 写入以下字段：
  - `id`：`$SPRINT_SID`
  - `type`：固定写 `sprint-for-code`
  - `desc`：用户输入 desc 原文
  - `sequence`：本次 sprint 的完整真实执行语法，如 `plan → loop(implement → verify) max=3`
  - `created`：当前 UTC ISO8601 时刻
3. 按 handoff 模板的 `SECTION: finalize` 默认结构创建 `Finalize` 内容块，写入以下字段：
  - `status`：写 `running`
  - `completed_at`：保持空值，不改
  - `insight.sequence_adjust_reason`：有调整时写 1 句话，格式固定为 `"<动作> — <理由>"`；无调整时不写
4. 创建成功后告知用户：
  ```
   归档建立完毕，流程开始。
  ```
5. 进 §4.3

### 4.3 执行 stages

目标：按 §4.1 流程编排逐个跑 stage，写 handoff。

#### 步骤

##### 1. 读取 `sequence` 

- 针对`sequence`按 `→` 拆出顶层 token，并从左到右执行
- 顶层 token 只允许三类：
  - 普通 stage
  - `loop(...)`
  - `parallel(...)`

##### 2. 执行普通 stage

- 按 [templates/handoff.md](./templates/handoff.md) 的 `SECTION: runtime` 结构整体更新 `Runtime` 内容块，把 `cursor` 改为当前 stage 名，清空 `loop.active`，并保持 `parallel.completed` 当前值
- 按当前 stage 文件执行
  - **clarify** — [./stages/clarify.md](./stages/clarify.md)
  - **explore** — [./stages/explore.md](./stages/explore.md)
  - **design** — [./stages/design.md](./stages/design.md)
  - **plan** — [./stages/plan.md](./stages/plan.md)
  - **implement** — [./stages/implement.md](./stages/implement.md)
  - **verify** — [./stages/verify.md](./stages/verify.md)
  - **review** — [./stages/review.md](./stages/review.md)
  - **reflect** — [./stages/reflect.md](./stages/reflect.md)
- stage 完成后，把本 stage 内容追加到 [templates/handoff.md](./templates/handoff.md) 的 `SECTION: stages`
- 继续执行下一个顶层 token

##### 3. 执行 `loop(...)`

- 按 [templates/handoff.md](./templates/handoff.md) 的 `SECTION: runtime` 结构整体更新 `Runtime` 内容块，把 `cursor` 改为 `loop()`
- 从 `loop(...) max=N` 读取 loop 内 stage 序列和 `max`，当前轮次设为 1
- 按 loop 内顺序逐个执行 stage；每进入一个 stage 前，整体更新 `Runtime` 内容块，把 `loop.active` 改为当前 stage 名；每个 stage 完成后，把本 stage 内容追加到 `SECTION: stages`，标题追加 `(round {k})`
- 本轮最后一个 stage 完成后，按该 stage 的说明判断本轮是否完成
- 已完成时：
  - 整体更新 `Runtime` 内容块
  - 把 `loop.active` 清空
  - 退出 loop
  - 继续执行下一个顶层 token
- 未完成时：
  - 若 `round < max`，`round +1`，开始下一轮
  - 若 `round = max`，停止后续顶层 token，进入 `§4.4`

##### 4. 执行 `parallel(...)`

- 按 [templates/handoff.md](./templates/handoff.md) 的 `SECTION: runtime` 结构整体更新 `Runtime` 内容块，把 `cursor` 改为 `parallel()`，并把 `parallel.completed` 重置为 `[]`
- 从前一个 stage 的正文读取任务列表；每个任务都要有唯一任务名
- 按任务列表启动并行分支；每个分支都执行 `parallel(...)` 内定义的 stage 序列；每个 stage 完成后，把本 stage 内容追加到 `SECTION: stages`，标题追加 `(task: {task_name})`
- 某个任务对应的分支完成后，整体更新 `Runtime` 内容块，把任务名追加到 `parallel.completed`
- 检验机制：每次更新后，都把 `parallel.completed` 与任务列表逐项对比；只有任务名全部覆盖且数量一致，才算“全部任务完成”
- 全部任务完成时：
  - 整体更新 `Runtime` 内容块
  - 把 `parallel.completed` 清空
  - 退出 parallel
  - 继续执行下一个顶层 token
- 仍有任务未完成时：
  - 等待剩余分支完成
  - 不进入后续顶层 token

##### 5. `sequence` 全部执行完

- 进入 `§4.4`

不支持嵌套 `loop`、嵌套 `parallel`、同一层混用 `loop` 和 `parallel`、goto。

### 4.4 收尾

目标：标记 sprint 结束，输出汇总。

步骤：

1. 读 handoff，解析 frontmatter `created` + 各章节 `<!-- ts: {...} -->`
2. 算 per-section 耗时：
  - 第 1 章节：dur = section[1].ts − frontmatter.created
  - 第 i 章节 (i>1)：dur = section[i].ts − section[i-1].ts
3. 按 [templates/handoff.md](./templates/handoff.md) 的 `SECTION: finalize` 结构整体更新 `Finalize` 内容块，写入：
  - `STATUS=completed`
  - `COMPLETED_AT={now ISO8601}`
  - `SEQUENCE_ADJUST_REASON={沿用 handoff 现有值}`
  - `INSIGHT_BODY={insight 其余内容；无则留空}`
  - aborted 时将 `STATUS=aborted`，并把原因写入 `INSIGHT_BODY`
4. 按以下模板输出给用户：
  ```
   ━━ Sprint 完成 ━━
   ID:   {SPRINT_SID}
   归档: $SPRINT_DIR/$SPRINT_SID.md

   stage 耗时：
   {N}. {stage 名}    {耗时}
   ...
   total              {总耗时}
  ```
