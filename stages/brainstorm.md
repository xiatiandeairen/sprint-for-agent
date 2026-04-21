# brainstorm

## Progress

- total: 2
- steps:
  1. What exactly do you want?
  2. Lock the conclusion

Align user intent through demand modeling and controlled value discovery.

Pure conversation. Do NOT read code, files, or docs. All evidence comes from the user.

## Hard Rules

- Each question must target a specific slot or hypothesis. No open-ended exploration.

---

## Step 1: Demand Modeling

Model: opus

### Pre-check: Sanity Gate

This is a filter layer, not a full analysis. Deep market / feasibility / root-cause work happens in design stage when needed. Purpose: break AI sycophancy before demand modeling starts — surface false needs, unverified assumptions, and hidden alternatives.

Run the 5 questions internally against the raw user description. Do NOT show the table to the user unless pushback fires.

| # | Challenge | Pushback trigger |
|---|-----------|------------------|
| 1 | Is the real pain behind this request identifiable? | answer is `no` or `unclear` |
| 2 | Does deleting the requirement entirely cause tangible harm? | answer is `no` |
| 3 | Does an existing tool / feature / workflow already solve this? | answer is `yes` |
| 4 | Is the minimum path here proportionally cheap vs. the value? | answer is `no` |
| 5 | Are the description's assumptions all verifiable from user-provided evidence? | answer is `no` |

**Algorithm**:

1. For each of Q1–Q5, answer y/n + 1-line evidence (internal, not shown).
2. Count pushback-triggering answers.
3. If Q3 triggered → include the 3 market-probe sub-questions in the pushback output.
4. If Q4 triggered → include the 3 feasibility-probe sub-questions in the pushback output.
5. **0 triggers** → silently proceed to 6-slot demand modeling below. Do not mention the gate.
6. **≥1 trigger** → render the pushback template. Stop. Wait for user response before continuing.

**Q3 expansion sub-questions** (market):

- Q3a: What existing solution, and why not use it?
- Q3b: Key differentiator from that solution?
- Q3c: Is this an implicit build-vs-buy decision?

**Q4 expansion sub-questions** (feasibility):

- Q4a: Largest technical risk or unknown?
- Q4b: What is the minimum viable version?
- Q4c: Can it be staged instead of done at once?

**Pushback template** (render in user language — do NOT output the label "Sanity Gate" or "Q{n}" codes; describe issues in plain language):

```
有 {N} 点需要先澄清：

- {1-line description of the concern — no code like "Q3"}
  {if market concern: list 3 market sub-questions inline as natural questions}
  {if feasibility concern: list 3 feasibility sub-questions inline as natural questions}

请选择：A) 补充信息 / 解释  B) 坚持原意（说明理由）  C) 调整需求
```

After user responds — if clarification resolves the triggers, proceed to 6-slot modeling. If user insists with justification, record the acknowledged risk in Context and proceed. If requirement is revised, re-run the internal check on the revised description.

**Few-shot**:

Good (0 triggers, silent passthrough):
```
User: "Add a sort-by-order-date descending filter to the order list"
Q1 pain: yes (default sort inconvenient) | Q2 delete harm: yes | Q3 existing: no | Q4 cost: yes | Q5 assumptions: yes
→ 0 triggers → proceed to 6-slot modeling, no user interaction
```

Bad (multi-trigger, full pushback):
```
User: "Build an AI assistant for the system"
Q1 pain: unclear | Q2 delete harm: no | Q3 existing: yes | Q4 cost: no | Q5 assumptions: no
→ 4 triggers (Q1, Q2, Q3, Q4) → pushback output includes Q3 and Q4 probe sub-questions
```

---

Turn vague input into a 6-slot demand frame.

| Slot | Captures |
|------|----------|
| Goal | What to achieve |
| Object | Target (feature, module, system, doc) |
| Constraint | Limits (time, compatibility, tech) |
| Context | Situation (why now, what triggered) |
| Success | How to verify done correctly |
| Priority | What matters most |

### Execution

**Ambiguity Triage** (run first, before slot extraction):

Assess the raw description against these 3 signals:

| Signal | Trigger |
|--------|---------|
| Verb ambiguity | Contains "完善/优化/改进/handle/support" without concrete verb (add/remove/replace/rename) |
| Scope ambiguity | ≥2 plausible scopes (1 file vs module vs cross-module) |
| Outcome ambiguity | ≥2 plausible end states (fix bug vs add feature vs rewrite) |

**0 signals fire** → description is concrete. Proceed directly to slot extraction below.

**≥1 signal fires** → present 3 candidate framings in ONE table before asking anything else (do NOT use the internal label "Strawman Framings" to the user):

```
基于描述，可能是以下三种之一。离哪个最近 + 差在哪？

| # | 问题框定 | 范围 | 形式 | 明确不做 |
|---|---------|------|------|---------|
| A | {narrowest framing} | {1 file / 1 module / etc.} | {Patch/Refactor/Feature/Automation} | {explicit exclusion} |
| B | {middle framing — recommended} | ... | ... | ... |
| C | {widest framing} | ... | ... | ... |
```

Rules:
- Each row must name concrete files/modules/actions — no "various" or "related components"
- Exclusions must be specific (something user might reasonably want but this framing excludes)
- Always recommend one (mark with ← 推荐) based on inferred effort/risk fit
- Max 3 rows. If <3 distinct framings exist → description wasn't ambiguous, should have skipped this sub-step

User picks → framing locked → proceed to slot extraction filling the 6 slots **under that framing's scope**. Do not revisit framing choice in Clarify step.

**Extract** visible slots from description (and chosen framing, if Strawman Framings ran). Rank gaps by downstream impact.

**Clarify** — present inferred slots + clarification questions in ONE round (slots are interdependent; batch asking is more efficient than sequential):

```
Here's what I inferred — confirm, correct, or fill in the blanks:

- **Goal**: {inferred or "not mentioned — A) ... B) ... C) ..."}
- **Object**: ...
- **Constraint**: ...
- **Context**: ...
- **Success**: ...
- **Priority**: ...

## Assumptions（哪条错了告诉我）
- [A1] {inferred load-bearing premise} — 来源：{evidence phrase from description}
- [A2] ...
- [A3] ...
```

Assumptions block rules:
- ≥3 items, each with explicit evidence source (quoted phrase or "inferred from X")
- Items must be **refutable** — user can say "A2 错" and mean something specific
- Cover the highest-risk inferences (what the user would be most surprised to see wrong)

User confirms → demand alignment locked. Corrections → update (max 1 follow-up).

**Lock** — present final demand frame, then evaluate step entry for Step 2.

Entry evaluation (internal, not shown to user):

For each diagnostic below, answer yes/no based solely on the locked demand frame:

| # | Question | yes signal |
|---|----------|------------|
| 1 | Will this task be done more than once? | Context mentions recurring trigger or pattern |
| 2 | Is there a manual step that could be eliminated? | Goal includes manual workflow |
| 3 | Could the result fail silently? | No validation in Success criteria |
| 4 | Is the output reusable by other features? | Object touches shared module or produces artifact |
| 5 | Does an implicit decision deserve to be explicit? | Constraint or Priority contains hidden assumption |

Count yes answers. ≥2 → recommend exploring additional value points (internally: Value Mining). Otherwise → proceed directly to conclusion.

Present to user (do NOT output the labels "Demand Lock" or "Value Mining"):

```
已对齐需求 ✓

[If ≥2 yes — recommend value exploration]
我注意到 {convert top 2 "yes" items into plain-language observations, e.g. "这个流程会重复发生，可以做成模板" / "这个产出会被其他模块引用"}。
A) 展开这些方向看看  B) 直接进入结论

[If <2 yes — proceed directly]
需求已清晰 — 直接进入结论。如果你看到值得挖的方向，随时提。
```

### Few-shot

Good: `Goal: Add dark mode to settings page | Object: SettingsViewController + theme system | Success: Toggle switches all colors; persists across launches`

Bad: `Goal: Improve the app | Object: The codebase | Success: It works better`

---

## Step 2: Converge

Model: sonnet

Present conclusion (render in user language):
```
### 结论

**{1 sentence — what to build}**

**举例**
- Before: {now}
- After: {then}
- 验证: {how to check}

**价值点**（如有）
- {confirmed point 1}
- {confirmed point 2}
```

Append: `如需对抗性审视，回复"审视"`

User confirms → write handoff. User says "审视" → switch to challenger role: challenge the conclusion using first-principles reasoning. Question whether the direction should exist, whether it's the simplest approach, and what assumptions are unverified. After challenge round, re-present conclusion (updated or unchanged).

**Handoff** (`.sprint/{id}/handoffs/brainstorm.md`):
```markdown
## Conclusion
## Demand Frame
- Goal / Object / Constraint / Context / Success / Priority
## Scope
### In / ### Out
## Value Points
## Downstream
```

---

## Optional Extension: Value Mining (internal label — do not render to user)

Triggered by: explicit user request, OR Step 1 entry recommendation (≥2 diagnostics yes). Not part of the standard brainstorm flow — runs only when demand frame suggests hidden value worth capturing and user opts in. When presenting to user, avoid the label "Value Mining"; use natural descriptions like "价值点探索".

Model: opus

Run diagnostic questions internally (not to user), generate grounded hypotheses:

| Diagnostic | If yes → direction |
|------------|-------------------|
| Task done repeatedly? | Automate or template |
| Manual step eliminable? | Remove or one-click |
| Could fail silently? | Add validation |
| Consistency check missing? | Build verification in |
| Output reusable elsewhere? | Extract as shared asset |
| Others benefit from this? | Generalize |
| Implicit decision should be explicit? | Surface as parameter |
| Recurring pattern? | Reusable solution |

**Diagnose:** Run questions against user's goal. Skip clear "no"s. Do not force hypotheses.

**Rank:** Present top 2-3 grounded hypotheses (render in user language):
```
除了你提到的目标，我注意到：
1. {hypothesis} — 因为 {evidence}
2. {hypothesis} — 因为 {evidence}

哪条有价值？任选 / 都不要 / 其他
```

**Confirm:** Confirmed → 价值点确认 ✓（internal: Value Lock）. Rejected → discard.

### Confirmed Value Point Expansion

Per confirmed value point, present 4 facets with recommended values:

| Facet | Question |
|-------|----------|
| Scope | How broadly does this apply? |
| Priority | Importance vs primary goal? |
| Operational | Additional info needed to deliver? |
| Boundary | Where should this NOT extend? |

Recommendation-first table. User flags dimension → expand with A/B/C.

### Dig Deeper Loop

After facet exploration: A) Dig deeper (new hypotheses from confirmed locks) B) Converge.

Limits: 3 rounds without convergence → ask user to redefine boundaries. Max 6 rounds → force converge.

After value exploration completes, re-enter Step 2 Converge to finalize the conclusion including any confirmed value points.

---

## Completion

- 6-slot frame filled, user confirmed
- Conclusion + example confirmed
- Handoff written
- Value points explored (if value mining triggered)

## Recovery

- One-word answers → switch to A/B/C choices
- Scope expanding → "Split into separate sprints. Which first?"
- Can't define success → give concrete options
- All hypotheses rejected → proceed without value points
