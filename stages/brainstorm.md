# brainstorm

## Progress

- total: 3
- steps:
  1. What exactly do you want?
  2. Any hidden value worth capturing?
  3. Lock the conclusion

Align user intent through structured demand modeling and controlled value discovery.

Pure conversation. Do NOT read code, files, or docs. All evidence comes from the user.

## Hard Rules

- Do not ask open-ended exploratory questions. Each question must target a specific slot or hypothesis.
- Only expand from confirmed hypotheses. Do not generate follow-ups from unconfirmed ones.
- Prefer multiple-choice questions (always 3 options) for single-dimension clarification. Multi-dimensional choices use recommendation-first table (see SKILL.md Presentation Format).
- Each question must state why it is being asked.
- If no question materially changes the output, converge.

---

## Step 1: Demand Modeling

Model: opus

Turn vague input into a 6-slot demand frame.

| Slot       | What it captures                      |
| ---------- | ------------------------------------- |
| Goal       | What to achieve                       |
| Object     | Target (feature, module, system, doc) |
| Constraint | Limits (time, compatibility, tech)    |
| Context    | Situation (why now, what triggered)   |
| Success    | How to verify done correctly          |
| Priority   | What matters most                     |

### Execution

**Extract:** Extract visible slots from user description. Identify missing/ambiguous slots. Rank gaps by downstream impact.

**Clarify:** Present inferred slots, clarification questions for gaps, and demand frame preview in ONE round:

```
Here's what I inferred — confirm, correct, or fill in the blanks:

- **Goal**: {inferred value}
- **Object**: {inferred value}
- **Constraint**: {inferred value or "not mentioned — A) ... B) ... C) ..."}
- **Context**: {inferred value or "not mentioned — A) ... B) ... C) ..."}
- **Success**: {inferred value or "not mentioned — A) ... B) ... C) ..."}
- **Priority**: {inferred value or "not mentioned — A) ... B) ... C) ..."}

For slots marked "not mentioned", pick the option that fits or write your own.
```

User confirms → Demand Anchor locked. Corrections → update and re-confirm (max 1 follow-up round).

### Few-shot: Demand Frame

Good (specific, actionable):
```
- Goal: Add dark mode support to the settings page
- Object: SettingsViewController + theme system
- Constraint: Must work on iOS 15+, no new dependencies
- Success: Toggle in settings switches all colors; persists across launches
```

Bad (vague, not actionable):
```
- Goal: Improve the app
- Object: The codebase
- Constraint: None
- Success: It works better
```

**Lock:** After user replies, present the final demand frame (no additional confirmation round unless user made corrections):

```
### 📋 Demand Frame

- **🎯 Goal**: {in user's words}
- **📦 Object**: {as user sees it}
- **🔒 Constraint**: {or "TBD in design"}
- **📍 Context**: {plain terms}
- **✅ Success**: {how user knows it works}
- **⚡ Priority**: {ranking or "single item"}
```

After presenting the demand frame, present the Gate question for Step 2:

```
你的需求背后是否有未发现的价值方向？

💡 如果这是一个明确的功能点实现，直接进入结论；如果是新方向或战略性需求，值得探索。
```

---

## Step 2: Value Mining

Gate: 你的需求背后是否有未发现的价值方向？

💡 如果这是一个明确的功能点实现，跳过；如果是新方向或战略性需求，值得探索。

Model: opus

Controlled hypothesis generation via diagnostic questions (ask internally, not to user):

| Question | If yes → hypothesis direction |
|----------|-------------------------------|
| Is the user doing this task repeatedly? | Automate or template the repetitive part |
| Is there a manual step that could be eliminated? | Remove the step or make it one-click |
| Could this task fail silently? | Add a consistency check or validation |
| Is there a consistency check missing? | Build verification into the workflow |
| Could the output be reused elsewhere? | Extract as a shared asset or template |
| Would others benefit from this capability? | Generalize for team/project use |
| Is a decision being made implicitly that should be explicit? | Surface the decision as a configurable parameter |
| Is there a pattern here that will recur? | Build a reusable solution instead of one-off |

### Execution

**Diagnose:** Run through the diagnostic questions against the user's stated goal. For each "yes", formulate a specific hypothesis grounded in the user's context. Skip questions where the answer is clearly "no". Do not force hypotheses.

**Rank:** Rank confirmed hypotheses by impact/cost. Present top 2-3 to user:

```
Beyond your stated goal, I noticed:
1. {hypothesis} — because {evidence from user input}
2. {hypothesis} — because {evidence}

Which matter to you? Any / none / other?
```

**Confirm:** Confirmed → Value Anchor. Rejected → discard (demand anchor unaffected).

### Few-shot: Hypothesis Quality

Good (grounded in user context, specific benefit):
```
"You mentioned updating 3 config files manually each release — a shared config template could eliminate that repetition."
```

Bad (generic, no grounding):
```
"This could improve code quality and maintainability across the project."
```

### Value Anchor Expansion

For each confirmed value anchor, present all 4 facets at once with AI's recommended values. User only corrects the ones they disagree with.

| Facet       | Question                                                    |
| ----------- | ----------------------------------------------------------- |
| Scope       | How broadly does this value point apply?                    |
| Priority    | How important is this compared to your primary goal?        |
| Operational | What additional info is needed to deliver this value?       |
| Boundary    | Where should this value point NOT extend to?                |

Format — recommendation-first table per value anchor:
```
Value Anchor: "{anchor}"

| 维度 | 推荐 | 理由 |
|------|------|------|
| 范围 | {recommended value} | {brief rationale} |
| 优先级 | {recommended value} | {brief rationale} |
| 前置信息 | {recommended value} | {brief rationale} |
| 边界 | {recommended value} | {brief rationale} |

全部接受，或标出要改的维度。
```

If user flags a dimension, expand that dimension only with 3 options:
```
Scope       — A) this feature only  B) this module  C) system-wide
Priority    — A) secondary to goal  B) equal weight  C) higher than goal
Operational — A) no extra info needed  B) needs {x}  C) needs {x} and {y}
Boundary    — A) strict limit  B) soft limit  C) no explicit limit
```

### Dig Deeper Loop

After all 4 facets are explored for current value anchors, ask:

```
A) Dig deeper — explore more dimensions based on what we confirmed
B) Converge — proceed with current results
```

**If A:** Generate new hypotheses building on confirmed value anchors (not from scratch). Repeat Step 5 → Step 7 → 4-facet expansion → dig deeper prompt.

**Loop limits:**
- After 3 rounds without user confirming convergence → ask user to redefine boundaries via counter-questions, then anchor.
- Maximum 6 rounds total. After round 6 → force converge to Step 3.

---

## Step 3: Converge

Model: sonnet

**Present:** Present conclusion:

```
### 🐰 Brainstorm Conclusion

**💡 {1 sentence — what to build}**

**📖 Example**
- Before: {now}
- After: {then}
- Verify: {how to check}

**🔍 Value Points** (if any)
- {confirmed point 1}
- {confirmed point 2}

---
```

User confirms → write handoff.

**Write:** Write `.sprint/{id}/handoffs/brainstorm.md`:

```markdown
# brainstorm Handoff

## Conclusion
{1 sentence}

## Demand Frame
- Goal: {goal}
- Object: {object}
- Constraint: {constraint}
- Context: {context}
- Success: {success}
- Priority: {priority}

## Scope
### In
- {item}
### Out
- {item}

## Value Points
- {confirmed hypothesis + facet details}

## Downstream
{what next stage needs to know}
```

---

## Completion

- 6-slot frame filled, user confirmed
- Conclusion + example confirmed
- Handoff written
- Value anchors + facets explored (if Step 2 entered)

## Early Exit

- Needs already fully specific → skip to Step 8, still confirm conclusion
- Gate not passed → skip Step 2
- No reasonable hypotheses in Step 2 → proceed to Step 3

## Recovery

- One-word answers → switch to A/B/C choices
- Scope expanding → "Split into separate sprints. Which first?"
- Can't define success → give concrete options
- All hypotheses rejected → normal, proceed without value points
