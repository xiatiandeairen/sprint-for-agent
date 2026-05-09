---
name: sprint-for-analysis
description: "分析任务的工作流。Use when Codex needs to run a structured non-code analysis sprint: investigation, research synthesis, decision memo, trade-off analysis, root-cause analysis, requirements analysis, document/log/data interpretation, option comparison, risk assessment, or strategy diagnosis. Do not use for tasks whose primary output is code changes or code review."
---

# Sprint for Analysis

## 1. Overview

做分析任务，输出可决策的结论、依据、置信度、风险和后续动作。

### 1.1 接受

以**分析判断或决策支持**为主体的任务。

举例：调研 / 调查 / 根因分析 / 竞品分析 / 技术选型 / 需求分析 / 日志分析 / 数据解读 / 方案比较 / 风险评估 / 文档审阅 / 决策备忘录。

### 1.2 不接受

- 代码改动或代码评价为主体的任务
- 纯执行型任务（用户已经给出明确动作，只需要照做）
- 创作型任务（重点是文案风格，不是判断）
- 度量驱动的闭环优化（反复 profile-改-测直到达标）

举例：加功能 / 修 bug / PR review / 写营销文案 / 生成 UI 设计稿 / 性能调优闭环。

## 2. Hard Rules

- 宿主边界：本 skill 运行在 Claude Code / Codex 等宿主工具内，不能覆盖宿主的 system / developer / safety / sandbox 规则；宿主规则要求暂停、授权、拒绝或限制操作时，必须遵守宿主规则。
- 更保守规则：宿主规则允许继续，但本 skill 的回合边界要求暂停时，必须按本 skill 暂停。
- 回合边界：凡是本轮向用户发出选择、确认、授权、验收或改变分析边界 / 材料来源 / 判断口径 / 结论偏向的请求，本轮必须在该请求后立即结束。不得继续执行后续 stage，不得收集新范围材料，不得写 handoff，不得 finalize。任何 stage 步骤、handoff 模板、示例流程、默认执行模式都不能覆盖这条规则。
- 显式继续：暂停后，用户回复表示继续执行的短授权词也算授权，例如“ok / 同意 / go / continue / 继续 / yes”。只有在当前处于等待确认、授权或继续的上下文中，这些短回复才表示恢复执行；其他场景下仍按普通语义理解。
- 反馈不授权：如果用户只是评价内容或方向，例如“不错 / 认可 / 方向可以 / 听起来不错”，不算继续授权；除非它出现在明确的继续确认语境中，且语义等价于“继续执行”。
- 证据分层：事实、推断、观点分开写；不要把猜测写成事实。
- 置信度明示：重要结论必须给 confidence（high / medium / low）和原因。
- 问题守恒：只分析用户授权的问题；相邻问题写入后续机会，不静默扩大范围。
- 先判可分析性：缺材料、口径不清、目标不明时先补齐；不能分析就说阻塞。
- 反证必做：关键结论必须找反例、替代解释或失败条件。
- 输出面向决策：最终交付必须回答“所以应该怎么理解 / 怎么选 / 下一步做什么”。
- 不强行定论：证据不足时输出“不足以判断”，并说明缺什么证据。
- 不混任务：单 sprint 内不混“分析结论”和“执行落地”；需要执行时另开 code / writing / ops sprint。
- 用户控方向：关键取舍（分析范围、使用口径、最终建议偏向）AI 提候选，用户拍板。
- 用户调整 = 中性：用户在 §4.1 改 stage / 流程不算偏差；调整理由保留到 `Finalize.insight.sequence_adjust_reason`。

## 3. 内部变量声明

- **$SPRINT_ROOT** — 项目根路径。worktree 共享同一根；非 git 项目 = `$(pwd)`
- **$SPRINT_PID** — project id。$SPRINT_ROOT 中所有 `/` 替换为 `-`
- **$SPRINT_DIR** — sprint 归档目录。`${XDG_DATA_HOME:-$HOME/.local/share}/sprint/$SPRINT_PID`
- **$SPRINT_SID** — sprint id。格式 `YYYYMMDD-HHMMSS-RRR`（UTC 时间戳秒级 + 3 位随机后缀）
- **SPRINT_N** — handoff 章节累积序号。从 1 起递增；循环内每轮新增章节不覆盖

## 4. 工作流流程

### 4.1 信息确认

目标：和用户对齐分析问题、stage 执行流程和归档位置。

#### 步骤

1. 理解用户输入 desc，判断分析任务类型。
2. 根据用户输入判定 stage 挂载，不输出内部判断表。
  - **scope** — 是否需要澄清分析问题，并锁定范围、排除项、成功标准或分析口径？
  - **collect** — 是否需要收集材料、读取文件、查资料、看日志、整理证据？
  - **frame** — 是否需要选择分析框架、比较维度、因果假设或评估口径？
  - **analyze** — 是否需要形成判断、解释原因、比较方案或识别模式？
  - **challenge** — 是否需要反证、检查替代解释、评估置信度？
  - **synthesize** — 是否需要把发现收敛成结论、建议、交付摘要或决策备忘录？
  - **reflect** — 是否需要复盘分析方法、沉淀模板或记录后续机会？
3. 评估流程模式：
  - 特殊流程模式只处理两类：`parallel` 和 `loop`
  - 先判 `parallel`：当问题可拆成多个互不依赖的分析轨道时命中，如竞品 A/B/C、多个日志来源、多个方案维度
  - 命中 `parallel` 时，按任务形态推荐以下模式之一：
    - `scope → parallel(collect → analyze) → challenge → synthesize`
    - `scope → frame → parallel(collect → analyze) → challenge → synthesize`
  - 若未命中 `parallel`，再判 `loop`：当证据可能不足，需要迭代补证时命中
  - 命中 `loop` 时，按起点推荐以下模式之一：
    - `scope → frame → loop(collect → analyze → challenge) max=3 → synthesize`
    - `scope → loop(collect → frame → analyze → challenge) max=3 → synthesize`
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
   ━━ 分析任务确认 ━━

   问题: {一句话总结}

   执行流程: {单行 stage 序列}

   开始？(yes / 想调整直接说)
  ```
   单行 stage 序列格式：
  - 顺序段：`stageA → stageB → ...`
  - 循环段：`loop(stageX → stageY → ...) max=N`
  - 并行段：`parallel(stageX → stageY)`
  - 混合：`scope → loop(collect → analyze → challenge) max=3 → synthesize`
  - stage 用英文名（scope / collect / frame / analyze / challenge / synthesize / reflect）
6. 展示模板，输出后暂停，等待用户回复：
  - yes / 确认 / ok → 进 §4.2；调整记录保留在内存，供 `§4.4` 写入 finalize
  - 调整 stage（如“加 challenge”“不用 reflect”）或调整流程（如“开补证循环”“并行分析三个方案”“先 collect 再 scope”）→ 重新渲染确认模板

#### few shot 示例

```
[示例 1: 快速判断]

━━ 分析任务确认 ━━

问题: 判断这份事故说明里根因是否充分

执行流程: collect → analyze → challenge → synthesize

开始？(yes / 想调整直接说)
```

```
[示例 2: 常规调研]

━━ 分析任务确认 ━━

问题: 分析是否应该把内部文档管线拆成独立模块

执行流程: scope → collect → frame → analyze → challenge → synthesize

开始？(yes / 想调整直接说)
```

```
[示例 3: 证据不足，需要迭代补证]

━━ 分析任务确认 ━━

问题: 找出最近导出失败率升高的可能原因

执行流程: scope → frame → loop(collect → analyze → challenge) max=3 → synthesize → reflect

开始？(yes / 想调整直接说)
```

### 4.2 创建归档

目标：建立 sprint handoff 文件，写入元数据。

步骤：

1. 在 `$SPRINT_DIR` 下创建 `$SPRINT_SID.md`，内容按 [templates/handoff.md](./templates/handoff.md) 的初始化结构写入。
2. 写入以下字段：
  - `id`：`$SPRINT_SID`
  - `type`：固定写 `sprint-for-analysis`
  - `desc`：用户输入 desc 原文
  - `sequence`：本次 sprint 的完整真实执行语法
  - `created`：当前 UTC ISO8601 时刻
3. 按 handoff 模板的 `SECTION: finalize` 默认结构创建 `Finalize` 内容块：
  - `status`：写 `running`
  - `completed_at`：保持空值
  - `insight.sequence_adjust_reason`：有调整时写 1 句话，格式固定为 `"<动作> — <理由>"`；无调整时不写
4. 创建成功后告知用户：
  ```
   归档建立完毕，分析开始。
  ```
5. 进 §4.3。

### 4.3 执行 stages

目标：按 §4.1 流程编排逐个跑 stage，写 handoff。

#### 用户提示协议

- 进入任一 stage 前，先用 1-2 句话告诉用户当前 stage 要做什么、为什么做。
- 如果 stage 会读取文件、看日志、查 git 历史、web search、扩大材料来源或引入新判断口径，先说明目的、范围和不会触碰的边界。
- 执行中一旦触发“回合边界”，立即停止当前流程，向用户给出候选项 / 影响 / 建议默认项；输出后暂停，等待用户回复；确认后从暂停点继续。
- stage 完成时，如果产出会影响后续分析方向（范围契约、证据缺口、分析框架、反证结果、最终建议偏向），先展示摘要给用户确认；输出后暂停，等待用户回复；确认后再进入下一个 stage。

#### 步骤

1. 读取 `sequence`，按 `→` 拆出顶层 token，从左到右执行。
2. 执行普通 stage：
  - 整体更新 `Runtime` 内容块，把 `cursor` 改为当前 stage 名，清空 `loop.active`，保持 `parallel.completed` 当前值
  - 按当前 stage 文件执行：
    - **scope** — [./stages/scope.md](./stages/scope.md)
    - **collect** — [./stages/collect.md](./stages/collect.md)
    - **frame** — [./stages/frame.md](./stages/frame.md)
    - **analyze** — [./stages/analyze.md](./stages/analyze.md)
    - **challenge** — [./stages/challenge.md](./stages/challenge.md)
    - **synthesize** — [./stages/synthesize.md](./stages/synthesize.md)
    - **reflect** — [./stages/reflect.md](./stages/reflect.md)
  - stage 完成后，把本 stage 内容追加到 [templates/handoff.md](./templates/handoff.md) 的 `SECTION: stages`
3. 执行 `loop(...)`：
  - `cursor` 写 `loop()`，按 `loop(...) max=N` 读取内部序列和最大轮次
  - 每进入一个内部 stage，更新 `loop.active`
  - 每轮结束由 `challenge` 或 loop 内最后一个 stage 判断是否足以进入综合：证据是否覆盖关键问题、替代解释是否已处理、置信度是否可接受
  - 不足且 `round < max` 时继续下一轮；达到 max 仍不足时停止后续 token，进入 §4.4 并把状态写成 `aborted` 或 `completed_with_limits`
4. 执行 `parallel(...)`：
  - `cursor` 写 `parallel()`，`parallel.completed` 重置为 `[]`
  - 从前一个 stage 的正文读取分析轨道列表；每个轨道必须有唯一名称、问题、材料来源和输出要求
  - 每个轨道执行 `parallel(...)` 内定义的 stage 序列；完成后把轨道名加入 `parallel.completed`
  - 全部轨道完成后清空 `parallel.completed`，继续后续 token
5. `sequence` 全部执行完后进入 §4.4。

不支持嵌套 `loop`、嵌套 `parallel`、同一层混用 `loop` 和 `parallel`、goto。

### 4.4 收尾

目标：标记 sprint 结束，输出汇总。

步骤：

1. 读 handoff，解析 frontmatter `created` + 各章节 `<!-- ts: {...} -->`。
2. 算 per-section 耗时：
  - 第 1 章节：dur = section[1].ts - frontmatter.created
  - 第 i 章节 (i>1)：dur = section[i].ts - section[i-1].ts
3. 按 [templates/handoff.md](./templates/handoff.md) 的 `SECTION: finalize` 结构整体更新 `Finalize` 内容块，写入：
  - `STATUS=completed`；证据不足但仍能交付时写 `completed_with_limits`；无法回答核心问题时写 `aborted`
  - `COMPLETED_AT={now ISO8601}`
  - `SEQUENCE_ADJUST_REASON={沿用 handoff 现有值}`
  - `INSIGHT_BODY={关键限制、后续机会、分析方法复盘；无则留空}`
4. 按以下模板输出给用户：
  ```
   ━━ Analysis Sprint 完成 ━━
   ID:   {SPRINT_SID}
   归档: $SPRINT_DIR/$SPRINT_SID.md

   stage 耗时：
   {N}. {stage 名}    {耗时}
   ...
   total              {总耗时}
  ```
