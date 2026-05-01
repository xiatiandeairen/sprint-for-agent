# plan

## Progress

- total: 6
- steps:
  1. How detailed should the spec be?
  2. Any open questions before coding?
  3. What must be true when done?
  4. How to break this into tasks?
  5. Ready to execute?
  6. Lock the plan

从 design handoff 到可执行任务列表。

## 1. 硬规则

1. 每个任务必须有非空的 AI verify。无 build/test → 用文件存在性或内容检查
2. 不混合"新功能"和"重构"任务
3. **Gate merge**：Step 1/2 通过 Gate 跳过时，Step 3+4+5 作为单一合并产出（锚点 + 任务切分 + 执行策略）一次性确认。**不要不带任务上下文孤立呈现锚点**

## 2. 输入

- design handoff：交付形式、设计内容、文件结构、约束
- 用户描述 + evaluate 结果（如 design 跳过）

---

## 3. Step 1：spec 偏好

Model: sonnet

**Gate (user)**：实现方式是否有多种选择（改动范围 / 过渡策略 / 兼容性）？

> 💡 只有一种显然的做法 → 跳过。涉及范围取舍 / 新旧过渡 / 兼容性约束 → 进入。Default: skip。

### 3.1 从 design handoff 继承

**design handoff 存在且含 `## Spec Preferences`**：

1. 解析 4 字段（scope / depth / transition / compatibility）
2. 对每字段：值 ≠ `undecided` → 已继承，**不再弹 Q**；值 = `undecided` → 弹对应 Q
3. Step 1 头部显示继承状态：
   ```
   已从 design 继承: {inherited fields}
   需补: {undecided fields or "无"}
   ```
4. 仅弹 `undecided` 字段对应的 Q

**design handoff 缺失（design 阶段被跳过）**：

Step 1 顶部显示 `⚠️ design 跳过，以下为 plan fallback 决策`，按原逻辑弹 Q1-Q4（如 Gate 进入）。

**覆盖路径**：触发词 `重新决策 / 重来 / 覆盖 / override / redo` + `{Qx | 字段名}` → 弹对应 Q 覆盖 design 继承值。

示例：

- "重新决策 Q1" / "Q1 重来" → 弹 scope
- "override depth" / "覆盖 depth" → 弹 depth
- "我想重新考虑 scope" → 弹 scope（`重新考虑` ≡ `重新决策`）

### 3.2 维度问题

**Core**（弹出规则见 3.1）：

| ID | 问题 | Key | A | B |
|----|------|-----|---|---|
| Q1 | 周边小问题顺手修吗？ | scope | precise: 只改必须改的 | extended: 顺手清理 |
| Q2 | 解决根因还是先堵住？ | depth | patch: 先堵住 | root-cause: 追到底 |
| Q3 | 新旧代码需要过渡期吗？ | transition | direct: 直接替换 | incremental: 分步迁移 |
| Q4 | 内部接口可重新设计吗？ | compatibility | strict: 不动调用方 | internal-break: 内部可破坏 |

**辅助**（仅当 design handoff 存在歧义时展示）：

| ID | 问题 | Key | A | B |
|----|------|-----|---|---|
| Q5 | 测试写到什么程度？ | test | minimal: 只测新增 | thorough: 相邻也补 |
| Q6 | 有现成库倾向引入还是自写？ | dependency | built-in: 不加依赖 | external: 有成熟方案就用 |

推荐优先表格。Undecided → "待定"，用户询问 → 展开 A/B。

---

## 4. Step 2：决策点

Model: opus

**Gate (user)**：改动是否可能引入兼容性问题、数据风险或集成冲突？

> 💡 改动局部且自包含 → 跳过。涉及模块边界 / 数据格式 / 现有功能交互 → 进入。Default: skip。

识别：兼容性问题、不确定性、风险项（数据丢失 / 性能 / 安全）、集成冲突。

**模板**：

```
### Decision Points
1. **{point}** — {why it matters}
   - Risk: {low/medium/high}
   - Mitigation: {approach}
```

---

## 5. Step 3：生成锚点

Model: sonnet

从 design handoff 自动提取并直接写入 `{sprint_dir}/anchors.txt`：

| Source | Anchor | 备注 |
|--------|--------|------|
| 文件结构：创建文件 | `MUST_EXIST {path}` | |
| 约束：do-not-touch | `FILE_NOT_MODIFIED {path}` | |
| 依赖：必需 import | `MUST_IMPORT {target} {module}` | target = 项目根相对路径 |
| 依赖：禁止 import | `MUST_NOT_IMPORT {target} {module}` | target = 项目根相对路径 |
| 设计意图：必需内容 | `MUST_CONTAIN {file} {pattern}` | 行级 grep（固定字符串） |
| 设计意图：禁止内容 | `MUST_NOT_CONTAIN {file} {pattern}` | 行级 grep（固定字符串） |
| 项目有测试 | `MUST_TEST` | 用 .sprint.json > CLAUDE.md > 自动检测，无则 SKIP |
| 项目可构建 | `MUST_BUILD` | 用 .sprint.json > CLAUDE.md > 自动检测，无则 SKIP |

也从 spec 偏好和决策点 mitigation 中提取。

写入后，以**自然语言形式**呈现清单（不向用户展示 `MUST_CONTAIN` / `MUST_EXIST` 等原始 token；不用 "Anchors" 标签）。

### 5.1 Anchor 翻译规则（rule → 一句中文）

- `MUST_EXIST {path}` → `{path} 必须存在`
- `MUST_NOT_EXIST {path}` → `{path} 必须不存在（须删除）`
- `MUST_CONTAIN {path} {pattern}` → `{path} 必须含文本 "{pattern}"`
- `MUST_NOT_CONTAIN {path} {pattern}` → `{path} 必须不含文本 "{pattern}"`
- `FILE_NOT_MODIFIED {path}` → `{path} 不得改动`
- `MUST_BUILD` → `项目必须能构建通过`
- `MUST_TEST` → `项目测试必须通过`
- `MUST_IMPORT {target} {module}` → `{target} 必须 import {module}`
- `MUST_NOT_IMPORT {target} {module}` → `{target} 必须不 import {module}`

### 5.2 可能还需要补（推荐推断规则，最多 3 条）

扫 design handoff 信号，命中作为候选补项推给用户：

- File Structure 列了 "do-not-touch" 文件 → `FILE_NOT_MODIFIED {path}`
- Decision Register 提到 "保留接口" / "不动调用方" → `MUST_CONTAIN {api_file} {signature}`
- Constraints 禁用某依赖 / API → `MUST_NOT_CONTAIN` 或 `MUST_NOT_IMPORT`
- 代码改动 + 项目有测试目录 → `MUST_TEST`
- 新建文件 + 编译型语言项目 → `MUST_BUILD`
- 新建配置 / 常量文件 → `MUST_CONTAIN {file} {key}`

规则：无信号命中 → 空菜单；最多 3 条，按信号强度排序；每条带"建议理由"一行。

### 5.3 输出模板

```
验证清单（{N} 条）— 已写入：

1. {translated rule 1}
2. {translated rule 2}
...

{if recommended additions:}
可能还需要补以下几项（可选）：
  A) {translated recommendation 1} — 建议理由：{signal}
  B) {translated recommendation 2} — 建议理由：{signal}
  C) {translated recommendation 3} — 建议理由：{signal}

回复 "ok" / "无需补充" 直接继续；回复编号（如 "A,C"）追加；自由文本补充也可。

{if no recommendations:}
无明显可补项，回复 "ok" 继续，或自己补一条（如 "文件 X 不得改动"）。
```

### 5.4 交互收敛

- `ok` / `无需补充` / `继续` → 接受现有清单，进 Step 4
- 编号（如 `A,C`）→ 反查推荐项 → 翻回 rule 原文 → 追加到 anchors.txt → 重刷一次
- 自由文本 → 按 5.1 翻译规则反向解析为 rule → 追加；解析失败 → 最多 1 轮追问，再失败视为不补

**托管模式**：呈现翻译清单 + 菜单以保可见性，但若用户输入未立即到达（无人值守），一次干净渲染后用当前锚点继续；用户可在 insight 用 `重跑 D5-task-split` 修正。

---

## 6. Step 4：切分任务

Model: sonnet

### 6.1 从 design 继承

design handoff 存在 AND `## Suggested Task Boundaries` 非空 AND 未标记 `— not generated (Step 2 skipped)`：

1. 解析边界行并呈现：
   ```
   Design suggested:
   - Task 1: {name} | Files: {files} | {rationale}
   - Task 2: ...
   
   A) 直接采用
   B) 调整（我给 diff，你编辑）
   C) 重做（忽略 design 建议）
   ```
2. **A** → 直接从边界生成 plan 任务；下方切分规则仅用于 size/model 分配
3. **B** → 进调整模式：用户编辑任务名/文件；对 size/model 重新应用切分规则
4. **C** → 落入下方切分规则，从零开始生成切分

design handoff 缺失 OR Suggested Task Boundaries 为空 → 跳过继承分支，直接运行下方切分规则。

### 6.2 切分规则

- **独立可验证**：每个任务能构建、测试通过、行为可独立观察
- **单一职责**：一个任务 = 一个关注点
- **尺寸约束**：

| Size | Files | Lines | Default Model |
|------|-------|-------|---------------|
| S | 1 | <50 | sonnet |
| M | 2-3 | 50-200 | sonnet |
| L | 3-5 | 200-500 | opus |
| XL | 5+ | 500+ | 必须进一步切 |

Model 覆盖规则：

- 跨模块 → opus
- 单文件、无逻辑 → haiku
- 否则 → size 默认值

S 任务在保持独立可验证的前提下可合并。

### 6.3 任务模板（每个任务必填）

```
### Task {N}: {title}
**Model**: {opus/sonnet/haiku} — {理由：跨模块 / 单文件 / 无逻辑}
**Files**: create: {path} / modify: {path}
**Steps**: 1. 写测试 2. 运行 → FAIL 3. 实现 4. 运行 → PASS 5. 构建验证 (强类型语言) 6. commit
**AI verify**: {build + test + anchor-check}
**User verify**: [ ] {check 1} [ ] {check 2}
```

聚合所有文件到 `## Expected Files`。

### 6.4 fewshot

- Good：`Task 1: 添加 UserProfile model — S — 1 文件 | verify: 文件存在，编译，含 fields`
- Bad：`Task 1: 加 profile 并重构 auth — L — 5 文件 | verify: 跑得通`

### 6.5 托管模式自检（`D5-task-split`）

如果 `state.json.auto == true`：

1. 任务切分编译完成后，按 `skills/sprint/auto-principles.zh.md` §自检 block 模板产出 Task Split 自检 block
2. 绑定原则：`independence` + `reversibility`
3. 追加到 handoff `## 自动审视` section
4. 跳过用户确认；进 Step 5

---

## 7. Step 5：确认执行

Model: sonnet

呈现任务摘要并附推荐执行策略：

```
**Tasks**: Task 1: {title} — {size} — {model} | Task 2: ...
**Anchors**: {N} rules | **Expected Files**: {count}
**推荐**: {mode} + {commit strategy}
💡 {rationale}
```

### 7.1 推荐选择逻辑

- 全部 S/M + 独立 → Parallel + 一起 commit
- 存在依赖 → Step-by-step + 每任务 commit
- 用户说 "later" → Deferred

不同意 → 展开：执行（Step-by-step / Parallel / Deferred）+ Commit（per task / all together）。

**Deferred**：收集 trigger → 写入 `.sprint/triggers.json` → 跳过 execute → 正常写入 plan handoff → 在 plan 阶段结束。

---

## 8. Step 6：写 Handoff

Model: sonnet

写入 `{sprint_dir}/handoffs/plan.md`：

```markdown
## Execution Mode
## Commit Preference
## Spec Preferences
- scope / depth / transition / compatibility / test / dependency
## Decision Points
## Tasks
### Task 1: {title}
- Files / Steps / Model / AI verify / User verify
## Expected Files
## Downstream
```

---

## 9. 完成条件

- spec 已确认、决策点已审视、锚点已写入
- 所有任务满足切分规则（无 XL），每任务都有 files / steps / model / verify
- 执行模式和 commit 策略已确认
- handoff 已写入

## 10. 恢复

- 任务过大 → 进一步切分
- 缺 verify → 执行前补上
- design 缺口 → 返回 design 阶段
