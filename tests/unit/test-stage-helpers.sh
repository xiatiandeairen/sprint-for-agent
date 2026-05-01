#!/usr/bin/env bash
# tests/unit/test-stage-helpers.sh — 共享 helper for stage 结构单元测试
#
# Usage from a stage test:
#   SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
#   REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
#   TARGET="$REPO_ROOT/stages/{stage}.md"
#   source "$SCRIPT_DIR/test-stage-helpers.sh"
#   # define test_* functions
#   run_tests "$@"
#
# 退出码：0=全 pass / 1=有 fail / 2=配置错误（TARGET 未设或不存在）

# ────────────────────────── precondition ──────────────────────────

[ -n "${TARGET:-}" ] || { echo "test-stage-helpers: TARGET must be set before sourcing" >&2; exit 2; }
[ -f "$TARGET" ]    || { echo "test-stage-helpers: TARGET not found: $TARGET" >&2; exit 2; }

# ────────────────────────── assertions ──────────────────────────

assert_contains() {
  local label="$1" needle="$2"
  if grep -qF -- "$needle" "$TARGET"; then
    return 0
  fi
  echo "  [$label] missing: '$needle'"
  return 1
}

assert_count() {
  local label="$1" pattern="$2" expected="$3"
  local actual
  actual=$(grep -cE -- "$pattern" "$TARGET" 2>/dev/null || true)
  if [ "$actual" -eq "$expected" ]; then
    return 0
  fi
  echo "  [$label] pattern: '$pattern'  expected: $expected  actual: $actual"
  return 1
}

assert_not_contains() {
  local label="$1" needle="$2"
  if ! grep -qF -- "$needle" "$TARGET"; then
    return 0
  fi
  echo "  [$label] should not contain: '$needle'"
  return 1
}

# ────────────────────────── runner ──────────────────────────

run_tests() {
  local cases=()
  if [ $# -ge 1 ]; then
    if declare -F "$1" >/dev/null; then
      cases=("$1")
    else
      echo "Error: no such case '$1'" >&2
      declare -F | awk '$3 ~ /^test_/ {print "  "$3}' >&2
      exit 1
    fi
  else
    while IFS= read -r line; do cases+=("$line"); done \
      < <(declare -F | awk '$3 ~ /^test_/ {print $3}')
  fi

  local pass=0 fail=0
  for c in "${cases[@]}"; do
    if ( "$c" ); then
      echo "[pass] $c"
      pass=$((pass + 1))
    else
      echo "[fail] $c"
      fail=$((fail + 1))
    fi
  done

  echo "──"
  echo "$pass pass / $fail fail (of $((pass + fail)))"
  [ "$fail" -eq 0 ]
}
