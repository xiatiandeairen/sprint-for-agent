# review

## Progress

- total: 6
- steps:
  1. What changed and why?
  2. Five-layer analysis
  3. Governance opportunities
  4. Here's what I found
  5. Record review results
  6. Your call

变更治理引擎。不是代码风格评审器，不是正确性复检器。判定设计决策、结构质量、模式扩散、长期维护成本以及自动化机会。

**定位**：execute 已经覆盖任务级测试和功能验证。review 回答的是：本次变更是否拉低了整体质量、扩散了坏模式、或漏掉了高 ROI 的治理机会？

**第一性原理**：以未来修改成本判断问题价值，不依赖个人偏好。

一个问题值得标记，必须满足以下之一：
- 增加未来理解成本
- 增加未来修改成本
- 增加未来出错概率
- 破坏代码库一致性
- 复制或扩散坏模式
- 遮蔽真实领域模型 / 设计边界
- 存在高 ROI 治理机会（autofix/codemod/规则）

低优先级（不强调）：主观风格偏好、低价值命名争议、不影响长期演化的小瑕疵、更适合 formatter/linter 处理的问题、无证据的猜测。

## 1. 硬规则

1. 不重复 execute 的功能验证。例外：实现明显属于"通过规避真实问题来过测试"
2. 不标记变更文件及其直接依赖之外的问题
3. 不输出逐文件逐行的点评。按层分析，不按文件分析
4. 不强行凑 finding。"该层无问题"是合法输出
5. 不把用户要求的变更归类为问题。变更请求是中性的
6. 每个 finding 必须使用 12 字段问题模板。不允许自由格式吐槽
7. 优先少量高杠杆 finding，而非大量低价值观察

## 2. 输入

- execute handoff：已完成任务、变更文件、测试范围
- design handoff（若存在）：Decision Register、File Structure
- plan handoff（若存在）：任务拆分、anchors
- `git diff {base_commit}`

---

## 3. Trigger

满足任一即运行 review：

- risk=yes（来自 evaluate）
- 任务数 >1 且存在跨模块变更（从 plan handoff 检测）

## 4. Depth Selection

Model: sonnet

Trigger 触发后，进入 Step 0 之前先确定 review 深度。

**变更类型自动检测（Change-type detection）**：

| 变更类型 | 检测规则 | 推荐深度 |
|-------------|---------------|-------------------|
| delete-migrate | plan handoff 包含 delete 任务，或 `git diff` 净负且包含文件删除 | quick |
| add-feature-single-module | 单个模块目录内的净正向行数 | quick（用户可升级到 full） |
| refactor-structural | 变更跨 >1 个模块，或触及架构/接口文件 | **full（强制）** |

呈现推荐：

```
Depth recommendation: {quick | full}
Change type detected: {delete-migrate | add-feature-single-module | refactor-structural}
Reason: {one-line evidence}

Options:
A) Accept recommendation
B) Override to {full | quick}  (only available for add-feature-single-module; refactor-structural locks to full)
```

选定的深度作为 Step 2 的分支开关。

## 5. Step 0: 跨任务回归

Model: sonnet

Gate (auto): plan handoff 任务数 >1 且任务间有共享文件或模块依赖 → 执行。否则跳过。

不要重复 execute 中的单任务检查。仅验证跨任务集成：

1. **公开接口变更** — 对每个变更的 API/protocol/type，识别消费方模块
2. **新增依赖** — 验证依赖图无环，下层模块不依赖上层
3. **删除 / 重命名** — 扫描残留引用

```
### Cross-Task Regression — PASS ✓ / FAIL ✗

**变更影响分析**
- 接口变更: {affected consumers or "无"}
- 依赖方向: ✓ / 发现违规
- 残留引用: 无 / {list}
```

Fail → 退回 execute 修复。Pass → 继续 Step 1。

## 6. Step 1: 变更理解

Model: opus

Gate (auto): execute handoff 中 completed tasks >0 → 执行。否则跳过整个 review。

读取 execute handoff + design handoff（若存在）+ git diff。建立心智模型：

```
## A. Change Understanding

- **Problem**: {what this change solves}
- **Approach**: {main design/implementation strategy}
- **Key decision points**: {where alternatives existed and choices were made}
- **Review focus**: {which areas deserve deepest scrutiny and why}
```

不要逐行阅读代码。理解意图、策略和决策点。

## 7. Step 2: 五层分析

Model: opus

**深度分支**（来自 Depth Selection）：

- 若 depth = quick：仅运行 L1 和 L4。跳过 L2、L3、L5。
- 若 depth = full：按文档运行 L1 到 L5。

核心分析引擎。按顺序处理适用的层。每层有特定检查项。仅报告实质性 finding —— 无可标记内容的层直接跳过。

### L1: Task-Level Residual Risk

基线安全网。不重复 execute 的工作。仅当实现明显脆弱时才标记。

**检查项**：

| Check | 关注什么 | 何时标记 |
|-------|-----------------|-----------|
| Happy-path-only | 错误/失败路径未处理 | 新公开函数没有错误返回或 catch |
| Test-passing fragility | 实现是为了过测试，而非解决问题 | 测试断言依赖实现细节（mock 调用次数、内部状态）而非行为 |
| Hardcoded constraints | 关键限制或阈值写死在代码里 | 应当可配置或可推导的 magic number |
| Mock concealment | mock 掩盖真实集成问题 | mock 无条件返回成功；没有针对真实依赖的测试 |
| Uncovered boundaries | 明显的边界 case 缺失 | 空输入、零、nil、最大值、并发访问 —— 一个都没测 |

**执行**：扫描变更的公开函数及其测试。逐函数检查：错误路径是否存在？测试是否覆盖 >1 条路径？mock 是否真实？

若无发现 → "L1: 无残留风险"。在此层投入不超过 review 总精力的 10%。

### L2: Code Decision Quality

**重点层**。判定每个代码决策是否为最简正确选择，或引入了偶然复杂度。

**检查项**：

| Check | 关注什么 | 何时标记 |
|-------|-----------------|-----------|
| Wrong abstraction | 模式与问题形态不匹配 | 仅 2 个固定 case 用了 strategy 模式；适合组合的地方用了继承 |
| Unnecessary indirection | 不增加价值的额外层/包装 | 1:1 委托给内层、只增加复杂度的 wrapper |
| One-off as interface | 临时逻辑被包装为可复用 API | 公开接口仅有 1 个调用方且看不到第二个 |
| Workaround as design | 局部修复伪装成通用方案 | 函数命名通用但只处理一个特定 case |
| False generalization | 看似可扩展实则更难修改 | 参数化代码，但每个"参数"实际上都硬编码为单一值 |
| Patch-on-patch | 旧代码绕开问题而非修复问题 | 在调用坏函数前加检查，而不是修复该函数 |

**执行**：对每个新增/修改的抽象（class、interface、module、有分量的函数）：
1. 数调用方。1 个调用方 + 通用名 → 怀疑 one-off-as-interface
2. 检查参数使用情况。所有参数永远取同一值 → 怀疑 false generalization
3. 检查修改是否触及根因，还是绕开根因加间接层 → patch-on-patch 信号

**关键问题**："如果另一个开发者 3 个月后要修改这里，当前结构是帮他还是阻碍他？"

### L3: Structural Quality

**重点层**。沿 7 条轴判定本次变更让代码库结构变好还是变差。

**检查项**：

| 轴 | Better signal | Worse signal | 检测方式 |
|------|--------------|--------------|---------------|
| Module boundaries | 模块职责更聚焦 | 模块开始处理不相关的关注点 | 检查模块新代码是否符合该模块声明/隐含目的 |
| Dependency direction | 依赖从高层 → 低层 | 低层模块 import 高层 | 跟踪变更文件的 import；画出依赖方向 |
| Data flow | 从源到消费方的跳数更少 | 数据经过多余中间层或被冗余转换 | 跨变更文件跟踪数据从起点到终点的路径 |
| State management | 状态归属更少、更清晰 | 新增共享可变状态，或归属不清 | 检查新增的 globals、singleton、shared ref，或无明确 owner 的状态 |
| Error handling | 错误策略与代码库约定一致 | 新错误模式偏离已有模式（如代码库用 Result 而新代码抛异常） | 拿变更文件的错误处理与同模块 2-3 个已有文件比对 |
| Interface conventions | 命名/签名遵循已有模式 | 新 API 破坏命名约定或参数风格 | 拿新增公开符号与同模块已有符号比对 |
| Coupling | 模块通过定义好的接口交互 | A 模块伸进 B 模块的内部 | 检查是否 import 内部/private 符号，或依赖另一模块的实现细节 |

**执行**：每条轴对比变更前（来自 git diff context）和变更后状态。打分：improved / unchanged / degraded。仅报告 degraded 的轴并附具体证据。

### L4: Pattern Layer

**最高价值层**。识别本次变更引入、扩散还是减少模式 —— 不只是单点问题。

**坏模式信号（Bad pattern signals）**：

| 信号 | 检测方式 | 例子 | 何时相关 |
|--------|-----------------|---------|---------------|
| Duplication growth | 同一逻辑在 >1 处出现，仅有微小差异 | 两个解析 config 的函数，字段列表略有差别 | any |
| Special-case proliferation | 为某个一次性场景加 if/switch 分支 | 通用 handler 里加 `if (type == "legacy_v2")` | modify-fn, refactor |
| Temp-compat permanence | 兼容代码没有 TODO / 过期时间 / 移除计划 | 没有版本检查或 deadline 的迁移 shim | add-api, modify-fn |
| Implicit protocol | 行为依赖未文档化的调用顺序或命名约定 | 函数必须在 init() 之后调用，但没有任何东西强制或说明 | add-api, refactor |
| Abstraction bypass | 代码绕过现有抽象直达底层 | 已有 repository 方法时直接调用 DB query | any |
| Config scatter | 常量/配置值散落在多个文件 | 同一个 timeout 在 3 个文件各定义一次 | add-api, modify-fn |
| Error style drift | 新错误处理与模块已有模式不一致 | 用异常的模块里返回错误码 | add-api, modify-fn |
| Type boundary weakening | 类型变得更不具体（如 typed → any/object） | 参数从 `UserId` 改成 `string` | add-api, modify-fn |
| Shared mutable state growth | 新增 globals、singleton 或未保护的共享变更 | 模块级变量被多个函数修改 | add-api, modify-fn |
| Debt replication | 已知坏模式被复制到新代码 | 新代码沿用了 legacy 模块的同款 anti-pattern | add-api, modify-fn |
| Name-semantics decoupling | 名字暗示 X，实现做的是 Y | `validateInput()` 同时做了转换和持久化 | add-api |
| Layer violation | 领域逻辑放错了架构层 | 业务规则写在 HTTP handler 或 UI 组件里 | add-api, refactor |

**好模式信号（Good pattern signals）**：

| 信号 | 检测方式 | 例子 | 何时相关 |
|--------|-----------------|---------|---------------|
| Abstraction convergence | 多种 ad-hoc 方式被统一为一种 | 3 个不同的 date parser 被替换为单个工具 | refactor |
| Interface clarity | 变更后 API 语义更明确 | 模糊的 `process(data)` → `validateAndStore(order)` | add-api |
| Error handling unification | 多种错误策略收敛为一种 | 异常 / 错误码混用 → 一致的 Result 类型 | refactor, modify-fn |
| State boundary tightening | 共享状态减少或归属更清晰 | 全局 config 替换为注入的依赖 | refactor |
| Dependency direction fix | 低层不再 import 高层 | infrastructure 模块不再 import domain types | refactor, delete |
| Reuse centralization | 散落的重复整合到单一来源 | 4 份 retry 逻辑 → 共享 retry 工具 | refactor |
| Type/constraint strengthening | 类型变得更具体或带校验 | `string` → 带校验的 `EmailAddress` | add-api, modify-fn |
| Rule codification | 隐式约定变为显式且可检查 | 未文档化的顺序要求 → 编译期或运行时检查 | any |
| Special-case normalization | 一次性 hack 回归到通用模型 | 移除 `if legacy` 分支，legacy 数据迁移到标准格式 | modify-fn, refactor |

**信号过滤（按 Depth Selection）**：扫描前先过滤信号集 —— 仅保留 `Relevant when` 与检测到的 change-type 相交的信号（或为 `any` 的信号）。不匹配的信号完全省略，不渲染 `N/A` 占位。

**执行**：每个模式 finding 回答 4 个问题：
1. **Instance or systemic?** —— 这是单点出现，还是 grep 后能在别处找到同样的模式？
2. **Introduced or pre-existing?** —— 本次变更新建了该模式，还是复制/延伸了已有模式？
3. **Point fix or class fix?** —— 只修这一处，还是修所有同模式实例？
4. **Automatable?** —— 检测或修复能否机械化（AST/codemod/lint）？

### L5: Evolution Layer

战略性评估。判定本次变更对代码库走向的净效果。

**检查项**：

| 问题 | 如何回答 |
|----------|---------------|
| Net direction | 数 L3 退化轴 vs 改善轴。数 L4 坏信号 vs 好信号。多数决方向。 |
| Systemic opportunity | 任何 scope 为 "cross-module-systemic" 的 L4 坏信号 → 系统性治理机会 |
| New rule candidate | 任何检测可机械化且出现 ≥2 次的 finding → lint/check 候选 |
| New convention candidate | 任何"正确"做法清晰但未文档化的 finding → 团队规约候选 |

**Net evolution judgment**：improvement / neutral / degradation。必须用一句话陈述理由，引用 L3/L4 的具体证据。

### Problem Template

每个值得标记的 finding 产出以下结构：

```
### {title: one sentence describing the problem essence}

- **Layer**: L1 / L2 / L3 / L4 / L5
- **Severity**: blocking / important / opportunistic
- **Observation**: {what was concretely observed}
- **Essence**: {why this is not a surface issue — what decision/structure/pattern problem it reflects}
- **Impact**: {how it increases future modification cost, complexity, or error rate}
- **Scope**: local / same-module-same-class / cross-module-systemic
- **Action**: fix_now / autofix_now / codemod_candidate / rule_candidate / defer_with_reason / ignore_with_reason
- **Fix**: {concrete executable modification suggestion}
- **Spread fix**: yes / no
- **Spread boundary** (if yes): current file / current module / same abstraction layer / whole project
- **Spread risk** (if yes): {what could go wrong with spread fix}
- **Automation**: not automatable / local autofix / codemod-AST / lint rule-static check-test guard
```

**fewshot**:

Good：
```
### parseAnchor 函数缺失 unknown rule 错误处理

- **Layer**: L1
- **Severity**: important
- **Observation**: scripts/anchor-check.sh 第 240 行 case 语句无 default 分支；非 9 类规则的行被静默跳过
- **Essence**: 失败模式被吞没（不报告"未识别的 rule"），让脏数据 anchor 假装 PASS
- **Impact**: 用户增改 anchors.txt 拼错 rule 名时无 feedback
- **Scope**: local
- **Action**: fix_now
- **Fix**: 在 case 末尾加 `*) echo "Error: unknown rule $RULE" >&2; FAIL=$((FAIL+1)) ;;`
- **Spread fix**: no
- **Automation**: not automatable
```

Bad：
```
### 错误处理不好

- **Layer**: L1
- **Severity**: important
- **Observation**: 缺错误处理
- **Fix**: 加错误处理
```（缺 Essence、Impact、Scope、具体 Fix）

## 8. Step 3: 治理机会

Model: opus

Gate (auto): Step 2 产出了 ≥1 个 finding → 执行。否则跳过。

对每个具备自动化潜力的 finding，评估：

### Autofix 评估

| 问题 | 答案 |
|----------|--------|
| Automation target | {what exactly gets automated} |
| Precondition | {what must be true for safe automation} |
| Automation risk | {what could break} |
| Verification method | {how to confirm automation didn't break behavior} |

### 扩展修复决策

仅当下列条件多数成立时才允许扩展修复：
- 同一坏模式在多处重复
- 修复机械、稳定、一致
- 范围可控
- 不需要额外的产品/架构决策
- 可安全地通过 codemod/AST/lint autofix/规则替换完成
- 完成后显著提升一致性

任一条成立时拒绝扩展修复：
- 会把当前变更膨胀为次级重构
- 不同位置语义不同，无法机械统一
- 需要新的架构决策
- 风险大于一致性收益
- 引入过多上下文切换和验证成本

### 规约候选

若 finding 具备复发潜力，评估：
- 新增 review checklist 项？
- 新增 lint/check/规则？
- 新增 test guard？
- 新增团队规约？

## 9. Step 4: 呈现发现

Model: sonnet

把 Steps 1-3 编排为 A-H 输出。这是 review 交付物。

用户可见 section 标题用用户语言。下方英文是模板骨架 —— 输出时翻译（例如 "## A. 变更理解 / ## B. 结论概览 / ## C. 核心问题 / ## D. 模式信号 / ## E. 可自动化修复 / ## F. 规约候选 / ## G. 行动决策"）。

```
## A. Change Understanding
{from Step 1}

## B. Conclusion Overview
{3-7 most important conclusions, priority-ordered, no vague statements}

## C. Core Issues
{findings using problem template, sorted by severity then layer}

## D. Pattern Signals

**Bad pattern signals**:
- {signal}: {where observed}

**Good pattern signals**:
- {signal}: {where observed}

**Net evolution judgment**: improvement / neutral / degradation
**Reason**: {one sentence}

## E. Autofix / Spread Fix

| Issue | Automation type | Scope | Risk | Expected benefit |
|-------|----------------|-------|------|-----------------|

## F. Convention Candidates

- **Review checklist**: {items or "无"}
- **Lint/check/rule**: {items or "无"}
- **Test guard**: {items or "无"}
- **Team convention**: {items or "无"}

## G. Action Decision

**Verdict**: approve / approve with targeted fixes / require significant cleanup / split refactor and re-review
**Reason**: {why}
**Required before merge**: {list or "无"}
**Recommended but not blocking**: {list or "无"}
```

Severity 参考：
- **blocking**：合并前必须修 —— 安全漏洞、数据丢失风险、撤销代价高的错误抽象、会被广泛复制的坏模式
- **important**：强烈建议修 —— 结构性退化、不一致扩散、未来维护成本显著上升
- **opportunistic**：低成本就值得做 —— 自动化机会、规约候选、ROI 良好的小改进

## 10. Step 5: 写阶段产出

Model: sonnet

按 Step 4 的 A-G 结构写入 `{sprint_dir}/handoffs/review.md`。

## 11. Step 6: 用户决策

Model: sonnet

**Note**: 本步骤行为随模式变化——非 auto 模式下询问用户；auto 模式下跳过询问、自动接受 verdict，分支细节见本节末尾 `Auto mode: mandatory self-check (D6-review-verdict)` 块。

呈现 G section 的 verdict 及支撑证据。问："是否同意这个行动建议？"

- Approve → 完成
- Approve with targeted fixes → 列出具体 fix → 退回 execute 修复 → 从 Step 2 重新进入 review
- Require cleanup → 列出需清理的内容 → 退回 execute 修复 → 从 Step 1 重新进入 review
- Split refactor → 识别需拆分的内容，标记为独立 sprint
- 用户覆盖 verdict → 用用户的决策和理由更新 handoff

### Auto mode: mandatory self-check (`D6-review-verdict`)

若 `state.json.auto == true`：
- 在呈现 verdict 问题之前，按 `skills/sprint/auto-principles.zh.md` §自检 block 模板生成 Review Verdict 自检 block
- 绑定原则：`reversibility` + `blast-radius` + `concrete-evidence`（auto-principles.zh.md decision `D6-review-verdict`）
- 追加到 handoff 的 `## 自动审视` section
- **auto 模式下跳过 "是否同意这个行动建议？" prompt**；verdict 自动接受并记录
- 任何非 `approve` 的决策 → 记录为高影响 finding，但仍自动推进；用户会在 insight 的 自动审视汇总 中看到，可以发出 `重跑 D6-review-verdict` 或通过 `approve` 接受

---

## 12. 完成条件

- [ ] 按选定深度完成所有层分析（quick: L1+L4；full: L1–L5）
- [ ] 每个 finding 均使用 12 字段问题模板
- [ ] 治理机会已评估
- [ ] Net evolution judgment 已陈述
- [ ] Action verdict 已给出且用户已确认（auto 模式：自检 block 已写）
- [ ] Handoff 已写入

## 13. 恢复

- 出现 blocking finding → 退回 execute 修复 → 从 Step 2 重新进入 review
- 用户不同意 verdict → 用用户的决策更新 handoff，记录理由
- 缺乏可信分析所需的上下文 → 标注具体结论为低置信度，说明还需要哪些上下文
- 修复期间新增文件 → 退回 execute 修复 → 从 Step 2 重新进入 review
