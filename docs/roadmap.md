# Sprint v2 Product Roadmap

## 1. Product Vision

### Product Essence

- **Positioning**: 面向 AI 协作任务（编程 / 创作 / 分析等）的工作流引擎——原子 stage 通过轻量编排组合
- **Motivation**: sprint v1 是绑死编程任务的线性流水线，stage 与"评估 / anchor / 文件改动"等编程预设耦合；做非编程任务（如长文创作）只能另起 skill（article、article-v2），stage 模型不互通，改进无法跨场景迁移
- **Long-term vision**: sprint 成为人机协作的工作流协议层——任何任务类（编程 / 创作 / 分析 / 调研 / ...）都能用一组 stage 配方表达，新增场景 = 写新配方，而不是建新 skill

### Value System


| Tier                 | Value                                           | Metric                                                                                 |
| -------------------- | ----------------------------------------------- | -------------------------------------------------------------------------------------- |
| **Immediate value**  | 用户在编程外的协作任务上能复用同一组 stage 能力，不必为每类任务另建 skill     | 单个新场景配方的编写工时（target value, pending validation: <1 day）                                 |
| **Cumulative value** | 配方库随场景累积，stage 改进自动惠及所有依赖它的配方                   | 配方总数（target: v2.0=1，v2.1≥2，v2.x 持续增长）；单 stage 被复用配方数（target value, pending validation） |
| **Strategic value**  | 从"为每类 AI 协作任务造一个 skill"升级为"组合现有 stage 能力即得新协作流" | 新场景从设想到首次可用配方的时间（target value, pending validation: <1 week）                            |


### Core Problem


| Problem                                                 | Occurrence Frequency                                                            | Per-Occurrence Cost                                             | Reach      | Existing Workaround                                            |
| ------------------------------------------------------- | ------------------------------------------------------------------------------- | --------------------------------------------------------------- | ---------- | -------------------------------------------------------------- |
| 用户在非编程类 AI 协作任务（写文章 / 做分析）上无法套用 sprint 的流程感             | 每次启动非编程任务即遇到（estimated: 数次/周, based on 作者已有 article / article-v2 等独立 skill 的事实） | 每个新场景额外 1-3 天 skill 设计 + 后续维护分裂（estimated, not precisely timed） | 唯一用户（作者本人） | article / article-v2 等独立 skill；缺点：与 sprint 不共享 stage，改进无法跨场景迁移 |
| sprint v1 流程仅支持"顺序 + 跳过"，无法表达"循环写到达标"、"分支评估后选路"等真实控制流需求 | 已遇到（user confirmed：现实场景中已有需要编排的需求，但不到 DSL 复杂度）                                  | to be quantified（无系统化测量手段，作者凭感觉手动重跑或在描述里塞条件）                    | 唯一用户       | 手动重跑 sprint 或修改输入描述；无系统化方式                                     |


### Target Users


| Role                              | Typical Scenario                                                 | Before                                                                                 | After                                                      | Estimated Productivity Gain                                        |
| --------------------------------- | ---------------------------------------------------------------- | -------------------------------------------------------------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------ |
| Claude Code 上的个人重度 AI 协作用户（仅作者本人） | 在编程 / 创作 / 分析三类任务间频繁切换，希望同一套 sprint 心智模型覆盖；并且对部分任务存在"循环修订"等控制流需求 | 编程走 sprint，创作走 article / article-v2，分析无标准化流程；改进无法跨场景迁移（estimated, not precisely timed） | 所有任务在 v2 sprint 下用配方表达；改一个 stage 全场景受益（pending validation） | pending validation (expected: 新场景启动从 1-3 天 skill 设计降至 <1 day 配方编写) |


### Competitive Comparison


| Solution             | Positioning                                               | Target Users | Core Features                                                                   | Strengths                  | Limitations                                   |
| -------------------- | --------------------------------------------------------- | ------------ | ------------------------------------------------------------------------------- | -------------------------- | --------------------------------------------- |
| **sprint v2**        | 面向 AI 协作任务的工作流引擎                                          | 个人重度 AI 协作用户 | 原子 stage、配方组合、控制流（顺序/条件/循环）、多场景覆盖                                               | 同一抽象覆盖编程 + 非编程；v1 数据层零成本复用 | 仍处 roadmap 阶段，原子化 + 编排尚未实施                    |
| sprint v1            | 编程任务的多阶段流水线                                               | 个人重度 AI 协作用户 | brainstorm / design / plan / execute / review / insight 线性流水线、handoff、anchor 校验 | 编程场景成熟稳定；handoff 与评估机制完善   | 流程线性、stage 不可独立调用、无法服务非编程场景                   |
| article / article-v2 | 中文长文创作的 5 步质量流（spark → angle → evidence → voice → revise） | 同上           | 内置硬 Gate、对抗性修订、专为长文设计                                                           | 写作场景效果好，与 sprint v1 互补     | 与 sprint 不共享 stage，改进无法跨场景迁移；不支持"循环写到达标"控制流抽象 |


## 2. Version Plan

### Version Summary Table


| Version | Core Direction               | Core-Metric Delta | Status   | Period | Milestones |
| ------- | ---------------------------- | ----------------- | -------- | ------ | ---------- |
| v2.0    | 落地原子 stage + 编排能力 + 编程配方等价迁移 | TBD               | planning | TBD    | M1-M3      |
| v2.1    | 落地首个非编程配方 + v1 痛点修复          | TBD               | planning | TBD    | M4-M5      |
| v2.x    | 高级控制流（并行 / 跳转）+ 其他场景配方       | TBD               | planning | TBD    | M6+        |


### Version Details

#### v2.0 — atomic foundation

- **Strategic intent**: 把 v1 的隐式线性流水线显式化为"原子 stage + 编排"，奠定后续多场景的基础抽象；与产品愿景对应：先证明同一组 stage 能在不同流程中独立调用
- **Input/output**: invest TBD（个人空闲时间，未估算）→ expected v1 编程任务可用 v2 等价复跑（VG4 验收通过）
- **Priority rationale**: 不解锁原子化 + 编排，v2.1 多场景配方无处依附；v2.x 控制流扩展也无前置；无外部依赖，可立即启动
- **Risks and dependencies**: 依赖 v1 数据层（sprint-ctl / state.json / handoff 目录）保持稳定；风险：原子化定义可能遗漏 v1 隐式上下文依赖（如 brainstorm 6 槽位假设）需回滚补救
- **Success metric**: 至少 3 个原 stage 完成原子化改造可独立调用；可用配方表达"顺序 / 条件 / 循环"三种控制流；v1 编程任务用 v2 复跑且 handoff 内容差异在可解释范围内
- **Core value**:
  1. 首次可用统一抽象描述 sprint 流程，不再绑定线性次序
  2. 首次可用配方表达控制流（条件 / 循环），不依赖手动重跑
  3. v1 全部能力等价保留，无能力退化
- **User coverage**: author dogfood
- **Core metric** (v1 → v2.0):


| Metric         | v1  | v2.0                   | Delta        | Source                           |
| -------------- | --- | ---------------------- | ------------ | -------------------------------- |
| 原子化 stage 数    | 0   | target ≥3              | new baseline | target value, pending validation |
| 配方数            | 0   | target 1（编程）           | new baseline | target value, pending validation |
| 控制流原语支持        | 0   | target 3（顺序 / 条件 / 循环） | new baseline | target value, pending validation |
| v1 编程任务等价回归通过率 | n/a | target 100%            | new baseline | target value, pending validation |


#### v2.1 — multi-scenario validation

- **Strategic intent**: 验证 v2 抽象在非编程场景的存在性（VG3），同时借此次升级一次性消化 v1 用着卡的具体痛点（VG5）；与 v2.0 的关系：检验抽象是否真的泛化
- **Input/output**: invest TBD → expected 至少 1 个非编程配方端到端跑通真实任务 + 痛点清单逐条修复
- **Priority rationale**: v2.0 通过验收后是检验抽象的唯一方式；不验证就只是改了个 v1；痛点修复借此次升级一次性完成，避免后续返工
- **Risks and dependencies**: 依赖 v2.0 验收通过；风险：实际跑非编程配方时可能发现 v2.0 抽象缺漏（需回滚到 v2.0 修补，影响排期）
- **Success metric**: 1 个非编程配方端到端跑通 1 个真实任务（创作 或 分析二选一）；痛点清单 ≥3 条，每条对应一行可验证修复标准且全部完成
- **Core value**:
  1. 首次可用 sprint 服务非编程任务
  2. v1 痛点借升级一次性消化，避免长期累积
- **User coverage**: author dogfood
- **Core metric** (v2.0 → v2.1):


| Metric         | v2.0 | v2.1      | Delta        | Source                           |
| -------------- | ---- | --------- | ------------ | -------------------------------- |
| 非编程配方数         | 0    | target ≥1 | new baseline | target value, pending validation |
| 痛点修复条数         | 0    | target ≥3 | new baseline | target value, pending validation |
| 端到端真实任务覆盖（非编程） | 0    | target ≥1 | new baseline | target value, pending validation |


#### v2.x — extension

- **Strategic intent**: 按 v2.0 / v2.1 落地后的实际反馈推进高级控制流（并行 / 跳转）和其他场景配方；显式不预设内容以避免长期承诺过度
- **Input/output**: invest TBD → expected TBD（按需启动）
- **Priority rationale**: 无前置紧迫性；v2.1 落地前任何 v2.x 决策都是猜测；不锁内容反而保留灵活度
- **Risks and dependencies**: no identified risks or external dependencies
- **Success metric**: 启动时基于 v2.1 实际反馈定义（roadmap 不预先锁定）
- **Core value**: TBD（按 v2.1 反馈扩展）
- **User coverage**: author dogfood
- **Core metric** (v2.1 → v2.x):


| Metric            | v2.1          | v2.x       | Delta | Source                           |
| ----------------- | ------------- | ---------- | ----- | -------------------------------- |
| 高级控制流（并行 / 跳转）支持数 | 0             | target TBD | —     | target value, pending validation |
| 累计配方数             | ≥2            | target TBD | —     | target value, pending validation |
| 累计场景覆盖类数          | 2（编程 + 1 非编程） | target TBD | —     | target value, pending validation |


## 3. Milestones


| #                           | Core Direction                             | Goal Achievement | Status      | Completion Date |
| --------------------------- | ------------------------------------------ | ---------------- | ----------- | --------------- |
| [M1](docs/milestones/m1.md) | 完成原子 stage 实现规范的设计与立项                      | —                | not started | —               |
| [M2](docs/milestones/m2.md) | 实现编排能力（顺序 / 条件 / 循环三种控制流原语）                | —                | not started | —               |
| [M3](docs/milestones/m3.md) | 完成编程配方等价迁移并通过 v1 回归证明                      | —                | not started | —               |
| [M4](docs/milestones/m4.md) | 落地首个非编程配方（创作或分析）并跑通 1 个真实任务                | —                | not started | —               |
| [M5](docs/milestones/m5.md) | 收集 v1 痛点清单并逐条完成修复                          | —                | not started | —               |
| [M6](docs/milestones/m6.md) | 启动 v2.x 扩展（高级控制流 / 其他场景配方），具体内容按 v2.1 反馈定义 | —                | not started | —               |


