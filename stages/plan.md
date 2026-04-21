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

From design handoff to executable task list.

## Hard Rules

- Every task must have a non-empty AI verify section. No build/test → use file existence or content check.
- Do not create tasks mixing new functionality with refactoring.
- **Gate merge rule**: when Steps 1/2 are skipped via Gate, present Steps 3+4+5 as a single combined output (anchors + task split + execution strategy) for one confirmation. Do not present anchors alone without task context.

## Input

- design handoff: delivery form, design content, file structure, constraints
- User description + evaluate result (if design skipped)

---

## Step 1: Spec Preferences

Model: sonnet

Gate (user): 实现方式是否有多种选择（改动范围、过渡策略、兼容性）？

💡 只有一种显然的做法 → 跳过。涉及范围取舍、新旧过渡、兼容性约束 → 进入。Default: skip.

### Inherit from design handoff

**If design handoff exists and contains `## Spec Preferences` section**:

1. Parse the 4 fields (scope / depth / transition / compatibility)
2. For each field：
   - Value ≠ `undecided` → 已从 design 继承，**不再弹 Q**
   - Value = `undecided` → 需补问，弹对应 Q
3. Step 1 头部显示继承状态：
   ```
   已从 design 继承: {inherited fields}
   需补: {undecided fields or "无"}
   ```
4. 仅弹出 `undecided` 字段对应的 Q，已继承的跳过

**If design handoff does not exist (design stage was skipped)**:

Step 1 顶部显示：`⚠️ design 跳过，以下为 plan fallback 决策`

然后按原逻辑弹 Q1-Q4（如 Gate 进入）。

**Override path**: 触发词 `重新决策 | 重来 | 覆盖 | override | redo` + `{Qx | 字段名 scope/depth/transition/compatibility}` → 弹对应 Q 覆盖 design 继承值。

示例：
- "重新决策 Q1" / "Q1 重来" → 弹 scope
- "override depth" / "覆盖 depth" → 弹 depth
- "我想重新考虑 scope" → 弹 scope（关键词 `重新考虑` 等价 `重新决策`）

### Dimensions

**Core** (弹出规则见上):

| ID | Question | Key | A | B |
|----|----------|-----|---|---|
| Q1 | 周边小问题顺手修吗？ | scope | precise: 只改必须改的 | extended: 顺手清理 |
| Q2 | 解决根因还是先堵住？ | depth | patch: 先堵住 | root-cause: 追到底 |
| Q3 | 新旧代码需要过渡期吗？ | transition | direct: 直接替换 | incremental: 分步迁移 |
| Q4 | 内部接口可以重新设计吗？ | compatibility | strict: 不动调用方 | internal-break: 内部可破坏 |

**Auxiliary** (show only when design handoff has ambiguity):

| ID | Question | Key | A | B |
|----|----------|-----|---|---|
| Q5 | 测试写到什么程度？ | test | minimal: 只测新增 | thorough: 相邻也补 |
| Q6 | 有现成库倾向引入还是自写？ | dependency | built-in: 不加依赖 | external: 有成熟方案就用 |

Recommendation-first table. Undecided → "待定", user asks → expand A/B.

---

## Step 2: Decision Points

Model: opus

Gate (user): 改动是否可能引入兼容性问题、数据风险或集成冲突？

💡 改动局部且自包含 → 跳过。涉及模块边界、数据格式、现有功能交互 → 进入。Default: skip.

Identify: compatibility issues, uncertainty, risk items (data loss, perf, security), integration conflicts.

```
### Decision Points
1. **{point}** — {why it matters}
   - Risk: {low/medium/high}
   - Mitigation: {approach}
```

---

## Step 3: Generate Anchors

Model: sonnet

Auto-extract from design handoff and write directly to `.sprint/{id}/anchors.txt`:

| Source | Anchor | Notes |
|--------|--------|-------|
| File structure: create files | `MUST_EXIST {path}` | |
| Constraints: do-not-touch | `FILE_NOT_MODIFIED {path}` | |
| Dependencies: required imports | `MUST_IMPORT {target} {module}` | target = relative path from project root (file or dir) |
| Dependencies: forbidden imports | `MUST_NOT_IMPORT {target} {module}` | target = relative path from project root (file or dir) |
| Design intent: required content | `MUST_CONTAIN {file} {pattern}` | line-level grep (fixed string). E.g. config must have key, function must return type |
| Design intent: forbidden content | `MUST_NOT_CONTAIN {file} {pattern}` | line-level grep (fixed string). E.g. no deprecated API calls, no hardcoded secrets |
| Project has tests | `MUST_TEST` | Uses .sprint.json > CLAUDE.md > auto-detect. SKIP if none found |
| Project is buildable | `MUST_BUILD` | Uses .sprint.json > CLAUDE.md > auto-detect. SKIP if none found |

Also extract from spec preferences and decision point mitigations.

After writing, present the list in **natural-language form** (do NOT show raw rule tokens like `MUST_CONTAIN`/`MUST_EXIST` to the user; do NOT use the label "Anchors").

### Anchor 翻译规则（rule → 一句中文）

| Rule | 一句中文模板 |
|------|--------------|
| `MUST_EXIST {path}` | `{path} 必须存在` |
| `MUST_NOT_EXIST {path}` | `{path} 必须不存在（须删除）` |
| `MUST_CONTAIN {path} {pattern}` | `{path} 必须含文本 "{pattern}"` |
| `MUST_NOT_CONTAIN {path} {pattern}` | `{path} 必须不含文本 "{pattern}"` |
| `FILE_NOT_MODIFIED {path}` | `{path} 不得改动` |
| `MUST_BUILD` | `项目必须能构建通过` |
| `MUST_TEST` | `项目测试必须通过` |
| `MUST_IMPORT {target} {module}` | `{target} 必须 import {module}` |
| `MUST_NOT_IMPORT {target} {module}` | `{target} 必须不 import {module}` |

### 可能还需要补（推荐推断规则，最多 3 条）

根据 design handoff 扫以下信号，命中则作为候选补项推给用户：

| design handoff 里的信号 | 推荐补项 |
|------------------------|---------|
| File Structure 列了"do-not-touch"文件 | `FILE_NOT_MODIFIED {path}` |
| Decision Register 提到"保留接口"/"不动调用方" | `MUST_CONTAIN {api_file} {signature}` |
| Constraints 禁用某依赖/API | `MUST_NOT_CONTAIN` 或 `MUST_NOT_IMPORT` |
| 代码改动 + 项目有测试目录 | `MUST_TEST` |
| 新建文件 + 编译型语言项目 | `MUST_BUILD` |
| 新建配置/常量文件 | `MUST_CONTAIN {file} {key}` |

规则：无信号命中 → 空菜单；最多 3 条，按信号强度排序；每条必须带"建议理由"一行。

### 输出模板

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

### 交互收敛

- `ok` / `无需补充` / `继续` → 接受现有清单，进入 Step 4
- 编号（如 `A,C`）→ 反查推荐项 → 翻回 rule 原文 → 追加到 anchors.txt → 重刷显示一次
- 自由文本 → 按 Anchor 翻译规则反向解析为 rule → 追加；解析失败 → 最多 1 轮追问，再失败则视为不补

**Auto mode note**: in `state.json.auto == true` mode, present the translated list + menu for visibility, but if no user input arrives immediately (the sprint is hands-off), proceed after one clean render with the current anchors; user can revise at insight's 自动审视汇总 via `重跑 D5-task-split`.

---

## Step 4: Split Tasks

Model: sonnet

### Inherit from design

If design handoff exists AND its `## Suggested Task Boundaries` section is non-empty AND not marked `— not generated (Step 2 skipped)`:

1. Parse the boundary rows and present to user:
   ```
   Design suggested:
   - Task 1: {name} | Files: {files} | {rationale}
   - Task 2: ...

   A) Accept as-is
   B) Adjust (I'll present a diff, you edit)
   C) Redo from scratch (ignore design's suggestion)
   ```
2. **A** → generate plan tasks directly from the boundaries; apply Splitting Rules below only for size/model assignment and per-task template fields.
3. **B** → enter adjust mode: user edits task names/files; re-apply Splitting Rules for size/model.
4. **C** → fall through to Splitting Rules below, producing a split from scratch.

If design handoff missing OR Suggested Task Boundaries empty OR marked `not generated (Step 2 skipped)`:
Skip inherit branch; run Splitting Rules below directly.

### Splitting Rules

- **Independent verifiability**: each task builds, tests pass, behavior observable standalone.
- **Single responsibility**: one task = one concern.
- **Size constraint**:

| Size | Files | Lines | Default Model |
|------|-------|-------|---------------|
| S | 1 | <50 | sonnet |
| M | 2-3 | 50-200 | sonnet |
| L | 3-5 | 200-500 | opus |
| XL | 5+ | 500+ | must split further |

Model override per task: cross-module → opus. Single file, no logic → haiku. Otherwise use size default.

S tasks may merge if independent verifiability preserved.

Per task:
```
### Task {N}: {title}
**Model**: {opus/sonnet/haiku} — {rationale: cross-module / single file / no logic}
**Files**: create: {path} / modify: {path}
**Steps**: 1. Write test 2. Run → FAIL 3. Implement 4. Run → PASS 5. Build verify (typed languages) 6. Commit
**AI verify**: {build + test + anchor-check}
**User verify**: [ ] {check 1} [ ] {check 2}
```

Aggregate all files into `## Expected Files`.

### Auto mode: mandatory self-check (`D5-task-split`)

If `state.json.auto == true`:
- After task split is compiled, produce the Task Split self-check block per `skills/sprint/auto-principles.md` §自检 block 模板
- Bound principles: `independence` + `reversibility` (auto-principles.md decision `D5-task-split`)
- Append to handoff `## 自动审视` section
- Skip user confirmation; proceed to Step 5

### Few-shot

Good: `Task 1: Add UserProfile model — S — 1 file | verify: exists, compiles, contains fields`
Bad: `Task 1: Add profile and refactor auth — L — 5 files | verify: it works`

---

## Step 5: Confirm Execution

Model: sonnet

Present task summary with recommended execution strategy:

```
**Tasks**: Task 1: {title} — {size} — {model} | Task 2: ...
**Anchors**: {N} rules | **Expected Files**: {count}
**推荐**: {mode} + {commit strategy}
💡 {rationale}
```

Selection logic:
- All S/M + independent → Parallel + commit together
- Dependencies exist → Step-by-step + commit each
- User says "later" → Deferred

Disagree → expand: Execution (Step-by-step / Parallel / Deferred) + Commit (per task / all together).

**Deferred**: collect trigger → write to `.sprint/triggers.json` → skip execute → write plan handoff normally → end at plan stage.

---

## Step 6: Write Handoff

Model: sonnet

Write `.sprint/{id}/handoffs/plan.md`:

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

## Completion

- Specs confirmed, decision points reviewed, anchors written
- All tasks satisfy splitting rules (no XL), each has files/steps/model/verify
- Execution mode and commit strategy confirmed
- Handoff written

## Recovery

- Task too large → split further
- Missing verify → add before execution
- Design gap → return to design stage
