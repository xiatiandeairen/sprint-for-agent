# review

## Progress

- total: 6
- steps:
  1. What changed and why?
  2. Five-layer analysis
  3. Governance opportunities
  4. Here's what I found
  5. Record review results
  6. Your call

Change governance engine. Not a code style reviewer. Not a correctness re-checker. Judges design decisions, structural quality, pattern spread, long-term maintenance cost, and automation opportunities.

**Identity**: execute already covers task-level testing and functional verification. Review answers: did this change degrade overall quality, spread bad patterns, or miss high-ROI governance opportunities?

**First principle**: judge problem value by future modification cost, not personal preference.

A problem is worth flagging only when it:
- Increases future understanding cost
- Increases future modification cost
- Increases future error probability
- Breaks codebase consistency
- Copies or spreads bad patterns
- Obscures real domain model / design boundaries
- Has high-ROI governance opportunity (autofix/codemod/rule)

Low-priority (do not emphasize): subjective style preference, low-value naming disputes, minor blemishes not affecting long-term evolution, issues better left to formatter/linter, speculation without evidence.

## Hard Rules

- Do not repeat execute's functional verification. Exception: implementation is obviously "passing tests by evading real problems".
- Do not flag issues outside changed files and their direct dependents.
- Do not output per-file line-by-line commentary. Analyze by layer, not by file.
- Do not force findings. "No issues at this layer" is valid output.
- Do not classify user-requested changes as issues. Change-requests are neutral.
- Every finding must use the 12-field problem template. No free-form complaints.
- Prefer fewer high-leverage findings over many low-value observations.

## Input

- execute handoff: tasks completed, files changed, test scope
- design handoff (if exists): Decision Register, File Structure
- plan handoff (if exists): task breakdown, anchors
- `git diff {base_commit}`

---

## Trigger

Review runs when any of these hold:
- risk=yes (from evaluate)
- tasks >1 AND cross-module changes (detected from plan handoff)

## Step 0: Cross-Task Regression

Model: sonnet

Gate (auto): plan handoff 任务数 >1 且任务间有共享文件或模块依赖 → 执行。否则跳过。

Do NOT repeat single-task checks from execute. Only verify cross-task integration:

1. **Public interface changes** — identify consuming modules for each changed API/protocol/type
2. **New dependencies** — verify acyclic dependency graph, lower modules don't depend on higher
3. **Deletions / renames** — scan for stale references

```
### Cross-Task Regression — PASS ✓ / FAIL ✗

**变更影响分析**
- 接口变更: {affected consumers or "无"}
- 依赖方向: ✓ / 发现违规
- 残留引用: 无 / {list}
```

Fail → return to execute to fix. Pass → continue to Step 1.

## Step 1: Change Understanding

Model: opus

Gate (auto): execute handoff 中 completed tasks >0 → 执行。否则跳过整个 review。

Read execute handoff + design handoff (if exists) + git diff. Build mental model:

```
## A. Change Understanding

- **Problem**: {what this change solves}
- **Approach**: {main design/implementation strategy}
- **Key decision points**: {where alternatives existed and choices were made}
- **Review focus**: {which areas deserve deepest scrutiny and why}
```

Do not read code line-by-line. Understand intent, strategy, and decision points.

## Step 2: Five-Layer Analysis

Model: opus

Core analysis engine. Work through layers sequentially. Each layer has specific checks. Report only substantive findings — skip layers with nothing to flag.

### L1: Task-Level Residual Risk

Baseline safety net. Do not repeat execute's work. Only flag if implementation is obviously fragile.

**Checks**:

| Check | What to look for | Flag when |
|-------|-----------------|-----------|
| Happy-path-only | Error/failure paths not handled | New public function has no error return or catch |
| Test-passing fragility | Implementation shaped to pass tests, not solve the problem | Test asserts on implementation detail (mock call count, internal state) rather than behavior |
| Hardcoded constraints | Critical limits or thresholds baked into code | Magic numbers that should be configurable or derived |
| Mock concealment | Mocks hide real integration issues | Mock returns success unconditionally; no test with real dependency |
| Uncovered boundaries | Obvious edge cases missing | Empty input, zero, nil, max value, concurrent access — none tested |

**Execution**: scan changed public functions and their tests. Per function: do error paths exist? Do tests cover >1 path? Are mocks realistic?

If nothing found → "L1: 无残留风险". Do not spend more than 10% of review effort here.

### L2: Code Decision Quality

**Focus layer**. Judges whether each code decision is the simplest correct choice or introduces accidental complexity.

**Checks**:

| Check | What to look for | Flag when |
|-------|-----------------|-----------|
| Wrong abstraction | Pattern doesn't match the problem shape | Using strategy pattern for 2 fixed cases; using inheritance where composition fits |
| Unnecessary indirection | Extra layer/wrapper that adds no value | Wrapper that delegates 1:1 to inner, adding only complexity |
| One-off as interface | Temporary logic packaged as reusable API | Public interface with exactly 1 caller and no foreseeable second |
| Workaround as design | Local fix disguised as general solution | Function named generically but handles only one specific case |
| False generalization | Looks extensible but actually harder to change | Parameterized code where every "parameter" is actually hardcoded to one value |
| Patch-on-patch | Legacy modification that bypasses rather than fixes | Adding a check before calling broken function instead of fixing the function |

**Execution**: for each new/modified abstraction (class, interface, module, significant function):
1. Count callers. 1 caller + generic name → suspect one-off-as-interface
2. Check parameter usage. All params always same value → suspect false generalization
3. Check if modification touches root cause or adds indirection around it → patch-on-patch signal

**Key question**: "If another developer needs to modify this in 3 months, will the current structure help or hinder?"

### L3: Structural Quality

**Focus layer**. Judges whether the change makes the codebase structure better or worse along 7 axes.

**Checks**:

| Axis | Better signal | Worse signal | How to detect |
|------|--------------|--------------|---------------|
| Module boundaries | Responsibilities more concentrated per module | Module now handles unrelated concerns | Check if new code in module matches module's stated/implied purpose |
| Dependency direction | Dependencies flow from high-level → low-level | Low-level module imports high-level | Trace imports in changed files; draw dependency direction |
| Data flow | Fewer hops from source to consumer | Data passed through extra intermediaries or transformed redundantly | Trace data from origin to final use across changed files |
| State management | State owned by fewer, clearer owners | New shared mutable state, or state ownership ambiguous | Check for new globals, singletons, shared refs, or state without clear owner |
| Error handling | Error strategy consistent with codebase convention | New error pattern diverges from existing (e.g., exceptions where codebase uses Result) | Compare error handling in changed files with 2-3 existing files in same module |
| Interface conventions | Naming/signatures follow established patterns | New API breaks naming convention or uses different parameter style | Compare new public symbols with existing ones in same module |
| Coupling | Modules interact through defined interfaces | Module A reaches into module B's internals | Check for imports of internal/private symbols, or knowledge of another module's implementation details |

**Execution**: per axis, compare before-state (from git diff context) with after-state. Score: improved / unchanged / degraded. Only report degraded axes with specific evidence.

### L4: Pattern Layer

**Highest value layer**. Identifies whether this change introduces, spreads, or reduces patterns — not just point issues.

**Bad pattern signals**:

| Signal | Detection method | Example |
|--------|-----------------|---------|
| Duplication growth | Same logic in >1 place with minor variation | Two functions that parse config with slightly different field lists |
| Special-case proliferation | if/switch branch added for one-off scenario | `if (type == "legacy_v2")` added to generic handler |
| Temp-compat permanence | Compatibility code with no TODO/expiry/removal plan | Migration shim with no version check or deadline |
| Implicit protocol | Behavior depends on undocumented call ordering or naming convention | Function must be called after init() but nothing enforces or documents this |
| Abstraction bypass | Code reaches past existing abstraction to lower layer | Directly calling DB query when a repository method exists |
| Config scatter | Constants/config values spread across files | Timeout value defined in 3 different files |
| Error style drift | New error handling inconsistent with module's existing pattern | Returning error codes in a module that uses exceptions |
| Type boundary weakening | Type becomes less specific (e.g., typed → any/object) | Parameter changed from `UserId` to `string` |
| Shared mutable state growth | New globals, singletons, or unprotected shared mutation | Module-level variable modified by multiple functions |
| Debt replication | Known bad pattern copied into new code | New code copies the same anti-pattern from legacy module |
| Name-semantics decoupling | Name implies X, implementation does Y | `validateInput()` that also transforms and persists |
| Layer violation | Domain logic placed in wrong architectural layer | Business rule inside HTTP handler or UI component |

**Good pattern signals**:

| Signal | Detection method | Example |
|--------|-----------------|---------|
| Abstraction convergence | Multiple ad-hoc approaches replaced by one | 3 different date parsers replaced by single utility |
| Interface clarity | API semantics more explicit after change | Opaque `process(data)` → `validateAndStore(order)` |
| Error handling unification | Multiple error strategies converged to one | Mixed exception/error-code replaced by consistent Result type |
| State boundary tightening | Shared state reduced or ownership clarified | Global config replaced by injected dependency |
| Dependency direction fix | Lower layer stops importing higher layer | Infrastructure module no longer imports domain types |
| Reuse centralization | Scattered duplicates consolidated into single source | 4 copies of retry logic → shared retry utility |
| Type/constraint strengthening | Types become more specific or validated | `string` → `EmailAddress` with validation |
| Rule codification | Implicit convention made explicit and checkable | Undocumented ordering requirement → compile-time or runtime check |
| Special-case normalization | One-off hack restored to general model | `if legacy` branch removed, legacy data migrated to standard format |

**Execution**: for each pattern finding, answer 4 questions:
1. **Instance or systemic?** — Is this a one-off occurrence or does grep reveal the same pattern elsewhere?
2. **Introduced or pre-existing?** — Did this change create the pattern or copy/extend an existing one?
3. **Point fix or class fix?** — Should only this instance be fixed, or all instances of the same pattern?
4. **Automatable?** — Can detection or fixing be done mechanically (AST/codemod/lint)?

### L5: Evolution Layer

Strategic assessment. Judges the change's net effect on codebase trajectory.

**Checks**:

| Question | How to answer |
|----------|---------------|
| Net direction | Count L3 axes degraded vs improved. Count L4 bad signals vs good signals. Majority determines direction. |
| Systemic opportunity | Any L4 bad signal with scope "cross-module-systemic" → systemic governance opportunity |
| New rule candidate | Any finding where detection is mechanical and occurrence is ≥2 → lint/check candidate |
| New convention candidate | Any finding where the "right" approach is clear but not documented → team convention candidate |

**Net evolution judgment**: improvement / neutral / degradation. Must state reason in one sentence referencing specific evidence from L3/L4.

### Problem Template

For each finding worth flagging, produce this structure:

```
### {title: one sentence describing the problem essence}

- **Layer**: L1 / L2 / L3 / L4 / L5
- **Severity**: blocking / important / opportunistic
- **Observation**: {what was concretely observed}
- **Essence**: {why this is not a surface issue — what decision/structure/pattern problem it reflects}
- **Impact**: {how it increases future modification cost, complexity, or error rate}
- **Scope**: local / same-module-same-class / cross-module-systemic
- **Action**: fix_now / autofix_now / codemod_candidate / rule_candidate / defer_with_reason / ignore_with_reason
- **Fix**: {concrete executable modification suggestion}
- **Spread fix**: yes / no
- **Spread boundary** (if yes): current file / current module / same abstraction layer / whole project
- **Spread risk** (if yes): {what could go wrong with spread fix}
- **Automation**: not automatable / local autofix / codemod-AST / lint rule-static check-test guard
```

## Step 3: Governance Opportunities

Model: opus

Gate (auto): Step 2 产出了 ≥1 个 finding → 执行。否则跳过。

For each finding with automation potential, assess:

### Autofix Assessment

| Question | Answer |
|----------|--------|
| Automation target | {what exactly gets automated} |
| Precondition | {what must be true for safe automation} |
| Automation risk | {what could break} |
| Verification method | {how to confirm automation didn't break behavior} |

### Spread Fix Decision

Allow spread fix only when majority of these hold:
- Same bad pattern repeats in multiple locations
- Fix is mechanical, stable, consistent
- Scope is controllable
- No additional product/architecture decision needed
- Can be safely done via codemod/AST/lint autofix/rule replacement
- Completion significantly improves consistency

Refuse spread fix when any of these hold:
- Would inflate current change into secondary refactor
- Different locations have different semantics, cannot mechanically unify
- Requires new architecture decision
- Risk exceeds consistency benefit
- Would introduce excessive context-switching and verification cost

### Convention Candidates

If findings have recurrence potential, assess:
- New review checklist item?
- New lint/check/rule?
- New test guard?
- New team convention?

## Step 4: Present Findings

Model: sonnet

Compile Steps 1-3 into A-H output. This is the review deliverable.

```
## A. Change Understanding
{from Step 1}

## B. Conclusion Overview
{3-7 most important conclusions, priority-ordered, no vague statements}

## C. Core Issues
{findings using problem template, sorted by severity then layer}

## D. Pattern Signals

**Bad pattern signals**:
- {signal}: {where observed}

**Good pattern signals**:
- {signal}: {where observed}

**Net evolution judgment**: improvement / neutral / degradation
**Reason**: {one sentence}

## E. Autofix / Spread Fix

| Issue | Automation type | Scope | Risk | Expected benefit |
|-------|----------------|-------|------|-----------------|

## F. Convention Candidates

- **Review checklist**: {items or "无"}
- **Lint/check/rule**: {items or "无"}
- **Test guard**: {items or "无"}
- **Team convention**: {items or "无"}

## G. Action Decision

**Verdict**: approve / approve with targeted fixes / require significant cleanup / split refactor and re-review
**Reason**: {why}
**Required before merge**: {list or "无"}
**Recommended but not blocking**: {list or "无"}
```

Severity reference:
- **blocking**: must fix before merge — security vulnerability, data loss risk, wrong abstraction that will be expensive to undo, bad pattern that will be widely copied
- **important**: strongly recommend fixing — structural degradation, inconsistency spread, significant future maintenance cost increase
- **opportunistic**: worth doing if low cost — automation opportunity, convention candidate, minor improvement with good ROI

## Step 5: Write Handoff

Model: sonnet

Write `.sprint/{id}/handoffs/review.md` using the A-G structure from Step 4.

## Step 6: User Decision

Model: sonnet

Present the G section verdict with supporting evidence. Ask: "是否同意这个行动建议？"

- Approve → complete
- Approve with targeted fixes → list specific fixes → return to execute to fix → re-enter review at Step 2
- Require cleanup → list what needs cleanup → return to execute to fix → re-enter review at Step 1
- Split refactor → identify what to split, flag for separate sprint
- User overrides verdict → update handoff with user's decision and reasoning

---

## Completion

- All 5 layers analyzed (or skipped with reason)
- Every finding uses 12-field problem template
- Governance opportunities assessed
- Net evolution judgment stated
- Action verdict given and user confirmed
- Handoff written

## Recovery

- Blocking finding → return to execute to fix → re-enter review at Step 2
- User disagrees with verdict → update handoff with user's decision, document reasoning
- Missing context for confident analysis → flag specific conclusions as low-confidence, state what additional context would be needed
- New files added during fix → return to execute to fix → re-enter review at Step 2
