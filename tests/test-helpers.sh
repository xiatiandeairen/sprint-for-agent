#!/usr/bin/env bash
# test-helpers.sh — Shared test utilities for sprint scripts
# Source this file from test-*.sh scripts

TESTS_PASS=0
TESTS_FAIL=0
FIXTURE_DIR=""

setup_fixture() {
  FIXTURE_DIR="$(mktemp -d)"
  cd "$FIXTURE_DIR"
  git init -q
  git config core.hooksPath /dev/null
  git commit -q --allow-empty -m "initial"
  mkdir -p .sprint
  export ROOT="$FIXTURE_DIR"
  export SPRINT_DIR="$FIXTURE_DIR/.sprint"
  trap teardown_fixture EXIT
}

teardown_fixture() {
  if [[ -n "$FIXTURE_DIR" && -d "$FIXTURE_DIR" ]]; then
    rm -rf "$FIXTURE_DIR"
  fi
}

run_test() {
  local name="$1"
  local body="$2"
  if ( eval "$body" ) 2>/dev/null; then
    echo "PASS: $name"
    TESTS_PASS=$(( TESTS_PASS + 1 ))
  else
    echo "FAIL: $name"
    TESTS_FAIL=$(( TESTS_FAIL + 1 ))
  fi
}

assert_exit_code() {
  local expected="$1"
  shift
  local actual
  "$@" >/dev/null 2>&1 && actual=0 || actual=$?
  [[ "$actual" -eq "$expected" ]] || { echo "  expected exit $expected, got $actual" >&2; return 1; }
}

assert_contains() {
  local needle="$1"
  local haystack="$2"
  echo "$haystack" | grep -qF "$needle" || { echo "  expected to contain: $needle" >&2; return 1; }
}

assert_not_contains() {
  local needle="$1"
  local haystack="$2"
  if echo "$haystack" | grep -qF "$needle" 2>/dev/null; then
    echo "  expected NOT to contain: $needle" >&2
    return 1
  fi
}

assert_file_exists() {
  local path="$1"
  [[ -e "$path" ]] || { echo "  file not found: $path" >&2; return 1; }
}

assert_file_not_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    echo "  file should not exist: $path" >&2
    return 1
  fi
}

report() {
  echo ""
  echo "Tests: $TESTS_PASS pass / $TESTS_FAIL fail"
  [[ $TESTS_FAIL -eq 0 ]]
}
