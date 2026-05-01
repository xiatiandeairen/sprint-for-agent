#!/usr/bin/env bats

load helpers.bash

setup()    { setup_sprint_env; }
teardown() { teardown_sprint_env; }

# ── MUST_EXIST ────────────────────────────────────────────────────────────

@test "MUST_EXIST: pass when file exists" {
  local id; id=$(make_sprint)
  echo "hello" > foo.txt
  echo "MUST_EXIST foo.txt" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_ok
  assert_contains "PASS: MUST_EXIST foo.txt"
  assert_contains "1 pass / 0 fail"
}

@test "MUST_EXIST: fail when file missing" {
  local id; id=$(make_sprint)
  echo "MUST_EXIST missing.txt" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_fail
  assert_contains "FAIL: MUST_EXIST missing.txt"
}

@test "MUST_EXIST: passes for directories" {
  local id; id=$(make_sprint)
  mkdir -p src/lib
  echo "MUST_EXIST src/lib" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_ok
}

# ── MUST_NOT_EXIST ────────────────────────────────────────────────────────

@test "MUST_NOT_EXIST: pass when file absent" {
  local id; id=$(make_sprint)
  echo "MUST_NOT_EXIST gone.txt" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_ok
}

@test "MUST_NOT_EXIST: fail when file present" {
  local id; id=$(make_sprint)
  echo "stillhere" > existing.txt
  echo "MUST_NOT_EXIST existing.txt" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_fail
  assert_contains "FAIL: MUST_NOT_EXIST existing.txt"
}

@test "MUST_NOT_EXIST: fail when directory present" {
  local id; id=$(make_sprint)
  mkdir -p node_modules
  echo "MUST_NOT_EXIST node_modules" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_fail
}

# ── MUST_CONTAIN ──────────────────────────────────────────────────────────

@test "MUST_CONTAIN: pass when pattern found" {
  local id; id=$(make_sprint)
  echo "function handleRequest()" > api.js
  echo "MUST_CONTAIN api.js handleRequest" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_ok
}

@test "MUST_CONTAIN: fail when pattern absent" {
  local id; id=$(make_sprint)
  echo "something else" > api.js
  echo "MUST_CONTAIN api.js handleRequest" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_fail
}

@test "MUST_CONTAIN: fail when target file missing" {
  local id; id=$(make_sprint)
  echo "MUST_CONTAIN gone.js anything" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_fail
  assert_contains "file not found"
}

@test "MUST_CONTAIN: fixed-string match (no regex interpretation)" {
  local id; id=$(make_sprint)
  echo 'config.get("key")' > cfg.txt
  echo 'MUST_CONTAIN cfg.txt config.get("key")' | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_ok
}

# ── MUST_NOT_CONTAIN ──────────────────────────────────────────────────────

@test "MUST_NOT_CONTAIN: pass when pattern absent" {
  local id; id=$(make_sprint)
  echo "clean code" > src.js
  echo "MUST_NOT_CONTAIN src.js console.log" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_ok
}

@test "MUST_NOT_CONTAIN: fail when pattern present" {
  local id; id=$(make_sprint)
  echo "console.log(debug)" > src.js
  echo "MUST_NOT_CONTAIN src.js console.log" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_fail
}

@test "MUST_NOT_CONTAIN: pass when target file missing (vacuously true)" {
  local id; id=$(make_sprint)
  echo "MUST_NOT_CONTAIN missing.js anything" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_ok
}

# ── MUST_BUILD ────────────────────────────────────────────────────────────

@test "MUST_BUILD: pass when build succeeds via .sprint.json" {
  local id; id=$(make_sprint)
  echo '{"build":"true"}' > .sprint.json
  echo "MUST_BUILD" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_ok
}

@test "MUST_BUILD: fail when build command exits non-zero" {
  local id; id=$(make_sprint)
  echo '{"build":"false"}' > .sprint.json
  echo "MUST_BUILD" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_fail
}

@test "MUST_BUILD: skip when no build command detectable" {
  local id; id=$(make_sprint)
  # Empty repo, no marker files, no CLAUDE.md → no build cmd
  echo "MUST_BUILD" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_contains "SKIP"
}

# ── MUST_TEST ─────────────────────────────────────────────────────────────

@test "MUST_TEST: pass when test passes" {
  local id; id=$(make_sprint)
  echo '{"test":"true"}' > .sprint.json
  echo "MUST_TEST" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_ok
}

@test "MUST_TEST: fail when test fails" {
  local id; id=$(make_sprint)
  echo '{"test":"false"}' > .sprint.json
  echo "MUST_TEST" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_fail
}

@test "MUST_TEST: skip when no test command detectable" {
  local id; id=$(make_sprint)
  echo "MUST_TEST" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_contains "SKIP"
}

# ── MUST_IMPORT ───────────────────────────────────────────────────────────

@test "MUST_IMPORT: pass when python import present" {
  local id; id=$(make_sprint)
  touch pyproject.toml
  echo "import os" > app.py
  echo "MUST_IMPORT app.py os" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_ok
}

@test "MUST_IMPORT: fail when python import missing" {
  local id; id=$(make_sprint)
  touch pyproject.toml
  echo "print('hi')" > app.py
  echo "MUST_IMPORT app.py requests" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_fail
}

@test "MUST_IMPORT: scans directory recursively" {
  local id; id=$(make_sprint)
  touch pyproject.toml
  mkdir -p src
  echo "from pathlib import Path" > src/core.py
  echo "MUST_IMPORT src pathlib" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_ok
}

# ── MUST_NOT_IMPORT ───────────────────────────────────────────────────────

@test "MUST_NOT_IMPORT: pass when import absent" {
  local id; id=$(make_sprint)
  touch pyproject.toml
  echo "print('x')" > a.py
  echo "MUST_NOT_IMPORT a.py os" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_ok
}

@test "MUST_NOT_IMPORT: fail when import present" {
  local id; id=$(make_sprint)
  touch pyproject.toml
  echo "import os" > a.py
  echo "MUST_NOT_IMPORT a.py os" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_fail
}

@test "MUST_NOT_IMPORT: pass when target does not exist (vacuous)" {
  local id; id=$(make_sprint)
  touch pyproject.toml
  echo "MUST_NOT_IMPORT missing.py os" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_ok
}

# ── FILE_NOT_MODIFIED ─────────────────────────────────────────────────────

@test "FILE_NOT_MODIFIED: pass when file unchanged since base_commit" {
  local id; id=$(make_sprint)
  echo "original" > locked.txt
  git add locked.txt && git commit -q -m "add locked"
  local base; base=$(git rev-parse --short HEAD)
  set_base_commit "$id" "$base"
  echo "FILE_NOT_MODIFIED locked.txt" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_ok
}

@test "FILE_NOT_MODIFIED: fail when file modified since base_commit" {
  local id; id=$(make_sprint)
  echo "v1" > locked.txt
  git add locked.txt && git commit -q -m "add locked"
  local base; base=$(git rev-parse --short HEAD)
  set_base_commit "$id" "$base"
  echo "v2" > locked.txt
  git add locked.txt && git commit -q -m "modify"
  echo "FILE_NOT_MODIFIED locked.txt" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_fail
}

@test "FILE_NOT_MODIFIED: skip when no base_commit" {
  local id; id=$(make_sprint)
  set_base_commit "$id" ""
  echo "FILE_NOT_MODIFIED locked.txt" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_contains "SKIP"
}

# ── General behavior ──────────────────────────────────────────────────────

@test "anchor-check: empty anchors.txt exits 0" {
  local id; id=$(make_sprint)
  : | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_ok
}

@test "anchor-check: comment and blank lines ignored" {
  local id; id=$(make_sprint)
  touch foo.txt
  cat <<EOF | write_anchors "$id"
# comment
MUST_EXIST foo.txt

# another
EOF
  run bash "$ANCHOR_CHECK" "$id"
  assert_exit_ok
  assert_contains "1 pass / 0 fail"
}

@test "anchor-check: writes anchor_check event to metrics.log" {
  local id; id=$(make_sprint)
  touch foo.txt
  echo "MUST_EXIST foo.txt" | write_anchors "$id"
  bash "$ANCHOR_CHECK" "$id" >/dev/null
  grep -qE "^anchor_check\|[0-9]+\|pass=1\|fail=0\|skip=0" "$(sprint_dir_for "$id")/metrics.log"
}

@test "anchor-check: missing sprint id → error" {
  run bash "$ANCHOR_CHECK"
  assert_exit_fail
  assert_contains "Usage"
}

@test "anchor-check: unknown rule produces UNKNOWN message" {
  local id; id=$(make_sprint)
  echo "MUST_WAT anything" | write_anchors "$id"
  run bash "$ANCHOR_CHECK" "$id"
  assert_contains "UNKNOWN"
}
