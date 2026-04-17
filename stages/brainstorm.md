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

**Pushback template** (render in user language):

```
Sanity Gate: {N} item(s) to clarify

- Q{n} ({short label}): {1-line reason}
  {if Q3 or Q4 triggered: list the 3 expansion sub-questions here}

Please choose: A) clarify / supply info   B) insist with justification   C) revise the requirement
```

After user responds — if clarification resolves the triggers, proceed to 6-slot modeling. If user insists with justification, record the acknowledged risk in the Demand Frame `Context` slot and proceed. If requirement is revised, re-run the gate on the revised description.

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

**Extract** visible slots from description. Rank gaps by downstream impact.

**Clarify** — present inferred slots + clarification questions in ONE round (slots are interdependent; batch asking is more efficient than sequential):

```
Here's what I inferred — confirm, correct, or fill in the blanks:

- **Goal**: {inferred or "not mentioned — A) ... B) ... C) ..."}
- **Object**: ...
- **Constraint**: ...
- **Context**: ...
- **Success**: ...
- **Priority**: ...
```

User confirms → Demand Lock locked. Corrections → update (max 1 follow-up).

**Lock** — present final demand frame, then evaluate Gate for Step 2.

Gate evaluation (internal, not shown to user):

For each diagnostic below, answer yes/no based solely on the locked demand frame:

| # | Question | yes signal |
|---|----------|------------|
| 1 | Will this task be done more than once? | Context mentions recurring trigger or pattern |
| 2 | Is there a manual step that could be eliminated? | Goal includes manual workflow |
| 3 | Could the result fail silently? | No validation in Success criteria |
| 4 | Is the output reusable by other features? | Object touches shared module or produces artifact |
| 5 | Does an implicit decision deserve to be explicit? | Constraint or Priority contains hidden assumption |

Count yes answers. ≥2 → recommend triggering Optional Value Mining. Otherwise → proceed directly to conclusion.

Present to user:

```
Demand Lock ✓

[If ≥2 yes — recommend triggering Optional Value Mining]
I noticed {convert top 2 "yes" items into plain-language observations, e.g. "this workflow will be repeated — templating opportunity" / "the output artifact is referenced by other modules"}.
A) Explore these directions (Optional Value Mining)  B) Skip to conclusion

[If <2 yes — proceed directly]
Requirements are clear — proceeding to conclusion. Speak up if you see directions worth exploring.
```

### Few-shot

Good: `Goal: Add dark mode to settings page | Object: SettingsViewController + theme system | Success: Toggle switches all colors; persists across launches`

Bad: `Goal: Improve the app | Object: The codebase | Success: It works better`

---

## Step 2: Converge

Model: sonnet

Present conclusion:
```
### Brainstorm Conclusion

**{1 sentence — what to build}**

**Example**
- Before: {now}
- After: {then}
- Verify: {how to check}

**Value Points** (if any)
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

## Optional Extension: Value Mining

Triggered by: explicit user request, OR Step 1 Gate recommendation (≥2 diagnostics yes). Not part of the standard brainstorm flow — runs only when demand frame suggests hidden value worth capturing and user opts in.

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

**Rank:** Present top 2-3 grounded hypotheses:
```
Beyond your stated goal, I noticed:
1. {hypothesis} — because {evidence}
2. {hypothesis} — because {evidence}

Which matter? Any / none / other?
```

**Confirm:** Confirmed → Value Lock. Rejected → discard.

### Value Lock Expansion

Per confirmed lock, present 4 facets with recommended values:

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
- Value Locks explored (if Optional Value Mining triggered)

## Recovery

- One-word answers → switch to A/B/C choices
- Scope expanding → "Split into separate sprints. Which first?"
- Can't define success → give concrete options
- All hypotheses rejected → proceed without value points
