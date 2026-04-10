# brainstorm

## Progress

- total: 3
- steps:
  1. What exactly do you want?
  2. Any hidden value worth capturing?
  3. Lock the conclusion

Align user intent through demand modeling and controlled value discovery.

Pure conversation. Do NOT read code, files, or docs. All evidence comes from the user.

## Hard Rules

- Each question must target a specific slot or hypothesis. No open-ended exploration.

---

## Step 1: Demand Modeling

Model: opus

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

**Lock** — present final demand frame, then Gate question for Step 2:

```
你的需求背后是否有未发现的价值方向？
💡 明确的功能点实现 → 直接进入结论；新方向或战略性需求 → 值得探索。
```

### Few-shot

Good: `Goal: Add dark mode to settings page | Object: SettingsViewController + theme system | Success: Toggle switches all colors; persists across launches`

Bad: `Goal: Improve the app | Object: The codebase | Success: It works better`

---

## Step 2: Value Mining

Gate (user): 你的需求背后是否有未发现的价值方向？

💡 明确的功能点实现 → 跳过；新方向或战略性需求 → 进入。Default: skip.

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

---

## Step 3: Converge

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

User confirms → write handoff.

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

## Completion

- 6-slot frame filled, user confirmed
- Conclusion + example confirmed
- Handoff written
- Value Locks + facets explored (if Step 2 entered)

## Recovery

- One-word answers → switch to A/B/C choices
- Scope expanding → "Split into separate sprints. Which first?"
- Can't define success → give concrete options
- All hypotheses rejected → proceed without value points
