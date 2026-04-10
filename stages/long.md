# long

## Progress

- total: 6
- steps:
  1. Value Diverge
  2. Value Converge & Rank
  3. Difficulty Annotation
  4. Blind Spot Prompting
  5. Sprint Splitting & Confirm
  6. Write Handoffs

Discover value, map difficulty, scan blind spots, split into ordered sub-sprints.

Pure conversation. Do NOT read code, files, or docs. All evidence comes from the user.

## Hard Rules

- Max 1 question per round (value discovery requires deep thinking; batch questions lead to shallow answers).
- Direction Lock is immutable after user confirmation.

---

## Step 1: Value Diverge

Model: opus

One open question:
```
What should be different after this is done?
(What pain goes away, what becomes possible, who benefits?)
```

Extract 3-7 candidate value propositions. Each: "{who} can {do what} / no longer suffers from {what}."

## Step 2: Value Converge & Rank

Model: opus

### Converge

Per candidate (one at a time):
```
If we only did "{candidate}", with nothing else, is it worth it?
A) Yes — valuable on its own
B) Only if combined with {another}
C) Not sure / depends
```

A → must-have (independent). B → merge or nice-to-have. C → one follow-up, then classify.

### Rank

```
If you could only deliver two value points, which two?
A) {top 1} + {top 2}
B) {top 1} + {top 3}
C) Different pair — tell me which
```

Reorder: must-haves first by priority, then nice-to-haves.

### Output

```
### Value Points
**Must-have** (ordered)
1. {value point} — {who, how}

**Nice-to-have**
- {value point}

**Excluded**
- {candidate} — reason
```

User confirms → locked.

---

## Step 3: Difficulty Annotation

Model: opus

Per must-have (one at a time):
```
For "{value point}": What's the hardest part? Any concerns?
```

AI supplements unmentioned technical difficulties. Score:
- Changes >3 files? → +1
- Touches public interface / shared data? → +1
- User couldn't answer unknowns? → +1

0 → low, 1 → medium, 2-3 → high.

---

## Step 4: Blind Spot Prompting

Model: sonnet

Per must-have, run internally:
1. Changes data formats/storage? → migration risk
2. Can fail without user noticing? → silent failure risk
3. Changes behavior other modules depend on? → cross-module impact
4. How to roll back? No clear answer → rollback risk
5. Needs new tests or existing cover it? → test gap

Present only "yes" / "no clear answer" results:
```
A few things easy to miss:
1. {blind spot} — affects {value point}

Which need attention? Any / none / others?
```

Tag confirmed → value point. Rejected → discard.

---

## Step 5: Sprint Splitting

Model: opus

### Requirements Per Sub-Sprint

1. **Value target**: "{who} can {do what}." Can't write it → not independent → merge.
2. **Task substance**: specific changes + verifiable behavior. Can't list → ask more.

### Validation

- Independent delivery: "If we stop after this sprint, does the user have something usable?"
- Dependency chain: no cycles, no chains >5, inputs from prior handoff.

```
Sprint {n}: {value target}
- Task substance: {specific changes}
- Type: simple / medium
- Stages: plan → execute → quality
- Depends on: Sprint {n-1} / none
- Difficulty: {from Step 3} | Blind spots: {from Step 4 or none}
- Expected output: {verifiable behavior change}
```

Present full plan. [STOP:confirm]: A) Confirm — start execution B) Adjust C) Re-split.

## Step 6: Write Handoffs

Model: sonnet

**`.sprint/{id}/handoffs/preparation.md`:**
```markdown
## End-State
{what is true when all sub-sprints complete}
## Value Points (ordered)
### Must-have / ### Nice-to-have / ### Excluded
## Sub-Sprint Plan
### Sprint {N}: {value target}
- Task substance / Type+Stages / Dependency / Difficulty+Blind spots / Expected output
## Downstream
```

**`.sprint/{id}/anchors/direction.md`** (immutable):
```markdown
# Direction Lock
## End-State
## Per Sub-Sprint Value Targets
## Explicit Exclusions
```

---

## Completion

- Value points ordered, confirmed
- Difficulty tags on all must-haves
- Blind spots surfaced and tagged
- Sub-sprint plan confirmed
- preparation.md + direction.md written

## Early Exit

- Already decomposed → skip to Step 5
- Single value point fits one sprint → suggest regular sprint
- User rejects blind spots → proceed without tags

## Recovery

- One-word answers → A/B/C choices
- Scope expanding → "New value point. Add to nice-to-have or split off?"
- Can't define value target → "What does user have after this sprint that they didn't before?"
- Chain >5 → "Can any run in parallel or be cut?"
- User re-opens direction → "Direction locked. Scope changes → follow-up sprint."
