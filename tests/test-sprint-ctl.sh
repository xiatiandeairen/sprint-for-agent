#!/usr/bin/env bash
# test-sprint-ctl.sh — Regression tests for sprint-ctl.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SPRINT_CTL="$(cd "$SCRIPT_DIR/.." && pwd)/scripts/sprint-ctl.sh"

source "$SCRIPT_DIR/test-helpers.sh"
setup_fixture

# ── create ──

run_test "create — generates directory structure" '
  OUTPUT=$(cd "$ROOT" && bash "$SPRINT_CTL" create "sprint" "test desc" "plan,execute" 2>&1)
  ID=$(echo "$OUTPUT" | grep "Sprint created:" | awk "{print \$3}")
  assert_file_exists "$SPRINT_DIR/$ID/state.json"
  assert_file_exists "$SPRINT_DIR/$ID/handoffs"
  assert_file_exists "$SPRINT_DIR/$ID/anchors.txt"
  assert_file_exists "$SPRINT_DIR/$ID/metrics.log"
'

run_test "create — state.json fields complete" '
  OUTPUT=$(cd "$ROOT" && bash "$SPRINT_CTL" create "sprint" "field test" "plan,execute,quality" 2>&1)
  ID=$(echo "$OUTPUT" | grep "Sprint created:" | awk "{print \$3}")
  STATE=$(cat "$SPRINT_DIR/$ID/state.json")
  assert_contains "\"id\":" "$STATE"
  assert_contains "\"type\": \"sprint\"" "$STATE"
  assert_contains "\"desc\": \"field test\"" "$STATE"
  assert_contains "\"status\": \"created\"" "$STATE"
  assert_contains "\"base_commit\":" "$STATE"
  assert_contains "\"created_at\":" "$STATE"
'

run_test "create — stages JSON array correct" '
  OUTPUT=$(cd "$ROOT" && bash "$SPRINT_CTL" create "sprint" "stages test" "brainstorm,design,plan" 2>&1)
  ID=$(echo "$OUTPUT" | grep "Sprint created:" | awk "{print \$3}")
  STATE=$(cat "$SPRINT_DIR/$ID/state.json")
  assert_contains "\"brainstorm\"" "$STATE"
  assert_contains "\"design\"" "$STATE"
  assert_contains "\"plan\"" "$STATE"
'

# ── activate ──

run_test "activate — status becomes running" '
  OUTPUT=$(cd "$ROOT" && bash "$SPRINT_CTL" create "sprint" "activate test" "plan" 2>&1)
  ID=$(echo "$OUTPUT" | grep "Sprint created:" | awk "{print \$3}")
  cd "$ROOT" && bash "$SPRINT_CTL" activate "$ID" >/dev/null 2>&1
  STATE=$(cat "$SPRINT_DIR/$ID/state.json")
  assert_contains "\"status\": \"running\"" "$STATE"
'

run_test "activate — base_commit recorded" '
  OUTPUT=$(cd "$ROOT" && bash "$SPRINT_CTL" create "sprint" "base test" "plan" 2>&1)
  ID=$(echo "$OUTPUT" | grep "Sprint created:" | awk "{print \$3}")
  cd "$ROOT" && bash "$SPRINT_CTL" activate "$ID" >/dev/null 2>&1
  STATE=$(cat "$SPRINT_DIR/$ID/state.json")
  assert_contains "\"base_commit\":" "$STATE"
  assert_not_contains "\"base_commit\": \"\"" "$STATE"
'

# ── stage ──

run_test "stage running — metrics recorded" '
  OUTPUT=$(cd "$ROOT" && bash "$SPRINT_CTL" create "sprint" "stage test" "plan,execute" 2>&1)
  ID=$(echo "$OUTPUT" | grep "Sprint created:" | awk "{print \$3}")
  cd "$ROOT" && bash "$SPRINT_CTL" activate "$ID" >/dev/null 2>&1
  cd "$ROOT" && bash "$SPRINT_CTL" stage "$ID" plan running >/dev/null 2>&1
  METRICS=$(cat "$SPRINT_DIR/$ID/metrics.log")
  assert_contains "stage_start|plan|" "$METRICS"
'

run_test "stage completed — duration in metrics" '
  OUTPUT=$(cd "$ROOT" && bash "$SPRINT_CTL" create "sprint" "dur test" "plan,execute" 2>&1)
  ID=$(echo "$OUTPUT" | grep "Sprint created:" | awk "{print \$3}")
  cd "$ROOT" && bash "$SPRINT_CTL" activate "$ID" >/dev/null 2>&1
  cd "$ROOT" && bash "$SPRINT_CTL" stage "$ID" plan running >/dev/null 2>&1
  sleep 1
  cd "$ROOT" && bash "$SPRINT_CTL" stage "$ID" plan completed >/dev/null 2>&1
  METRICS=$(cat "$SPRINT_DIR/$ID/metrics.log")
  assert_contains "stage_end|plan|completed|" "$METRICS"
'

run_test "stage invalid status — exit 1" '
  OUTPUT=$(cd "$ROOT" && bash "$SPRINT_CTL" create "sprint" "invalid test" "plan" 2>&1)
  ID=$(echo "$OUTPUT" | grep "Sprint created:" | awk "{print \$3}")
  cd "$ROOT" && bash "$SPRINT_CTL" activate "$ID" >/dev/null 2>&1
  assert_exit_code 1 bash "$SPRINT_CTL" stage "$ID" plan invalid_status
'

# ── evaluate ──

run_test "evaluate 0 0 0 — basic stages" '
  OUTPUT=$(cd "$ROOT" && bash "$SPRINT_CTL" evaluate 0 0 0 2>&1)
  assert_contains "plan,execute,quality" "$OUTPUT"
  assert_contains "insight" "$OUTPUT"
  assert_not_contains "brainstorm" "$(echo "$OUTPUT" | grep "^  [a-z]" | grep "INCLUDED")"
'

run_test "evaluate 1 1 1 — all stages" '
  OUTPUT=$(cd "$ROOT" && bash "$SPRINT_CTL" evaluate 1 1 1 2>&1)
  assert_contains "brainstorm" "$OUTPUT"
  assert_contains "design" "$OUTPUT"
  assert_contains "review" "$OUTPUT"
'

run_test "evaluate keyword override — delete forces risk=1" '
  OUTPUT=$(cd "$ROOT" && bash "$SPRINT_CTL" evaluate 0 0 0 delete 2>&1)
  assert_contains "review" "$OUTPUT"
'

# ── end ──

run_test "end — status becomes completed" '
  OUTPUT=$(cd "$ROOT" && bash "$SPRINT_CTL" create "sprint" "end test" "plan" 2>&1)
  ID=$(echo "$OUTPUT" | grep "Sprint created:" | awk "{print \$3}")
  cd "$ROOT" && bash "$SPRINT_CTL" activate "$ID" >/dev/null 2>&1
  cd "$ROOT" && bash "$SPRINT_CTL" stage "$ID" plan running >/dev/null 2>&1
  cd "$ROOT" && bash "$SPRINT_CTL" stage "$ID" plan completed >/dev/null 2>&1
  cd "$ROOT" && bash "$SPRINT_CTL" end "$ID" >/dev/null 2>&1
  STATE=$(cat "$SPRINT_DIR/$ID/state.json")
  assert_contains "\"status\": \"completed\"" "$STATE"
'

run_test "end — summary output contains stage duration" '
  OUTPUT=$(cd "$ROOT" && bash "$SPRINT_CTL" create "sprint" "summary test" "plan" 2>&1)
  ID=$(echo "$OUTPUT" | grep "Sprint created:" | awk "{print \$3}")
  cd "$ROOT" && bash "$SPRINT_CTL" activate "$ID" >/dev/null 2>&1
  cd "$ROOT" && bash "$SPRINT_CTL" stage "$ID" plan running >/dev/null 2>&1
  cd "$ROOT" && bash "$SPRINT_CTL" stage "$ID" plan completed >/dev/null 2>&1
  END_OUTPUT=$(cd "$ROOT" && bash "$SPRINT_CTL" end "$ID" 2>&1)
  assert_contains "plan" "$END_OUTPUT"
  assert_contains "总计" "$END_OUTPUT"
'

# ── list ──

run_test "list — shows existing sprints" '
  OUTPUT=$(cd "$ROOT" && bash "$SPRINT_CTL" create "sprint" "list test" "plan" 2>&1)
  LIST_OUTPUT=$(cd "$ROOT" && bash "$SPRINT_CTL" list 2>&1)
  assert_contains "list test" "$LIST_OUTPUT"
'

report
