# Test Principles — what counts as a valuable sprint unit test

Sprint is a **multi-file state machine**: SKILL.md + stages/*.md + skills/sprint/*.md (consumed by an LLM) + sprint-ctl.sh + anchor-check.sh (code + CLI) + state.json/metrics.log/anchors.txt/handoffs (data). Every pair of files has a **contract**. Tests enforce contracts. Everything else is doc lint.

## Single criterion

An assertion has value iff its failure mode can be filled into this triplet:

```
consumer: {who at runtime reads / executes / depends on this property}
when:     {at what concrete runtime moment}
failure:  {what specific observable error occurs when the property is violated}
```

Three blanks. If any blank cannot be filled with a **specific name and behavior** (not "things break" or "docs get confused") — the test is decorative, not a contract. Delete.

## Three deletion filters

Apply to every existing test; reapply to every new one.

1. **Is there a file OTHER than the one being tested that depends on this property at runtime?** If no specific file name comes out — delete.
2. **Does LLM behavior, script output, or downstream-stage input change when this property is violated?** If no concrete behavior — delete.
3. **Is the assertion subsumed by a higher-level contract test?** If yes — delete the weaker one.

## Tiers

| Tier | Type | Purpose | Example |
|------|------|---------|---------|
| **T1** | Contract test (file joint) | Catch drift between paired files | `bash "$SPRINT_CTL" <cmd>` in docs matches a case branch in the script |
| **T2** | Self-consistency (within file) | Catch intra-file drift | `- total: N` equals step-list length |
| **T3** | Behavior-critical content | Ensure AI-consumed content of runtime-critical sections exists | `### Hard Rules` has ≥5 bullets |
| **T4** | CLI contract (scripts) | Normal code unit tests | `sprint-ctl evaluate 0 0 0` stages = `plan,execute,insight` |
| **anti-T** | Pure existence / implementation echo / smoke | — | "section `## X` exists" where nothing reads it |

T1 covers the most failure modes in a sprint-shaped skill. Current suite was T3/anti-T heavy; this audit rebalances toward T1.

## Writing requirement

Every retained or new test must include a triplet docstring:

```python
def test_some_invariant(...):
    """
    consumer: {...}
    when:     {...}
    failure:  {...}
    """
    ...
```

Missing or vague triplet → test is rejected at review. "The system could break" is not a failure description; "`sprint-ctl evaluate` exits with `unbound variable` when called with `yes`/`no` because line 360 bash `set -u` triggers" is.

## Forbidden patterns

- **Smoke tests without assertions** (`cmd` runs + exit 0, no further check). The exit code is not an assertion, it's absence of a crash — crashes are test infrastructure failures, not the test itself.
- **Implementation echoes**: testing that the code does what the code says, with no cross-file coupling. These add no safety, reduce refactorability.
- **Documentation structure checks without downstream readers**: `## X section exists` when no file/script/LLM role reads `X`.
- **Existence-only checks of tables/lists** (e.g. "at least one table exists") — measure zero information about correctness.

## When a contract test goes red

Contract tests catch drift between two files. When red:
1. Figure out which side is the authority (usually the code / script, since it runs).
2. Fix the **other** side (usually docs), unless the test reveals the authority itself is wrong.
3. Do not suppress by relaxing the assertion.
