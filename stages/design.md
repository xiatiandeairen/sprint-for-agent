# design

## Progress

- total: 7
- steps:
  1. What form should the output take?
  2. What technical decisions need to be made?
  3. How do others solve this?
  4. Does this solution fit your needs?
  5. What to build first?
  6. How does it all fit together?
  7. Lock the design

From confirmed demand to concrete solution design. Goal: plan stage can split tasks directly from design output.

## Hard Rules

- Max 3 candidates per need. If more pass filter, drop the weakest.
- Do not generate candidates for forms failing Q1/Q2 filter.
- No `open` Decision Register entries when moving to next step.

## Input

- brainstorm handoff (if exists): demand frame, scope, value points
- User description + evaluate result (if brainstorm skipped)

---

## Step 1: Delivery Form Classification

Model: opus

Gate (user): 需求的解决方式是否不明确？

💡 "做什么"清楚但"用什么形式做"不清楚 → 需要分类。形式已明确 → 跳过。Default: skip.

### 7 Delivery Forms

| Form | Solves | Classifier |
|------|--------|-----------|
| Feature | Can't do X | user can't do it at all |
| Workflow | Does steps wrong | user can but gets it wrong |
| Decision Policy | Can't judge | user can but can't judge |
| Automation | Repeats boring work | user can but doesn't want to |
| Data Structure | Info disorganized | information is chaotic |
| Asset/Template | Keeps being rebuilt | same thing built repeatedly |
| Collaboration | People misaligned | multiple parties misalign |

### Execution

Per need: classify → primary form + check 2 adjacent forms. Filter:
- Q1: Solves user's problem directly? (must be yes)
- Q2: Buildable within sprint scope? (must be yes)
- Q3: Reusable value beyond this sprint? (prefer yes)

Eliminate Q1/Q2 failures. Present top 3 with form + rationale. User confirms form per need.

Then: "默认全部包含。要排除哪些？" — unselected needs logged as "out of scope".

---

## Step 2: Decision Convergence

Model: opus

Gate (user): 是否存在多个可行方案需要取舍？

💡 技术路径唯一且明确 → 跳过。多种实现方式需要比较 → 进入。Default: skip.

Binary tradeoff questions in batches of 3. Select most discriminating from pool:

```
1. Priority: fast result (A) vs better result (B)?
2. Scope: one need (A) vs reusable capability (B)?
3. Control: user drives (A) vs system guides (B)?
4. Input: structured (A) vs freeform (B)?
5. Flow: step-by-step (A) vs free exploration (B)?
6. Form: standalone (A) vs integrated (B)?
7. Automation: suggest (A) vs auto-execute (B)?
8. Decision: user judges (A) vs system recommends (B)?
9. Display: show all (A) vs filter first (B)?
10. Optimize: current task (A) vs overall process (B)?
```

Present batch + "skip" option. Max 3 rounds. Answers converge → output 3 ranked task goals.

"默认全部包含。要排除哪些？" — unselected goals logged as "deferred".

---

## Step 3: Industry Insight

Model: sonnet (with WebSearch)

Gate (user): 是否涉及技术选型或架构模式选择？

💡 内部逻辑实现 → 不需要外部参考。框架/架构/竞争方案选择 → 值得调研。Default: skip.

Ask user first: "There may be relevant industry practices. Want me to research?" No → skip.

If yes, research per task goal along: User problem → Mechanism → Industry patterns → Tradeoffs → Evolution. Present 4 perspectives: Frontier, Standard, Popular, Recommended (with project-context rationale).

---

## Step 4: Solution Alignment

Model: opus

Produce concrete design artifacts matched to delivery form.

| Form | Artifact |
|------|----------|
| Feature | Interface sketch + interaction flow |
| Workflow | Flow diagram with steps, decisions, outputs |
| Decision Policy | Decision flow + scoring criteria |
| Automation | Trigger-action flow + before/after comparison |
| Data Structure | Schema + field definitions + relationships |
| Asset/Template | Template structure + usage example + variation points |
| Collaboration | Protocol diagram + roles + state transitions |

For code-level design, also produce:
- File structure table (create / modify / do-not-touch)
- Interface definitions (public API, before/after)
- Dependency direction (allowed + forbidden)
- Architecture/sequence/data-flow diagrams (when warranted by complexity)

Present to user. Corrections → update and re-present.

### Build Decision Register

After user confirms, compile all decisions from Steps 1-4:
- Steps 1-2 selections → `core`
- Step 4 design decisions → `core`
- Implementation details → `detail`

Present register for user review.

### Few-shot

Good: `Form: Automation | Trigger: /deploy → auto-checks env, builds, pushes staging | Before: 5 manual steps | After: 1 command | Files: create scripts/deploy.sh, modify package.json`

Bad: `Form: Feature | Description: Improve deployment to be more automated | Files: various`

---

## Step 5: Implementation Priority Review

Model: sonnet

Gate (auto): Decision Register 中是否有 `detail` 类 `○ direction` 条目？

有 → 进入。无 → 跳过。

Extract unconfirmed `detail` items, sort by dependency. TaskCreate per item. Walk through each: recommended approach + alternatives. User confirms → TaskUpdate completed + register entry → `confirmed`.

User says "skip" → remaining `detail` items stay at `direction` for plan/execute to resolve.

---

## Step 6: System Design

Model: opus

Gate (user): 是否需要定义架构分层、核心流程、接口协议或算法？

💡 不增加新层、不改数据流、不设计新接口、不涉及非平凡算法 → 跳过。Default: skip.

Evaluate 4 sub-layers, present applicable ones for confirmation:

| Sub-layer | Trigger | Output |
|-----------|---------|--------|
| Architecture | Need responsibility boundaries or layering? | Layers, modules, dependency direction, tech choices |
| Core Flow | Critical paths need explicit ordering? | Main path, branches, state transitions, data flow |
| Interface & Protocol | Components exchanging data? | Signatures, schemas, formats, calling conventions |
| Algorithm | Non-trivial algorithm logic? | Pseudocode, complexity, performance/scalability/maintainability/edge case review |

All "not applicable" → skip entirely. Present applicable outputs together for user confirmation. Decisions added to register as `core`.

---

## Step 7: Write Handoff

Model: sonnet

Write `.sprint/{id}/handoffs/design.md`:

```markdown
## Conclusion
## Delivery Form
## Task Goals
## Industry Context
## Design Content
{diagrams, tables, interface defs, flows}
## Key Decisions
## File Structure
| Action | File | Responsibility |
## Constraints
## Decision Register
| # | Decision Point | Category | Status | Conclusion |
## Downstream
```

---

## Completion

### Decision Register

Status: `✓ confirmed` (execute directly) | `○ direction` (details pending) | `✗ open` (not discussed).

Category: `core` (architecture/flow/system-level, must be confirmed before plan) | `detail` (implementation specifics, may remain at `direction`).

### Exit Rules

1. No `open` status allowed
2. All `core` entries must be `confirmed`
3. `detail` entries may remain at `direction`
4. User confirmed Decision Register
5. Handoff written

## Recovery

- Plan discovers design gap → return to design, fill gap, re-confirm
- User changes direction → re-run from Step 2
- Missing technical design → return to Step 6, fill specific sub-layer
