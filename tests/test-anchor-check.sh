#!/usr/bin/env bash
# test-anchor-check.sh — Regression tests for anchor-check.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ANCHOR_CHECK="$(cd "$SCRIPT_DIR/.." && pwd)/scripts/anchor-check.sh"

source "$SCRIPT_DIR/test-helpers.sh"
setup_fixture

SPRINT_CTL="$(cd "$SCRIPT_DIR/.." && pwd)/scripts/sprint-ctl.sh"

# Helper: create a sprint with given anchors
make_sprint() {
  local id="$1"
  local anchors="$2"
  mkdir -p "$SPRINT_DIR/$id/handoffs"
  local base
  base="$(cd "$ROOT" && git rev-parse --short HEAD)"
  cat > "$SPRINT_DIR/$id/state.json" <<EOF
{
  "id": "$id",
  "type": "sprint",
  "desc": "test",
  "stages": ["plan","execute"],
  "status": "running",
  "current_stage": "execute",
  "base_commit": "$base",
  "created_at": "2026-01-01T00:00:00Z"
}
EOF
  echo "sprint_start|$id|$(date +%s)" > "$SPRINT_DIR/$id/metrics.log"
  echo "$anchors" > "$SPRINT_DIR/$id/anchors.txt"
}

# ── MUST_EXIST ──

run_test "MUST_EXIST — file exists → PASS" '
  make_sprint "test-001" "MUST_EXIST testfile.txt"
  touch "$ROOT/testfile.txt"
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-001" 2>&1)
  assert_contains "PASS" "$OUTPUT"
'

run_test "MUST_EXIST — file missing → FAIL" '
  make_sprint "test-002" "MUST_EXIST nonexistent.txt"
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-002" 2>&1) || true
  assert_contains "FAIL" "$OUTPUT"
'

# ── MUST_NOT_EXIST ──

run_test "MUST_NOT_EXIST — file missing → PASS" '
  make_sprint "test-003" "MUST_NOT_EXIST ghost.txt"
  rm -f "$ROOT/ghost.txt"
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-003" 2>&1)
  assert_contains "PASS" "$OUTPUT"
'

run_test "MUST_NOT_EXIST — file exists → FAIL" '
  make_sprint "test-004" "MUST_NOT_EXIST existing.txt"
  touch "$ROOT/existing.txt"
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-004" 2>&1) || true
  assert_contains "FAIL" "$OUTPUT"
'

# ── MUST_BUILD ──

run_test "MUST_BUILD — package.json + build succeeds → PASS" '
  make_sprint "test-005" "MUST_BUILD"
  cat > "$ROOT/package.json" <<PEOF
{"scripts":{"build":"echo build-ok"}}
PEOF
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-005" 2>&1)
  assert_contains "PASS" "$OUTPUT"
  rm -f "$ROOT/package.json"
'

run_test "MUST_BUILD — build fails → FAIL" '
  make_sprint "test-006" "MUST_BUILD"
  cat > "$ROOT/package.json" <<PEOF
{"scripts":{"build":"exit 1"}}
PEOF
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-006" 2>&1) || true
  assert_contains "FAIL" "$OUTPUT"
  rm -f "$ROOT/package.json"
'

run_test "MUST_BUILD — no project type → SKIP" '
  make_sprint "test-007" "MUST_BUILD"
  rm -f "$ROOT/package.json" "$ROOT/Package.swift" "$ROOT/Cargo.toml" "$ROOT/Makefile" "$ROOT/pyproject.toml" "$ROOT/go.mod" "$ROOT/Gemfile"
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-007" 2>&1)
  assert_contains "SKIP" "$OUTPUT"
'

# ── MUST_TEST ──

run_test "MUST_TEST — package.json + test succeeds → PASS" '
  make_sprint "test-008" "MUST_TEST"
  cat > "$ROOT/package.json" <<PEOF
{"scripts":{"test":"echo test-ok"}}
PEOF
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-008" 2>&1)
  assert_contains "PASS" "$OUTPUT"
  rm -f "$ROOT/package.json"
'

run_test "MUST_TEST — no project type → SKIP" '
  make_sprint "test-009" "MUST_TEST"
  rm -f "$ROOT/package.json" "$ROOT/Package.swift" "$ROOT/Cargo.toml" "$ROOT/Makefile" "$ROOT/pyproject.toml" "$ROOT/go.mod" "$ROOT/Gemfile"
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-009" 2>&1)
  assert_contains "SKIP" "$OUTPUT"
'

# ── MUST_IMPORT ──

run_test "MUST_IMPORT — file contains import → PASS" '
  make_sprint "test-010" "MUST_IMPORT src/app.js express"
  mkdir -p "$ROOT/src"
  echo "import express from '\''express'\''" > "$ROOT/src/app.js"
  cat > "$ROOT/package.json" <<PEOF
{"scripts":{}}
PEOF
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-010" 2>&1)
  assert_contains "PASS" "$OUTPUT"
  rm -f "$ROOT/package.json"
'

run_test "MUST_IMPORT — file missing import → FAIL" '
  make_sprint "test-011" "MUST_IMPORT src/app.js lodash"
  mkdir -p "$ROOT/src"
  echo "import express from '\''express'\''" > "$ROOT/src/app.js"
  cat > "$ROOT/package.json" <<PEOF
{"scripts":{}}
PEOF
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-011" 2>&1) || true
  assert_contains "FAIL" "$OUTPUT"
  rm -f "$ROOT/package.json"
'

run_test "MUST_IMPORT — directory search → PASS" '
  make_sprint "test-012" "MUST_IMPORT src express"
  mkdir -p "$ROOT/src"
  echo "const x = require('\''express'\'')" > "$ROOT/src/index.js"
  cat > "$ROOT/package.json" <<PEOF
{"scripts":{}}
PEOF
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-012" 2>&1)
  assert_contains "PASS" "$OUTPUT"
  rm -f "$ROOT/package.json"
'

run_test "MUST_IMPORT — target not found → FAIL" '
  make_sprint "test-013" "MUST_IMPORT nonexistent/path express"
  cat > "$ROOT/package.json" <<PEOF
{"scripts":{}}
PEOF
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-013" 2>&1) || true
  assert_contains "FAIL" "$OUTPUT"
  rm -f "$ROOT/package.json"
'

# ── MUST_NOT_IMPORT ──

run_test "MUST_NOT_IMPORT — file missing import → PASS" '
  make_sprint "test-014" "MUST_NOT_IMPORT src/app.js lodash"
  mkdir -p "$ROOT/src"
  echo "import express from '\''express'\''" > "$ROOT/src/app.js"
  cat > "$ROOT/package.json" <<PEOF
{"scripts":{}}
PEOF
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-014" 2>&1)
  assert_contains "PASS" "$OUTPUT"
  rm -f "$ROOT/package.json"
'

run_test "MUST_NOT_IMPORT — file contains import → FAIL" '
  make_sprint "test-015" "MUST_NOT_IMPORT src/app.js express"
  mkdir -p "$ROOT/src"
  echo "import express from '\''express'\''" > "$ROOT/src/app.js"
  cat > "$ROOT/package.json" <<PEOF
{"scripts":{}}
PEOF
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-015" 2>&1) || true
  assert_contains "FAIL" "$OUTPUT"
  rm -f "$ROOT/package.json"
'

run_test "MUST_NOT_IMPORT — target not found → PASS" '
  make_sprint "test-016" "MUST_NOT_IMPORT nonexistent/path express"
  cat > "$ROOT/package.json" <<PEOF
{"scripts":{}}
PEOF
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-016" 2>&1)
  assert_contains "PASS" "$OUTPUT"
  rm -f "$ROOT/package.json"
'

# ── FILE_NOT_MODIFIED ──

run_test "FILE_NOT_MODIFIED — file unchanged → PASS" '
  echo "original" > "$ROOT/keep.txt"
  cd "$ROOT" && git add keep.txt && git commit -q -m "add keep"
  make_sprint "test-017" "FILE_NOT_MODIFIED keep.txt"
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-017" 2>&1)
  assert_contains "PASS" "$OUTPUT"
'

run_test "FILE_NOT_MODIFIED — file changed → FAIL" '
  echo "changed" >> "$ROOT/keep.txt"
  make_sprint "test-018" "FILE_NOT_MODIFIED keep.txt"
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-018" 2>&1) || true
  assert_contains "FAIL" "$OUTPUT"
  cd "$ROOT" && git checkout -q -- keep.txt
'

# ── Edge cases ──

run_test "Empty anchors.txt → exit 0, 0 pass" '
  make_sprint "test-019" ""
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-019" 2>&1)
  assert_contains "0 pass / 0 fail" "$OUTPUT"
'

run_test "Comment lines skipped" '
  make_sprint "test-020" "# this is a comment
MUST_EXIST testfile.txt"
  touch "$ROOT/testfile.txt"
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-020" 2>&1)
  assert_contains "1 pass / 0 fail" "$OUTPUT"
'

run_test "CLAUDE.md build_cmd takes priority" '
  make_sprint "test-021" "MUST_BUILD"
  cat > "$ROOT/package.json" <<PEOF
{"scripts":{"build":"exit 1"}}
PEOF
  cat > "$ROOT/CLAUDE.md" <<PEOF
build_cmd: echo custom-build-ok
PEOF
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-021" 2>&1)
  assert_contains "PASS" "$OUTPUT"
  rm -f "$ROOT/package.json" "$ROOT/CLAUDE.md"
'

# ── .sprint.json config ──

run_test ".sprint.json build field → MUST_BUILD uses config" '
  make_sprint "test-030" "MUST_BUILD"
  rm -f "$ROOT/package.json" "$ROOT/CLAUDE.md"
  cat > "$ROOT/.sprint.json" <<PEOF
{"build": "echo sprint-json-build-ok"}
PEOF
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-030" 2>&1)
  assert_contains "PASS" "$OUTPUT"
  rm -f "$ROOT/.sprint.json"
'

run_test ".sprint.json test field → MUST_TEST uses config" '
  make_sprint "test-031" "MUST_TEST"
  rm -f "$ROOT/package.json" "$ROOT/CLAUDE.md"
  cat > "$ROOT/.sprint.json" <<PEOF
{"test": "echo sprint-json-test-ok"}
PEOF
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-031" 2>&1)
  assert_contains "PASS" "$OUTPUT"
  rm -f "$ROOT/.sprint.json"
'

run_test ".sprint.json takes priority over CLAUDE.md" '
  make_sprint "test-032" "MUST_BUILD"
  cat > "$ROOT/CLAUDE.md" <<PEOF
build_cmd: exit 1
PEOF
  cat > "$ROOT/.sprint.json" <<PEOF
{"build": "echo sprint-json-wins"}
PEOF
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-032" 2>&1)
  assert_contains "PASS" "$OUTPUT"
  rm -f "$ROOT/.sprint.json" "$ROOT/CLAUDE.md"
'

run_test ".sprint.json missing field → fallback to CLAUDE.md" '
  make_sprint "test-033" "MUST_BUILD"
  cat > "$ROOT/.sprint.json" <<PEOF
{"test": "echo only-test"}
PEOF
  cat > "$ROOT/CLAUDE.md" <<PEOF
build_cmd: echo claude-md-fallback
PEOF
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-033" 2>&1)
  assert_contains "PASS" "$OUTPUT"
  rm -f "$ROOT/.sprint.json" "$ROOT/CLAUDE.md"
'

run_test ".sprint.json missing field → fallback to auto-detect" '
  make_sprint "test-034" "MUST_BUILD"
  cat > "$ROOT/.sprint.json" <<PEOF
{"lint": "echo only-lint"}
PEOF
  rm -f "$ROOT/CLAUDE.md"
  cat > "$ROOT/package.json" <<PEOF
{"scripts":{"build":"echo auto-detect-build"}}
PEOF
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-034" 2>&1)
  assert_contains "PASS" "$OUTPUT"
  rm -f "$ROOT/.sprint.json" "$ROOT/package.json"
'

run_test "No .sprint.json → behavior unchanged (backward compat)" '
  make_sprint "test-035" "MUST_BUILD"
  rm -f "$ROOT/.sprint.json" "$ROOT/CLAUDE.md"
  cat > "$ROOT/package.json" <<PEOF
{"scripts":{"build":"echo compat-ok"}}
PEOF
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-035" 2>&1)
  assert_contains "PASS" "$OUTPUT"
  rm -f "$ROOT/package.json"
'

run_test ".sprint.json invalid JSON → error exit 1" '
  make_sprint "test-036" "MUST_BUILD"
  echo "not valid json{{{" > "$ROOT/.sprint.json"
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-036" 2>&1) || true
  RC=0; cd "$ROOT" && bash "$ANCHOR_CHECK" "test-036" >/dev/null 2>&1 || RC=$?
  [[ $RC -ne 0 ]]
  rm -f "$ROOT/.sprint.json"
'

# ── MUST_CONTAIN ──

run_test "MUST_CONTAIN — file contains pattern → PASS" '
  make_sprint "test-040" "MUST_CONTAIN testfile.txt hello world"
  echo "hello world" > "$ROOT/testfile.txt"
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-040" 2>&1)
  assert_contains "PASS" "$OUTPUT"
'

run_test "MUST_CONTAIN — file missing pattern → FAIL" '
  make_sprint "test-041" "MUST_CONTAIN testfile.txt hello world"
  echo "goodbye" > "$ROOT/testfile.txt"
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-041" 2>&1) || true
  assert_contains "FAIL" "$OUTPUT"
'

run_test "MUST_CONTAIN — file not found → FAIL" '
  make_sprint "test-042" "MUST_CONTAIN nonexistent.txt some pattern"
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-042" 2>&1) || true
  assert_contains "FAIL" "$OUTPUT"
'

# ── MUST_NOT_CONTAIN ──

run_test "MUST_NOT_CONTAIN — file missing pattern → PASS" '
  make_sprint "test-043" "MUST_NOT_CONTAIN testfile.txt deprecated_api"
  echo "good_api()" > "$ROOT/testfile.txt"
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-043" 2>&1)
  assert_contains "PASS" "$OUTPUT"
'

run_test "MUST_NOT_CONTAIN — file contains pattern → FAIL" '
  make_sprint "test-044" "MUST_NOT_CONTAIN testfile.txt deprecated_api"
  echo "deprecated_api()" > "$ROOT/testfile.txt"
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-044" 2>&1) || true
  assert_contains "FAIL" "$OUTPUT"
'

run_test "MUST_NOT_CONTAIN — file not found → PASS" '
  make_sprint "test-045" "MUST_NOT_CONTAIN nonexistent.txt bad_pattern"
  OUTPUT=$(cd "$ROOT" && bash "$ANCHOR_CHECK" "test-045" 2>&1)
  assert_contains "PASS" "$OUTPUT"
'

report
