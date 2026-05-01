# Sprint Tests

Two-tier test suite for the sprint skill:

1. **Unit tests** (`tests/unit/`)
   - **bash scripts** (bats-core): `sprint-ctl.sh` + `anchor-check.sh` CLI contracts
   - **markdown invariants** (pytest + markdown-it-py): `SKILL.md`, `stages/*.md`, `skills/sprint/{auto-principles,interaction-terms}.md` — structure + cross-file referential integrity
2. **Benchmark** (`tests/bench/`)
   - **schema validator** (compare.py): checks a sprint's artifact dir against protocol invariants
   - **historical replay** (runner.py replay): validates every completed sprint under `$SPRINT_HOME` and emits a drift summary
   - **LLM judge** (judge.py): emits prompts for a Claude Code subagent to score a sprint on 5 dimensions; stats module computes per-dimension mean/stdev over batch runs

No Anthropic SDK. All LLM evaluation is performed via the Claude Code Agent tool (subagent).

---

## Prereqs

```bash
brew install bats-core
pip3 install --system pytest markdown-it-py pyyaml deepdiff
```

Python 3.10+.

## Run unit tests

```bash
make test            # both frameworks
make test-bats       # scripts only
make test-pytest     # markdown invariants only
```

### Run mutation demos

These prove the invariant suite catches bad changes. Each mutation:
temporarily alters a real file, verifies the invariant test FAILs, then restores.

```bash
python3 -m pytest tests/unit/test_mutations.py -m mutation -v
```

3 mutations included:
- delete `### Hard Rules` from `SKILL.md` → `test_skill_invariants` fires
- flip `- total: 6` to `- total: 99` in `stages/plan.md` → `test_stage_invariants` fires
- remove `D3-design-decisions` row from `auto-principles.md` mapping → `test_crossref` fires

## Run benchmark — historical replay

```bash
make bench-replay
# or: cd tests/bench && python3 -m runner replay
```

This walks every completed sprint under `$SPRINT_HOME/projects/<project-id>/*/`,
applies the schema invariants, and writes `reports/replay-<ts>.json` containing:
- counts of PASS / FAIL sprints
- `violations_by_rule` — sorted by frequency (use as a protocol-drift report)
- per-sprint failed-rule lists

Current dataset (38 historical sprints, as of 2026-04-23):

| Count | Rule |
|------:|------|
| 32 | handoff files match the state.stages list |
| 16 | metrics.log event chain is complete and consistent |
| 12 | state.json.stages contains only known stage names |

(These are **real findings**, not false positives — e.g. sprint-ctl.sh's `end` command does not close the `insight` stage, which is a protocol gap.)

## Run benchmark — LLM judge (subagent)

The judge is a Claude Code subagent, not an API client. Use it via a two-step flow:

```bash
# 1. emit the batch prompt (covers the last N sprints)
make bench-judge-prompt LIMIT=10
# writes tests/bench/reports/judge-batch-prompt.txt + lists included sprint ids

# 2. in Claude Code, invoke the Agent tool (subagent_type=general-purpose) with:
#    "Read the prompt at <path>, follow it, save JSON to <scores_path>"

# 3. compute statistics
make bench-judge-stats UPDATE=1
# prints mean/stdev/min/max per dimension; saves baselines/replay-stats.json
```

### Which dimensions can be automated gates?

From the latest 10-sprint run (`baselines/replay-stats.json`):

| dim              | mean | stdev | gate? | rationale |
|------------------|------|-------|-------|-----------|
| term-hygiene     | 3.6  | 0.70  | ✓     | low variance → stable signal |
| scope-discipline | 4.2  | 0.92  | ✓     | low variance → stable signal |
| clarity          | 3.3  | 1.64  | —     | too variable across handoff styles |
| decisiveness     | 3.7  | 1.89  | —     | too variable |
| handoff-quality  | 3.1  | 2.23  | —     | bimodal (missing handoffs drag to 0) |

Only the first two should be used for CI-style FAIL gates. The rest are observability signals.

## Adding an invariant

**Markdown**: add a test function under `tests/unit/test_*.py`. Use `conftest.py`'s
`find_sections` / `section_body` helpers. Reuse the `skill_md` / `stage_files` / `auto_principles_md` fixtures.

**Sprint artifact schema**: append a `(name, callable)` tuple to `SCHEMA_INVARIANTS` in `tests/bench/schema.py`. The callable takes a sprint dir and returns a list of violation strings.

**New dimension for judge**: extend `DIMENSIONS` in `tests/bench/judge.py` and the rubric in the prompt template.

## Architecture note

`tests/` has **no dependency** on `scripts/` or `skills/` sources — it only reads them.
Forbidden:
- `scripts/* → tests/*` (production must not import tests)
- `tests/bench/* → tests/unit/*` and vice versa (two independent layers)

Files written by tests/bench live under `tests/bench/reports/` which is gitignored.
