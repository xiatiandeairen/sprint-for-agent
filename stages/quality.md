# quality

Integration verification after execute completes.

## Input

- execute handoff: files changed, test scope
- anchors.txt
- state.json: base_commit

---

## Step 1: Detect Build & Test

Scan project root to determine build and test toolchain. Check for:

| Signal | Build command | Test command |
|--------|-------------|-------------|
| Package.swift | `swift build` | `swift test` |
| package.json | `npm run build` / `bun run build` | `npm test` / `bun test` |
| Cargo.toml | `cargo build` | `cargo test` |
| Makefile | `make` | `make test` |
| pyproject.toml / setup.py | `pip install -e .` | `pytest` |
| go.mod | `go build ./...` | `go test ./...` |
| Gemfile | `bundle exec rake build` | `bundle exec rake test` |

If multiple detected (e.g. monorepo), run all relevant ones.

If CLAUDE.md has build/test commands defined, use those as primary source.

Run detected build command, then test command. Both must pass before Step 2.

Fail → return to execute to fix.

## Step 2: Custom Scripts

Run project-specific quality scripts:

```bash
# [RUN] dependency health check (if exists)
[ -f scripts/dep-check.sh ] && bash scripts/dep-check.sh || echo "no dep-check script"
```

```bash
# [RUN] anchor check (if anchors exist)
[ -s ".sprint/{id}/anchors.txt" ] && bash "$ANCHOR_CHECK" "{sprint_id}" || echo "no anchors"
```

Placeholder for future scripts:
```bash
# bash scripts/integration-test.sh
# bash scripts/e2e-test.sh
```

All pass → Step 3. Any fail → return to execute to fix.

## Step 3: Impact Verification

Based on files changed in execute handoff, generate a global impact checklist for user manual verification.

Analyze changed files → identify affected features/modules/flows → generate checklist:

```
═══════════════════════════════════════
  🔬 Impact Verification
═══════════════════════════════════════

  Automated checks: PASS ✓
  - Build: ✓
  - Tests: {N} pass / 0 fail
  - Anchor: {N} pass / 0 fail (or skipped)
  - Custom: {results}

  Files changed:
  - {path}
  - {path}

  Please verify the following affected areas:

  - [ ] {area 1}: {what to check, how to check}
  - [ ] {area 2}: {what to check, how to check}
  - [ ] {area 3}: {what to check, how to check}

═══════════════════════════════════════
```

Wait for user to confirm all checks pass. Confirmed → next stage.

---

## Completion

- Build passes (auto-detected toolchain)
- Tests pass
- Custom scripts pass (or skipped if not present)
- User confirmed impact verification checklist

## Recovery

- Build/test fail → execute fixes
- User finds issue in impact check → execute fixes, re-run quality
