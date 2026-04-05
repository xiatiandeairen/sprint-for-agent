---

## name: entry

description: Sprint 统一入口。评估 → 创建 → 执行流水线

# Sprint Entry

---

# 一、参数解析


| 输入 | 行为 |
|------|------|
| 无参数 | `sprint-ctl.sh list` 展示未完成和停止的 sprint |
| `simple`/`medium`/`complex`/`long`/`auto` + 描述 | 用户指定任务类型，跳过评估 |
| 恢复指定 sprint | `sprint-ctl.sh activate {id}` 恢复 |
| 其他 | 评估 -> 确认 -> 创建 -> 执行 |


---

# 二、任务评估

快速扫描相关代码后，逐个阶段判断是否需要，从阶段组合反推任务类型。

## 2.1 阶段必要性评估

快速扫描任务相关的代码/文档/上下文后，从三个抽象维度评估每个阶段是否需要：

### 评估维度

| 维度 | 含义 | 低 | 高 |
|------|------|-----|-----|
| **信息密度** | 理解任务需要掌握多少上下文 | 一看就懂 | 需要读多个文件/系统才能理解全貌 |
| **决策密度** | 任务中需要做多少个独立决策 | 路径唯一，无需选择 | 多个互相影响的决策点 |
| **不确定性** | 做之前能否预见结果 | 做什么、怎么做、做成什么样都明确 | 需要探索才知道方向 |

### 阶段触发规则

| 阶段 | 什么时候需要 | 什么时候不需要 |
|------|------------|------------|
| brainstorm | 不确定性高：需求模糊，多种理解方式，用户自己也不确定要什么 | 用户明确说了要做什么且能具象化 |
| research | 决策密度高：有 >= 2 种可行路径需要对比；涉及没用过的技术/模式 | 做法唯一且明确；有完全相同的先例 |
| design | 信息密度高 + 决策密度高：涉及多个组件/模块的结构变更；需要前置确定接口/边界 | 单一组件内部改动，不影响其他部分 |
| plan | 信息密度中+：任务需要拆步骤（多文件/多决策/多依赖） | 一步能做完的事 |
| execute | 有东西需要产出（代码/文档/配置） | -- |
| quality | 改动影响面广：涉及多个文件/模块；改了已有逻辑 | 新增独立内容，不影响已有部分 |
| review | 信息密度高：改动涉及复杂逻辑或架构决策，需要讲解才能理解 | 改动一目了然 |
| insight | 始终需要 | -- |

### 快速判定

不确定时问自己：
- 「不 brainstorm 会不会做错方向？」 -> 会则需要
- 「不 research 会不会选错方案？」 -> 会则需要
- 「不 design 会不会后期重构？」 -> 会则需要
- 「不 plan 会不会中途卡住？」 -> 会则需要

## 2.2 类型判定

从需要的阶段组合反推类型：

| 判定 | 条件 | 流水线 |
|------|------|--------|
| 判定 | 条件 | 流水线 |
| 不走 sprint | plan 不需要（一步能完成，信息密度低，决策密度低） | 直接执行 |
| simple | 需要 plan + execute，不需要 research 和 design | plan -> execute -> [quality] -> insight |
| medium | 需要 design 或 research | [research] -> [design] -> plan -> execute -> [quality] -> insight |
| complex | 需要 brainstorm（不确定性高）| brainstorm -> research -> design -> plan -> execute -> quality -> review -> insight |
| long | 用户指定 `/sprint long` 或方向性描述（无具体需求） | 不走常规流水线，执行 `stages/long.md` |

方括号表示按 2.1 判断可能需要也可能不需要。long 类型跳过 2.1 评估，直接路由到 `stages/long.md` 执行三阶段循环。

## 2.3 输出与确认 [GATE:must]

不走 sprint 时直接执行：

```
[评估] {描述}
   判定: 直接执行（不需要 sprint 流水线）
   原因: {如「单文件修改，< 50 行，做法明确」}
```

走 sprint 时输出评估清单，等用户确认：

```
[评估] {描述}
   类型: medium

   阶段评估:
     brainstorm -- 需要（1 must + 1 decide + 1 review）
     research   -- 需要（1 decide + 1 review）
     plan       -- 需要（1 must）
     execute    -- 需要（1 review）
     insight    -- 需要（1 must）

   流水线: brainstorm -> research -> plan -> execute -> insight
   跳过: design, quality, review
   gate 统计: 3 must / 2 decide / 3 review

   执行模式: step-by-step
   （decide 密集，含 brainstorm + research 决策阶段）
   如需调整为 auto 请说明

   [ok] 确认 / [调整] 调整
```

模式判定规则：
- 流水线中 decide gate 占比 > 40% 或含 brainstorm 阶段 -> 默认 step-by-step
- 否则 -> 默认 auto
- 拿不准 -> 标注两个选项让用户选

每个阶段的「需要/不需要」都给出一句话理由，用户可以逐条调整。确认后才创建 sprint。

---

# 三、Sprint 生命周期

## 3.1 状态机

```
created ──→ running ──→ completed ──→ archived
               │
               ├──→ failed ──→ retrying ──┬──→ running（成功）
               │       │                  └──→ failed（失败）
               │       └──→ (abandon) ──→ archived
               │
               └──→ stopped（超时自动检测）──→ running（用户恢复）
```

状态说明：


| 状态        | 含义                      |
| --------- | ----------------------- |
| created   | 类型已确认，等待启动              |
| running   | 流水线执行中                  |
| failed    | 阶段失败，等待用户介入             |
| retrying  | 用户修复后重试中                |
| stopped   | running 超时未活动，自动标记      |
| completed | 所有 required 阶段完成        |
| archived  | 归档（completed/abandoned） |


## 3.2 状态转换


| 从         | 到         | 触发条件                  | 前置动作                                         | 执行命令                                        |
| --------- | --------- | --------------------- | -------------------------------------------- | ------------------------------------------- |
| --        | created   | `/sprint <描述>` + 类型确认 | 评估类型，确认流水线阶段                                 | `sprint-ctl.sh create {id} {type} "{desc}"` |
| created   | running   | 流水线开始执行第一个阶段          | 确认本地无其他变更，记录 base_commit，初始化阶段列表，输出信息提示，见3.3 | `sprint-ctl.sh activate {id}`               |
| running   | completed | 所有 required 阶段完成      | 输出信息提示，见3.4                                  | `sprint-ctl.sh end {id}`                    |
| running   | failed    | 阶段失败，重试耗尽             | 输出信息提示，见3.5                                  | `sprint-ctl.sh fail {id} "{reason}"`        |
| running   | stopped   | 超时检测（见 3.6）           | 保存当前阶段进度                                     | `sprint-ctl.sh stop {id}`                   |
| failed    | retrying  | 用户选择重试                | 确认用户已修复问题                                    | `sprint-ctl.sh retry {id}`                  |
| retrying  | running   | 重试阶段执行成功              | --                                           | `sprint-ctl.sh activate {id}`               |
| retrying  | failed    | 重试阶段执行失败              | 记录重试次数 +1                                    | `sprint-ctl.sh fail {id} "{reason}"`        |
| failed    | archived  | 用户执行 abandon          | 二次确认，`git revert` 到 base_commit              | `sprint-ctl.sh abandon {id}`                |
| stopped   | running   | 用户恢复                  | 读取上次阶段进度                                     | `sprint-ctl.sh activate {id}`               |
| completed | archived  | 手动 / 7 天自动            | 压缩产出文件                                       | `sprint-ctl.sh archive {id}`                |


## 3.3 启动提示 [SOFT-GATE]

sprint 创建并激活后输出，不等用户响应直接进入流水线：

```
[启动] Sprint #{id} 启动
   描述: {desc}
   类型: medium（总分 14/36）
   执行模式: 自动 / 逐步
   流水线: brainstorm -> research -> plan -> execute(checked) -> quality -> insight
   跳过: design, review
   并发: 当前活跃 2 个 sprint
   base_commit: {short_hash}
```

## 3.4 完成提示 [SOFT-GATE]

```
[ok] Sprint #{id} 完成
   类型: medium
   完成: research [ok] plan [ok] execute [ok] quality [ok] insight [ok]
   跳过: brainstorm, design
   Chunks: 5 完成 | Diff: 320 行
   耗时: 约 25 分钟
```

## 3.5 失败提示 [HARD-GATE]

阶段失败且重试耗尽后，sprint 标记 failed，必须等用户介入：

```
[FAIL] Sprint #{id} 需要介入
   阶段: execute | 步骤: step4 (gate)
   原因: {错误信息}
   已完成: research [ok] plan [ok] execute:chunk2 [ok]
   失败点: execute:chunk3:step4
```

根据用户输入的上下文判断下一步：


| 用户意图    | 动作                      | 命令                                  |
| ------- | ----------------------- | ----------------------------------- |
| 修复后继续   | retrying → 从失败点继续       | `sprint-ctl.sh retry {id}`          |
| 跳过当前阶段  | 标记 skipped → 执行下一阶段     | `sprint-ctl.sh skip-stage {id}`     |
| 回退到上一阶段 | 重跑上一个阶段                 | `sprint-ctl.sh rollback-stage {id}` |
| 暂时不处理   | sprint → stopped        | `sprint-ctl.sh stop {id}`           |
| 放弃      | 二次确认 → revert → archive | `sprint-ctl.sh abandon {id}`        |


abandon 流程：

1. 用户二次确认
2. 记录原因到 state + journal
3. `git revert` 到 base_commit
4. 移入 `.sprint/archive/`

---

# 四、流水线

## 4.1 阶段定义


| 阶段         | 聚焦问题                     | 文件                     |
| ---------- | ------------------------ | ---------------------- |
| brainstorm | 做什么 — 发散需求，找核心价值         | `stages/brainstorm.md` |
| research   | 怎么做好 — 方案调研 + 决策         | `stages/research.md`   |
| design     | 做成什么样 — UI / 架构设计        | `stages/design.md`     |
| plan       | 怎么做成 — 落实方案细节            | `stages/plan.md`       |
| execute    | 怎么分配验收 — 任务拆分 + agent 执行 | `stages/execute.md`    |
| quality    | 有没有问题 — 质量保证             | `stages/quality.md`    |
| review     | 讲解复审 — 代码讲解 + 质量评价       | `stages/review.md`     |
| insight    | 做得怎么样 — 指标汇总 + 结束        | `stages/insight.md`    |


固定顺序：`brainstorm → research → design → plan → execute → quality → review → insight`

## 4.2 类型参数

阶段组合由 2.1 评估结果决定，不再固定映射。类型只决定默认参数：


| 类型          | plan 参数                                     | execute 参数                     |
| ----------- | ------------------------------------------- | ------------------------------ |
| simple      | anchor: lite, chunks_max: 3, budget: 100    | mode: auto, review: none       |
| medium      | anchor: full, budget: 150                   | mode: checked, review: sampled |
| complex     | anchor: full, budget: 150                   | mode: checked, review: every   |
| long        | 不走常规流水线，执行 stages/long.md 的三阶段循环 | max_rounds: 5, resume: true    |
| auto (TODO) | anchor: lite, budget: 100                   | mode: auto, trigger: cron      |


## 4.3 执行器

<HARD-RULE>
1. 每个 sprint-ctl.sh 命令必须用 Bash 工具真正执行，不是口头描述。
2. 每个阶段必须用 Read 工具读取 stages/{stage}.md，然后按步骤执行。
3. stage 文件中的 shell 命令也必须用 Bash 工具执行。
违反任何一条 = 流程无效。
</HARD-RULE>

插件根目录变量（后续命令中使用）：
```
SPRINT_PLUGIN="src/plugins/sprint"
```

### 创建 Sprint

用户确认评估后，用 Bash 工具执行：

```bash
# create 自动生成 ID，返回值中包含 ID
bash "$SPRINT_PLUGIN/scripts/sprint-ctl.sh" create "{type}" "{desc}" "{stages}"
# 从 create 输出中提取 ID，用于后续命令
bash "$SPRINT_PLUGIN/scripts/sprint-ctl.sh" activate "{id}"
```

输出启动提示（不等用户）。

**long 类型特殊处理**：long 类型不走下面的流水线循环，而是用 Read 工具读取 `stages/long.md`，按其 Phase 1-3 执行。

### 流水线循环（simple/medium/complex）

对每个 stage 依次执行：

**step 1** — 用 Bash 工具执行：
```bash
bash "$SPRINT_PLUGIN/scripts/sprint-ctl.sh" stage-update "{id}" "{stage}" running
```

**step 2** — brainstorm/research 跳过，其他阶段用 Bash 工具执行：
```bash
bash "$SPRINT_PLUGIN/scripts/sprint-ctl.sh" anchor-check "{id}"
```

**step 3** — optional 阶段处理：
- auto 模式 -> 按 2.1 判断结果自动决定
- sbs 模式 -> 展示建议，问用户是否跳过 [GATE:must]
- 跳过则用 Bash 工具执行：
```bash
bash "$SPRINT_PLUGIN/scripts/sprint-ctl.sh" skip-stage "{id}"
```

**step 4** — 用 Read 工具读取 `stages/{stage}.md`

**step 5** — 按 stage 文件的「步骤」段逐步执行：
- 每个 Step 按「怎么做」执行，按「完成标志」验证
- stage 文件中的 shell 命令用 Bash 工具执行
- 遇到 gate 按模式处理：
  - `[GATE:must]` -> 输出内容，等待用户（两种模式一致）
  - `[GATE:decide]` -> auto: AI 高置信则 "[自动决策] {结论}" 继续，低置信等用户 / sbs: 等用户
  - `[GATE:review]` -> auto: "[自动通过] {摘要}" 继续 / sbs: 等用户
- scope 外发现 -> 追加 observations.md
- 超时(30分钟) -> 执行 `sprint-ctl.sh stop "{id}"`，退出

**step 6** — 失败时读 stage 文件的「排查指南」尝试处理。无法恢复则用 Bash 工具执行：
```bash
bash "$SPRINT_PLUGIN/scripts/sprint-ctl.sh" fail "{id}" "{reason}"
```
输出失败提示 [GATE:must] -> 用户介入（见 3.5）

**step 7** — 按 stage 文件的「验证清单」逐条检查，任一失败则回到 step 6

**step 8** — 用 Bash 工具执行：
```bash
bash "$SPRINT_PLUGIN/scripts/sprint-ctl.sh" verify "{id}"
```
PASS 继续，FAIL 回到 step 6

**step 9** — 用 Bash 工具执行：
```bash
bash "$SPRINT_PLUGIN/scripts/sprint-ctl.sh" stage-update "{id}" "{stage}" completed
bash "$SPRINT_PLUGIN/scripts/sprint-ctl.sh" log-event "{id}" "stage_completed" "{stage}"
```

### 完成

所有阶段完成后，用 Bash 工具执行：
```bash
bash "$SPRINT_PLUGIN/scripts/sprint-ctl.sh" end "{id}"
```
输出完成提示。

## 4.4 数据流

产出在 `.sprint/active/{id}/` 下，按消费方组织：

```
.sprint/active/{id}/
├── anchors/               # 约束层 — 后续阶段对照检查
│   ├── brainstorm.md      #   需求边界 / 排除 / 成功标准
│   ├── research.md        #   技术约束 / 方案决策
│   ├── design.md          #   结构约束 / 接口契约
│   └── plan.md            #   Intent Anchor（invariants / boundaries / baselines）
│
├── handoffs/              # 交接层 — 阶段间传递
│   ├── brainstorm.md      #   需求点 + 验收标准 -> research/design
│   ├── research.md        #   方案决策 + 佐证 -> design
│   ├── design.md          #   文件结构 + 接口 + 约束 -> plan
│   └── plan-chunks.md     #   Chunk Plan -> execute
│
├── reports/               # 汇报层 — 给人看的摘要
│   ├── brainstorm.md      #   结论 + 例子 + scope
│   ├── quality.md         #   质量报告
│   ├── review.md          #   代码讲解 + 评价
│   └── insight.md         #   指标汇总
│
├── execute/               # 执行层 — execute 阶段运行时产出
│   └── observations.md    #   scope 外发现
│
└── tmp/                   # 临时文件
```

指标数据（chunks/gates/baselines/events）全部在 DB 中。

消费规则:
- 人看 `reports/` — 一个目录扫完
- 执行器检查 `anchors/` — anchor-check 扫这个目录
- stage 读上游产出看 `handoffs/` — 不用猜路径


---

# 五、用户介入

sprint 进入 failed 或 stopped 状态后，等待用户介入。根据用户输入的上下文判断动作：


| 意图  | 动作                             | 说明                        |
| --- | ------------------------------ | ------------------------- |
| 继续  | `sprint-ctl.sh retry/activate` | 从未完成的阶段/步骤继续              |
| 跳过  | `sprint-ctl.sh skip-stage`     | 跳过当前阶段，执行下一个              |
| 回退  | `sprint-ctl.sh rollback-stage` | 回到上一阶段重跑                  |
| 暂停  | `sprint-ctl.sh stop`           | 标记 stopped，稍后处理           |
| 放弃  | `sprint-ctl.sh abandon`        | 二次确认 → revert → archive   |
| 改方向 | `sprint-ctl.sh pivot {id}`     | 更新 anchor/chunks → 当前阶段继续 |


