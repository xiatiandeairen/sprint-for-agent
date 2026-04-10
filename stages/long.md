# long

## Progress

- total: 7
- steps:
  1. Value Diverge
  2. Value Converge & Rank
  3. Difficulty Annotation
  4. Blind Spot Prompting
  5. Sprint Splitting
  6. Write Handoffs
  7. Confirm & Lock

Discover value, map difficulty, scan blind spots, and split a large task into ordered sub-sprints ready for automatic execution.

Pure conversation. Do NOT read code, files, or docs. All evidence comes from the user.

## Hard Rules

- Ask at most 1 question per round. Each question must state why it is being asked.
- Provide 3 options (A/B/C) for single-dimension clarification. Multi-dimensional choices use recommendation-first table.
- Only expand from confirmed answers. Do not generate follow-ups from unconfirmed hypotheses.
- After user confirms a split plan, the direction anchor is immutable — do not re-open it in subsequent stages.
- Do not ask questions whose answer does not change any downstream output. If all slots are filled, converge.

---

## A1. Value Discovery

Model: opus

Turn a large ambiguous task into an ordered list of independent value propositions.

### Step 1: Diverge

Ask the user one open question to surface raw intent:

```
To figure out what's really worth doing:

What should be different after this is done?
(What pain goes away, what becomes possible, who benefits?)
```

Extract 3–7 candidate value propositions from the user's answer. Each candidate must be expressible as: "{who} can {do what} / no longer suffers from {what}."

### Step 2: Converge

For each candidate, test independence. Ask per candidate (one at a time, wait for reply):

```
{Why this test matters}: If we only did "{candidate}", with nothing else, is it worth it?

A) Yes — valuable on its own
B) Only if combined with {another candidate}
C) Not sure / depends on context
```

- Answer A → **must-have**, mark independent.
- Answer B → merge with named candidate or downgrade to nice-to-have.
- Answer C → ask one clarifying follow-up, then re-classify.

### Step 3: Rank

Once all candidates are classified, force a ranking:

```
To reveal true priorities:

If you could only deliver two value points, which two?

A) {top candidate 1} + {top candidate 2}
B) {top candidate 1} + {top candidate 3}
C) Different pair — tell me which
```

Reorder the full list based on the answer. Must-haves come first, ordered by priority; nice-to-haves follow.

### Output

Present the ordered value list:

```
### Value Points

**Must-have** (ordered)
1. {value point} — {who benefits, how}
2. {value point} — {who benefits, how}

**Nice-to-have**
- {value point}

**Excluded**
- {candidate} — merged into #{n} / deprioritized

---
```

User confirms → value list locked. Corrections → update and re-confirm.

---

## A2. Difficulty Annotation

Model: opus

Per must-have value point, surface concerns before splitting.

### Step 4

For each must-have, ask the user (one at a time, wait for reply):

```
For "{value point}":

What's the hardest part? Any concerns?
(technical unknowns, risky dependencies, things you're unsure about)
```

After the user answers, AI supplements potential technical difficulties not mentioned. Then assess difficulty using these criteria:

- Does it require changes to >3 files? → +1
- Does it touch a public interface or shared data structure? → +1
- Are there unknowns the user couldn't answer? → +1

Score 0 → **low**, 1 → **medium**, 2-3 → **high**.

Keep it conversational. One exchange per value point.

---

## A3. Blind Spot Prompting

Model: sonnet

Based on the full value list and difficulty tags, run diagnostic questions to surface missed concerns.

### Step 5

For each must-have value point, run these diagnostic questions internally:

1. Does this change existing data formats or storage? → migration risk
2. Can this fail without the user noticing? → silent failure risk
3. Does this change behavior that other modules depend on? → cross-module impact
4. How would you roll this back? If no clear answer → rollback risk
5. Does this need new tests, or do existing tests cover it? → test gap

Present only questions answered "yes" or "no clear answer" as blind spots:

```
A few things that are easy to miss:

1. {specific blind spot from diagnostic} — affects {value point}
2. {specific blind spot from diagnostic} — affects {value point}

Which need attention? Any / none / others?
```

Tag confirmed blind spots onto corresponding value points. Rejected → discard.

---

## A4. Sprint Splitting

Model: opus

Split the ordered value list into executable sub-sprints.

### Hard Requirements Per Sub-Sprint

Every sub-sprint must satisfy both:

1. **Value target**: one sentence — "{who} can {do what} / no longer suffers from {what}". If you can't write it, the sprint is not independent → merge it.
2. **Task substance**: specific what changes + verifiable behavior change. If you can't list it, understanding is insufficient → ask more in preparation.

### Validation Checks

Before finalizing the split, verify:

- **Independent delivery**: "If we stop after this sprint, does the user have something usable?"
- **Dependency chain**: no cycles, no long serial chains (>5 sprints), inputs obtainable from prior handoff.

### Step 6

Generate a sub-sprint plan. For each sub-sprint:

```
Sprint {n}: {value target}
- Task substance: {specific what changes}
- Type: simple / medium
- Stages: plan → execute → quality
- Depends on: Sprint {n-1} / none
- Difficulty: {low / medium / high} (from A2)
- Blind spots: {tagged items from A3, or none}
- Expected output: {verifiable behavior change}
```

Present the full plan:

```
### Sub-Sprint Plan

**Sprint 1**: {value target}
...

**Sprint 2**: {value target}
...

**Total**: {n} sprints | **Execution**: automatic, sequential

---

Confirm this split? Once confirmed, the direction is locked and execution begins automatically.

A) Confirm — start execution
B) Adjust — I want to change {something}
C) Re-split — the grouping is wrong
```

Wait for explicit confirmation before proceeding.

### Step 7: Write Handoffs

After user confirms, write both output files.

**Write `.sprint/{id}/handoffs/preparation.md`:**

```markdown
# Preparation Handoff

## End-State
{1 sentence: what is true when all sub-sprints complete}

## Value Points (ordered)

### Must-have
- {value point} — {who benefits, how}

### Nice-to-have
- {value point}

### Excluded
- {candidate} — reason

## Sub-Sprint Plan

### Sprint 1: {value target}
- Task substance: {specific changes}
- Type / Stages: {simple|medium} / plan → execute → quality
- Dependency: none / Sprint {n}
- Difficulty / Blind spots: {low|medium|high} / {tagged items or none}
- Expected output: {verifiable behavior change}

### Sprint 2: {value target}
- Task substance: {specific changes}
- Type / Stages: {simple|medium} / plan → execute → quality
- Dependency: Sprint 1
- Difficulty / Blind spots: {low|medium|high} / {tagged items or none}
- Expected output: {verifiable behavior change}

## Downstream
{what the first sub-sprint executor needs to know}
```

**Write `.sprint/{id}/anchors/direction.md`:**

```markdown
# Direction Anchor

⚠️ This file is immutable after user confirmation. Do not re-open scope decisions.

## End-State
{1 sentence}

## Per Sub-Sprint Value Targets
1. Sprint 1: {value target}
2. Sprint 2: {value target}

## Explicit Exclusions
- {excluded candidate} — reason
```

---

## Completion

- Value points ordered, user confirmed
- Difficulty tags assigned to all must-haves
- Blind spots surfaced and tagged
- Sub-sprint plan confirmed by user
- `preparation.md` handoff written
- `direction.md` anchor written

## Early Exit

- Task already fully decomposed → skip A1–A3, go directly to A4 split presentation
- Single value point that fits one sprint → suggest using a regular sprint instead of long
- User rejects blind spot prompts → proceed without tags

## Recovery

- One-word answers → switch to A/B/C choices
- Scope expanding mid-split → "This looks like a new value point. Add to nice-to-have or split off entirely?"
- Can't define value target for a sprint → "What does the user have after this sprint that they didn't before?"
- Dependency chain too long (>5) → "Can any of these run in parallel or be cut entirely?"
- User wants to re-open direction after confirmation → "Direction is locked. Scope changes go into a follow-up sprint."
