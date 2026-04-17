# design

## Progress

- total: 5
- steps:
  1. How should this be solved?
  2. Does this solution fit your needs?
  3. What to build first?
  4. How does it all fit together?
  5. Lock the design

From confirmed demand to concrete solution design. Goal: plan stage can split tasks directly from design output.

## Hard Rules

- Max 3 candidates when presenting solution approaches.
- No `open` Decision Register entries when moving to next step.

## Input

- brainstorm handoff (if exists): demand frame, scope, value points
- User description + evaluate result (if brainstorm skipped)

---

## Step 1: Solution Approach

Model: opus

Gate (user): 解决方式是否需要确定？

💡 如何解决已经明确 → 跳过。存在多种可行方向或形式不清 → 进入。Default: skip.

Determine how to solve the problem before designing the details.

### Execution

1. **Infer** — from demand frame (Goal/Object), infer the most likely solution approach: form (what type of deliverable) + path (how to implement).

2. **Ambiguity check** — is there only one reasonable approach?
   - Yes → present the approach, one-line rationale, user confirms.
   - No → present 2-3 candidates:
     ```
     | # | Approach | Form | Trade-off |
     |---|----------|------|-----------|
     | 1 | {approach} | {Feature/Workflow/Automation/...} | {1 sentence} |
     | 2 | {approach} | {form} | {1 sentence} |
     ```
     Recommend one. User picks.

3. **Industry reference** (optional sub-action) — if user asks "业界怎么做?" or task involves tech selection / architecture pattern choice → quick WebSearch, present findings inline. Do not proactively offer.

4. **Lock** — confirmed approach feeds into Step 2 (Solution Alignment).

### Few-shot

Good: `Approach: CLI script with subcommands | Form: Automation | Trade-off: fast to build, less discoverable than UI`

Bad: `Approach: Improve the system | Form: Feature | Trade-off: better`

---

## Step 2: Solution Alignment

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

After user confirms, compile all decisions from Steps 1-2:
- Step 1 approach selection (if entered) → `core`
- Step 2 design decisions → `core`
- Implementation details → `detail`

Present register for user review. Append: `如需对抗性审视，回复"审视"`

User says "审视" → switch to challenger role: for each `core` decision, challenge using first-principles reasoning. Question whether the problem being solved is real, whether a simpler approach exists, and whether the decision should be reversed. After challenge round, re-present register (updated or unchanged).

### Few-shot

Good: `Form: Automation | Trigger: /deploy → auto-checks env, builds, pushes staging | Before: 5 manual steps | After: 1 command | Files: create scripts/deploy.sh, modify package.json`

Bad: `Form: Feature | Description: Improve deployment to be more automated | Files: various`

---

## Step 3: Implementation Priority Review

Model: sonnet

Gate (auto): Decision Register 中是否有 `detail` 类 `○ direction` 条目？

有 → 进入。无 → 跳过。

Extract unconfirmed `detail` items, sort by dependency. TaskCreate per item. Walk through each: recommended approach + alternatives. User confirms → TaskUpdate completed + register entry → `confirmed`.

User says "skip" → remaining `detail` items stay at `direction` for plan/execute to resolve.

---

## Step 4: System Design

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

## Step 5: Write Handoff

Model: sonnet

Write `.sprint/{id}/handoffs/design.md`:

```markdown
## Conclusion
## Solution Approach
{form + path, from Step 1 if entered; otherwise inferred in Step 2}
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
- User changes direction → re-run from Step 1
- Missing technical design → return to Step 4, fill specific sub-layer
