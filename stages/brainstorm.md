# brainstorm

Align user intent through structured demand modeling and controlled value discovery.

Pure conversation. Do NOT read code, files, or docs. All evidence comes from the user.

## Hard Rules

- Never ask broad open-ended exploratory questions.
- Only expand from confirmed hypotheses.
- Ask at most one follow-up question per round.
- Prefer multiple-choice questions (always 3 options).
- Each question must state why it is being asked.
- If no question materially changes the output, converge.

## Mode

From evaluate output `clarify` level:

- **clarify=1:** Layer 1 → Layer 3 (demand modeling only)
- **clarify=2:** Layer 1 → Layer 2 → Layer 3 (demand modeling + value mining)

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

**Step 3:** For each missing slot, ask one question with 3 options. Wait for reply before asking the next slot.

Format per question:
```
{Why this matters for downstream}: {slot name} is unclear.

A) {most likely interpretation}
B) {alternative}
C) {another alternative}
```

**Step 4:** Present filled frame to user:

```
───────────────────────────────────────
  📋 Demand Frame
───────────────────────────────────────
  🎯 Goal        {in user's words}
  📦 Object      {as user sees it}
  🔒 Constraint  {or "TBD in design"}
  📍 Context     {plain terms}
  ✅ Success     {how user knows it works}
  ⚡ Priority    {ranking or "single item"}
───────────────────────────────────────
```

User confirms → Demand Anchor locked. Corrections → update and re-confirm.

---

## Layer 2: Value Mining (clarify=2 only)

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

For each confirmed value anchor, explore 4 facets sequentially. One question per facet, each with 3 options. Wait for reply before next facet.

| Facet      | Question                                                    |
| ---------- | ----------------------------------------------------------- |
| Scope      | How broadly does this value point apply?                    |
| Priority   | How important is this compared to your primary goal?        |
| Operational| What additional info is needed to deliver this value?       |
| Boundary   | Where should this value point NOT extend to?                |

Format per facet:
```
{Facet context}: {why asking this}

A) {option}
B) {option}
C) {option}
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
═══════════════════════════════════════
  🐰 Brainstorm Conclusion
═══════════════════════════════════════

  💡 {1 sentence — what to build}

  📖 Example
  ┌─ Before: {now}
  ├─ After:  {then}
  └─ Verify: {how to check}

  🔍 Value Points (if any)
  ├─ {confirmed point 1}
  └─ {confirmed point 2}

═══════════════════════════════════════
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
- Value anchors + facets explored (clarify=2 only)

## Early Exit

- Needs already fully specific → skip to Step 8, still confirm conclusion
- No reasonable hypotheses → skip Layer 2
- User rejects value mining → skip Layer 2

## Recovery

- One-word answers → switch to A/B/C choices
- Scope expanding → "Split into separate sprints. Which first?"
- Can't define success → give concrete options
- All hypotheses rejected → normal, proceed without value points
