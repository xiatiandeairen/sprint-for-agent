# brainstorm

## Progress

- total: 3
- steps:
  1. 明确你要做什么
  2. 探索额外价值
  3. 确认最终目标

Align user intent through structured demand modeling and controlled value discovery.

Pure conversation. Do NOT read code, files, or docs. All evidence comes from the user.

## Hard Rules

- Never ask broad open-ended exploratory questions.
- Only expand from confirmed hypotheses.
- Prefer multiple-choice questions (always 3 options).
- Each question must state why it is being asked.
- If no question materially changes the output, converge.

## Mode

From evaluate output `clarify` level. Grading criteria defined in SKILL.md (Mode Determination section).

- **quick:** Layer 1 → Layer 3 (demand modeling only)
- **full:** Layer 1 → Layer 2 → Layer 3 (demand modeling + value mining)

---

## Layer 1: Demand Modeling

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

**Step 1-2:** Extract visible slots from user description. Identify missing/ambiguous slots. Rank gaps by downstream impact.

**Step 3:** Present inferred slots, clarification questions for gaps, and demand frame preview in ONE round:

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

**Step 4:** After user replies, present the final demand frame (no additional confirmation round unless user made corrections):

```
### 📋 Demand Frame

- **🎯 Goal**: {in user's words}
- **📦 Object**: {as user sees it}
- **🔒 Constraint**: {or "TBD in design"}
- **📍 Context**: {plain terms}
- **✅ Success**: {how user knows it works}
- **⚡ Priority**: {ranking or "single item"}
```

After presenting the demand frame, add a mode switch prompt:

```
{If demand modeling only: Want to explore additional value directions? Say so and I'll switch to value mining mode.}
{If full mode: If the scope is already clear enough, we can skip value mining and go straight to conclusion.}
```

---

## Layer 2: Value Mining (full mode only)

Controlled hypothesis generation across 4 quadrants:

| Quadrant   | Look for                                                       |
| ---------- | -------------------------------------------------------------- |
| Efficiency | Save time, reduce repetition, lower cognitive load             |
| Risk       | Reduce errors, improve consistency, prevent omissions          |
| Growth     | Improve quality, increase reusability, enable collaboration    |
| Strategy   | Expose decision variables, long-term planning, reusable assets |

### Execution

**Step 5:** Generate 0-1 hypothesis per quadrant. Skip if nothing reasonable. Do not force.

**Step 6:** Rank by impact/cost. Present top 2-3 to user:

```
Beyond your stated goal, I noticed:
1. {hypothesis} — because {evidence from user input}
2. {hypothesis} — because {evidence}

Which matter to you? Any / none / other?
```

**Step 7:** Confirmed → Value Anchor. Rejected → discard (demand anchor unaffected).

### Value Anchor Expansion

For each confirmed value anchor, present all 4 facets at once with AI's recommended values. User only corrects the ones they disagree with.

| Facet       | Question                                                    |
| ----------- | ----------------------------------------------------------- |
| Scope       | How broadly does this value point apply?                    |
| Priority    | How important is this compared to your primary goal?        |
| Operational | What additional info is needed to deliver this value?       |
| Boundary    | Where should this value point NOT extend to?                |

Format — all facets in one round per value anchor:
```
Value Anchor: "{anchor}"
- Scope: {A/B/C} (recommended) — {brief rationale}
- Priority: {A/B/C} (recommended) — {brief rationale}
- Operational: {A/B/C} (recommended) — {brief rationale}
- Boundary: {A/B/C} (recommended) — {brief rationale}

Mark which ones to change, or confirm all.
```

Options per facet (always 3):
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
- Maximum 6 rounds total. After round 6 → force converge to Layer 3.

---

## Layer 3: Converge

**Step 8:** Present conclusion:

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

**Step 9:** Write `.sprint/{id}/handoffs/brainstorm.md`:

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
- Value anchors + facets explored (full mode only)

## Early Exit

- Needs already fully specific → skip to Step 8, still confirm conclusion
- No reasonable hypotheses → skip Layer 2
- User rejects value mining → skip Layer 2

## Recovery

- One-word answers → switch to A/B/C choices
- Scope expanding → "Split into separate sprints. Which first?"
- Can't define success → give concrete options
- All hypotheses rejected → normal, proceed without value points
