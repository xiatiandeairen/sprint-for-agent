# design

## Progress

- total: 7
- steps:
  1. 确定解决方案的形式
  2. 收敛方向
  3. 参考行业实践
  4. 确定具体方案
  5. 确认功能清单
  6. 确认技术方向
  7. 输出设计文档

From confirmed demand to concrete solution design. Goal: plan stage can split tasks directly from design output.

## Mode

Mode criteria are defined in SKILL.md (Mode Determination section). Reference that for quick vs full rules.

- **quick:** Skip Step 1-2. Start from Step 3 (conditional) or Step 4 directly if approach is obvious.
- **full:** Full Step 1-4. Demand modeling → decision convergence → industry insight (conditional) → solution alignment.

## Input

- brainstorm handoff (if exists): demand frame, scope, value points
- User description + evaluate result (if brainstorm was skipped)

---

## Step 1: Demand Modeling (full only)

Classify each need into its optimal delivery form. Do not default to "feature" — choose the form that best solves the underlying problem.

### 7 Delivery Forms

| Form | Solves | Example |
|------|--------|---------|
| Feature | User "can't do X" | New chat command |
| Workflow | User "does steps in wrong order" | Guided checklist |
| Decision Policy | User "doesn't know how to judge" | Scoring/ranking logic |
| Automation | User "repeats boring work" | Auto-fill, auto-trigger |
| Data Structure | Information "is disorganized" | Schema, index, format |
| Asset/Template | Capability "keeps being rebuilt" | Reusable template, config |
| Collaboration | Multiple people "aren't aligned" | Shared state, protocol |

### Classifier

```
if user can't do it at all       → Feature
if user can but gets it wrong    → Workflow
if user can but can't judge      → Decision Policy
if user can but doesn't want to  → Automation
if information is chaotic        → Data Structure
if same thing keeps being built  → Asset/Template
if multiple parties misalign     → Collaboration
```

### Execution

For each need from brainstorm handoff:

1. Classify using the classifier above
2. Generate candidates across multiple forms (not just the classified one):
   - 1 feature candidate
   - 1 workflow candidate
   - 1 decision policy candidate
   - (optional) automation / data / asset / collaboration

3. Score each candidate:
```
score = outcome_impact + coverage + reusability - complexity - implementation_cost
```

4. Present top 3 ranked by score. For each, state the delivery form and why it fits:

```
Your need "{need}" could be solved as:

1. {form}: {description} — best fit because {reason}
2. {form}: {description} — alternative because {reason}
3. {form}: {description} — if you also want {benefit}
```

Wait for user to confirm delivery form per need. Then ask which needs to include in this sprint:

```
Which needs to include in this sprint?

A) All
B) {need 1} only
C) {need 1} + {need 2}
D) {need 1} + {need 3}
E) Other combination
```

Only selected needs proceed to Step 2. Unselected needs are logged as "out of scope" in handoff.

---

## Step 2: Decision Convergence (full only)

Narrow down the solution space through binary tradeoff questions. Present all 3 questions in one batch; user answers all at once.

### Question Pool (select most relevant per context)

```
1. Priority: get usable result fast (A) vs spend time for better result (B)?
2. Scope: solve this one need (A) vs build reusable capability (B)?
3. Control: user drives decisions (A) vs system guides/decides (B)?
4. Input: structured (templates/fields) (A) vs freeform (natural language) (B)?
5. Flow: explicit step-by-step (A) vs free exploration (B)?
6. Form: standalone tool (A) vs integrated into existing system (B)?
7. Automation: assist with suggestions (A) vs auto-execute (B)?
8. Decision: user judges (A) vs system recommends/ranks (B)?
9. Display: show everything (A) vs filter then show (B)?
10. Optimize: current task (A) vs overall process/system (B)?
```

### Execution

1. Pick 3 most discriminating questions for the current context
2. Present all 3 as a single batch with A/B options; wait for user to answer all at once
3. Add skip instruction at the end of the batch: "If the direction is already clear from these answers, reply **skip** to skip remaining rounds."
4. Narrow solution space based on answers
5. If answers already point to a clear direction (all 3 align to same approach) OR user replies "skip" → stop, go to output
6. If still ambiguous, pick next 3 questions, present as another batch, repeat (max 3 rounds)
7. Once converged, output 3 concrete task goals ranked by fit:

```
Based on your preferences, the task goals are:

1. {goal} — {why this fits your choices}
2. {goal} — {alternative angle}
3. {goal} — {if you want to extend scope}
```

Wait for user to confirm. If none fits, continue asking.

Then ask which task goals to include in this sprint:

```
Which task goals to include?

A) All
B) {goal 1} only
C) {goal 1} + {goal 2}
D) Other combination
```

Only selected goals proceed to Step 3. Unselected goals logged as "deferred" in handoff.

---

## Step 3: Industry Insight (conditional)

**Trigger condition:** Only execute when full AND the task involves technology selection or approach comparison (e.g., choosing between frameworks, architectural patterns, or competing implementation strategies).

If the trigger condition is not met, skip this step entirely.

If triggered, ask the user first:

```
There may be relevant industry practices for this decision. Want me to research?
```

If user says no, skip entirely. Only proceed if user confirms yes.

### Execution (when triggered and user says yes)

For each confirmed task goal, research along this chain:

```
User problem → Mechanism → Industry implementation patterns → Company tradeoffs → Evolution trend
```

Present 4 perspectives per goal:

```
### Industry Insight: {task goal}

**Frontier**
{cutting edge approaches, latest research}

**Standard**
{industry norms, established best practices}

**Popular**
{most widely adopted, community favorites}

**Recommended**
{best fit for current project context, with rationale}

---
```

Can use subagent + WebSearch for parallel research across goals.

Wait for user to confirm research direction. If user disagrees, continue researching.

---

## Step 4: Solution Alignment

Produce concrete design artifacts matched to the delivery form. User must be able to see what the solution looks like before implementation.

### Output by delivery form

| Form | Design artifact |
|------|----------------|
| Feature | UI mockup or interface sketch + interaction flow |
| Workflow | Flow diagram with steps, decision points, outputs |
| Decision Policy | Decision flow + scoring criteria + parameters |
| Automation | Trigger-action flow + before/after comparison |
| Data Structure | Schema diagram + field definitions + relationships |
| Asset/Template | Template structure + usage example + variation points |
| Collaboration | Protocol diagram + roles + state transitions |

### For code-level design, also produce:

- File structure table (create / modify / do-not-touch)

```
| Action | File | Responsibility |
|--------|------|---------------|
| create | path/to/file | ... |
| modify | path/to/file | ... |
```

- Interface definitions (public API, before/after for changes)
- Dependency direction (allowed + forbidden)
- Architecture diagram / sequence diagram / data flow as needed

### Present to user:

```
### 📐 Solution Design

**Form**: {delivery form}

{design artifacts per form}

**Key Decisions**
- {decision}: {why A not B}

**File Impact**
- create: {files}
- modify: {files}
- do not touch: {files}

---
```

Wait for user confirmation. Corrections → update and re-present.

---

## Step 5: Implementation Priority Review (skippable)

After Solution Alignment and before writing the handoff, extract all detail items that require a decision, create tasks for visibility, and walk through each with the user.

### Procedure

**5a: Extract**
Extract all `detail` category items from the Decision Register that are not yet `confirmed`. Sort by implementation dependency (depended-upon items first).

**5b: Create tasks**
For each detail item, create a TaskCreate with:
- Title: the decision point
- Status: open

This gives the user visibility into how many details remain to confirm.

**5c: Discuss and close**
Walk through each item sequentially: present recommended approach + alternatives. When the user confirms, call TaskUpdate to mark that task as completed and update the Decision Register entry to `confirmed`.

### Skip Condition

User says "skip" or "go to plan" → skip this step; remaining `detail` items stay at `direction` and are left for plan/execute to resolve.

---

## Step 6: System Design (conditional)

After product decisions are locked (Step 5), determine whether the solution needs technical design depth. This step ensures core technical directions are clear before entering plan.

### Trigger Assessment

Based on Step 1-5 outputs, evaluate these 4 questions. Present results to user for confirmation in one round:

```
Based on the design so far:

1. Need to define responsibility boundaries or layering?     → Architecture Design
2. Have critical paths that need explicit flow ordering?      → Core Flow Design
3. Components/layers/services exchanging data?                → Interface & Protocol
4. Need to choose or design non-trivial algorithm logic?      → Algorithm & Optimization

Applicable: {list}
Not applicable: {list}

Agree? Or adjust?
```

If all 4 are "not applicable" → skip this step entirely.

### 6a: Architecture Design

Define the structural skeleton of the solution.

- **Layering**: what layers exist, each layer's responsibility, boundary rules (what can call what)
- **Module decomposition**: modules/components, their responsibilities, dependency direction
- **Key tech decisions**: framework, storage, pattern choices with rationale

Output: layered diagram or structured description. Must be concrete enough that someone can judge whether a new file belongs in layer A or layer B.

### 6b: Core Flow Design

Define how the system processes its primary scenarios.

- **Main path**: complete flow from trigger to result (happy path)
- **Key branch paths**: error handling, edge cases that affect flow
- **State transitions**: if stateful, define states and transition rules
- **Data flow**: where data originates, what transforms it, where it lands

Output: flow diagram, sequence diagram, or structured step-by-step description.

### 6c: Interface & Protocol

Define the contracts between components.

- **Inter-component interfaces**: function signatures, parameters, return values
- **Data structures**: schema definitions, field types, constraints
- **Data formats**: serialization format, encoding conventions
- **Calling conventions**: sync/async, error propagation, retry policy

Output: interface definition table or code-level type definitions.

### 6d: Algorithm & Optimization

Define the core logic and its quality characteristics.

- **Algorithm description**: pseudocode or logic walkthrough
- **Complexity**: time/space analysis
- **Multi-dimensional review**:
  - Performance: where are the bottlenecks, acceptable?
  - Scalability: 10x data volume, still viable?
  - Maintainability: can a new contributor understand this?
  - Edge cases: empty input, extreme values, concurrency

Output: algorithm description with complexity and review conclusions.

### Confirmation

Present all applicable sub-layer outputs together. User confirms or requests changes. System design decisions are added to the Decision Register as `core` category.

---

## Step 7: Write handoff

Write `.sprint/{id}/handoffs/design.md`:

```markdown
# design Handoff

## Conclusion
{1-2 sentences}

## Delivery Form
{Feature / Workflow / Decision Policy / Automation / Data Structure / Asset / Collaboration}

## Task Goals
- {confirmed goal 1}
- {confirmed goal 2}

## Industry Context
{key findings that influenced the design}

## Design Content
{full design artifacts — diagrams, tables, interface defs, flows}

## Key Decisions
- {decision}: {rationale}

## File Structure
| Action | File | Responsibility |
|--------|------|---------------|

## Constraints
- {structural constraints for plan/execute}
- {dependency rules}
- {do-not-touch list}

## Downstream
{enough for plan to split tasks without additional design decisions}
```

---

## Completion

Design handoff must include a Decision Register. User confirmation required before marking design as completed.

### Decision Register

Handoff must contain a structured decision ledger:

```markdown
## Decision Register

| # | Decision Point | Category | Status | Conclusion |
|---|----------------|----------|--------|------------|
| 1 | ... | core | ✓ confirmed | ... |
| 2 | ... | core | ✓ confirmed | ... |
| 3 | ... | detail | ○ direction | ... |
```

**Status definitions:**
- `✓ confirmed` — Clear conclusion; downstream can execute directly
- `○ direction` — Direction set but details pending; plan stage may fill in
- `✗ open` — Not yet discussed

**Category definitions:**
- `core` — Decisions that affect architecture, primary flow, or system-level behavior; must be resolved before plan
- `detail` — Implementation specifics that do not affect architecture; can remain at `direction`

### Exit Rules

1. No `open` status allowed
2. All `core` entries **must** be `confirmed` before entering plan
3. `detail` entries may remain at `direction`
4. Decision Register must be reviewed and confirmed by the user

### Checklist

- [ ] Demand modeling done, user confirmed delivery form (full)
- [ ] Decision convergence done, task goals confirmed (full)
- [ ] Industry insight: skipped (condition not met or user said no) OR confirmed by user
- [ ] Solution design confirmed
- [ ] Decision Register: no `open`, all `core` entries `confirmed`
- [ ] Implementation Priority Review: detail items confirmed via tasks (or user skipped)
- [ ] System Design: applicable sub-layers completed and confirmed (or all skipped)
- [ ] User confirmed Decision Register
- [ ] Handoff written

## Early Exit

- quick: approach obvious from code → Step 4 minimal design, Step 6 trigger assessment only (likely skip), done
- Upstream already contains design detail → fill gaps only

## Recovery

- Plan discovers design gap → return to design, fill gap, re-confirm
- User changes direction after seeing design → re-run from Step 2
- Plan discovers missing technical design → return to Step 6, fill specific sub-layer
