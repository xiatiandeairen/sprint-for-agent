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

## Input

- design handoff: delivery form, design content, file structure, constraints
- User description + evaluate result (if design skipped)

---

## Step 1: Spec Preferences

Model: sonnet

Gate (user): 实现方式是否有多种选择（改动范围、过渡策略、兼容性）？

💡 只有一种显然的做法 → 跳过。涉及范围取舍、新旧过渡、兼容性约束 → 进入。Default: skip.

### Dimensions

**Core** (always show):

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

Infer defaults from design handoff ("minimal changes" → scope=precise, "refactor" → depth=root-cause, etc.). Use recommendation-first table. Undecided → "待定", user asks → expand A/B.

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
| Project has tests | `MUST_TEST` | SKIP if no project type detected |
| Project is buildable | `MUST_BUILD` | SKIP if no project type detected |

Also extract from spec preferences and decision point mitigations.

After writing, present anchor list with one question:

```
Anchors ({N} rules) — written.
{list anchors, 1 per line}

Any files or constraints to add?
```

User adds → append. User says nothing / confirms → proceed. Do not ask for confirmation of auto-extracted anchors.

---

## Step 4: Split Tasks

Model: sonnet

### Splitting Rules

- **Independent verifiability**: each task builds, tests pass, behavior observable standalone.
- **Single responsibility**: one task = one concern.
- **Size constraint**:

| Size | Files | Lines | Model |
|------|-------|-------|-------|
| S | 1 | <50 | sonnet |
| M | 2-3 | 50-200 | sonnet |
| L | 3-5 | 200-500 | opus |
| XL | 5+ | 500+ | must split further |

S tasks may merge if independent verifiability preserved.

Per task:
```
### Task {N}: {title}
**Files**: create: {path} / modify: {path}
**Steps**: 1. Write test 2. Run → FAIL 3. Implement 4. Run → PASS 5. Build verify (typed languages) 6. Commit
**AI verify**: {build + test + anchor-check}
**User verify**: [ ] {check 1} [ ] {check 2}
```

Aggregate all files into `## Expected Files`.

### Few-shot

Good: `Task 1: Add UserProfile model — S — 1 file | verify: exists, compiles, contains fields`
Bad: `Task 1: Add profile and refactor auth — L — 5 files | verify: it works`

---

## Step 5: Confirm Execution

Model: sonnet

Present task summary with recommended execution strategy:

```
**Tasks**: Task 1: {title} — {size} | Task 2: ...
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
