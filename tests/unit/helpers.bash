#!/usr/bin/env bash
# Shared helpers for sprint unit tests.
# Each test gets an isolated SPRINT_HOME + git-initialized working tree.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SPRINT_CTL="$PROJECT_ROOT/scripts/sprint-ctl.sh"
ANCHOR_CHECK="$PROJECT_ROOT/scripts/anchor-check.sh"

setup_sprint_env() {
  TEST_TMP="$(mktemp -d)"
  export XDG_DATA_HOME="$TEST_TMP/xdg"
  export SPRINT_HOME_TEST="$XDG_DATA_HOME/sprint"
  mkdir -p "$TEST_TMP/repo"
  # macOS returns /var/folders/... from mktemp but git resolves to /private/var/...
  # Use the canonical path that matches `git rev-parse --show-toplevel`.
  export TEST_REPO="$(cd "$TEST_TMP/repo" && pwd -P)"
  cd "$TEST_REPO"
  git init -q
  git config user.email "test@test"
  git config user.name "test"
  # Isolate from user-global hooks (commit-msg linters etc.)
  git config core.hooksPath /dev/null
  git commit --allow-empty -q -m "init"
}

teardown_sprint_env() {
  cd /tmp
  rm -rf "$TEST_TMP"
}

project_id() {
  echo "$TEST_REPO" | sed 's|/|-|g'
}

sprint_dir_for() {
  local id="$1"
  echo "$SPRINT_HOME_TEST/projects/$(project_id)/$id"
}

latest_sprint_id() {
  local pdir="$SPRINT_HOME_TEST/projects/$(project_id)"
  ls -1 "$pdir" 2>/dev/null | grep -E '^[0-9]{8}-[0-9]{6}-[0-9]{3}$' | sort | tail -1
}

json_field() {
  local file="$1" field="$2"
  python3 -c "import json; print(json.load(open('$file')).get('$field',''))"
}

json_list_field() {
  local file="$1" field="$2"
  python3 -c "import json; print(','.join(json.load(open('$file')).get('$field',[])))"
}

assert_exit_ok() {
  [ "$status" -eq 0 ] || { echo "expected exit 0, got $status. output: $output" >&2; return 1; }
}

assert_exit_fail() {
  [ "$status" -ne 0 ] || { echo "expected non-zero exit, got 0. output: $output" >&2; return 1; }
}

assert_contains() {
  echo "$output" | grep -qF "$1" || { echo "output missing: $1. got: $output" >&2; return 1; }
}

# Create a sprint via sprint-ctl create and return its id via stdout.
make_sprint() {
  bash "$SPRINT_CTL" create sprint "test" "plan,execute,insight" >/dev/null
  latest_sprint_id
}

# Write lines to the sprint's anchors.txt (multi-line via stdin).
write_anchors() {
  local id="$1"
  cat > "$(sprint_dir_for "$id")/anchors.txt"
}

# Set state.json.base_commit (used by FILE_NOT_MODIFIED).
set_base_commit() {
  local id="$1" commit="$2"
  local state; state="$(sprint_dir_for "$id")/state.json"
  python3 -c "
import json
s=json.load(open('$state'))
s['base_commit']='$commit'
json.dump(s, open('$state','w'), indent=2)
"
}
