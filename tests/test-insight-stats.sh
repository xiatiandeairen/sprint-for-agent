#!/usr/bin/env bash
# test-insight-stats.sh — Regression tests for sprint-insight-stats.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSIGHT_STATS="$(cd "$SCRIPT_DIR/.." && pwd)/scripts/sprint-insight-stats.sh"
SPRINT_CTL="$(cd "$SCRIPT_DIR/.." && pwd)/scripts/sprint-ctl.sh"

source "$SCRIPT_DIR/test-helpers.sh"
setup_fixture

# Helper: create and complete a sprint with metrics
make_completed_sprint() {
  local desc="$1"
  local output
  output=$(cd "$ROOT" && bash "$SPRINT_CTL" create "sprint" "$desc" "plan,execute" 2>&1)
  local id
  id=$(echo "$output" | grep "Sprint created:" | awk '{print $3}')
  cd "$ROOT" && bash "$SPRINT_CTL" activate "$id" >/dev/null 2>&1
  cd "$ROOT" && bash "$SPRINT_CTL" stage "$id" plan running >/dev/null 2>&1
  sleep 1
  cd "$ROOT" && bash "$SPRINT_CTL" stage "$id" plan completed >/dev/null 2>&1
  cd "$ROOT" && bash "$SPRINT_CTL" stage "$id" execute running >/dev/null 2>&1
  sleep 1
  cd "$ROOT" && bash "$SPRINT_CTL" stage "$id" execute completed >/dev/null 2>&1
  cd "$ROOT" && bash "$SPRINT_CTL" end "$id" >/dev/null 2>&1
  echo "$id"
}

# ── Basic functionality ──

run_test "no sprint ID → usage error" '
  OUTPUT=$(bash "$INSIGHT_STATS" 2>&1) || true
  assert_contains "Usage" "$OUTPUT"
'

run_test "nonexistent sprint → no data message" '
  OUTPUT=$(cd "$ROOT" && bash "$INSIGHT_STATS" "nonexistent-id" 2>&1)
  assert_contains "no data" "$OUTPUT"
'

run_test "insufficient history (<2 sprints) → insufficient message" '
  ID=$(make_completed_sprint "single sprint")
  OUTPUT=$(cd "$ROOT" && bash "$INSIGHT_STATS" "$ID" 2>&1)
  assert_contains "insufficient" "$OUTPUT"
'

run_test "3 completed sprints → comparison table output" '
  ID1=$(make_completed_sprint "hist 1")
  ID2=$(make_completed_sprint "hist 2")
  ID3=$(make_completed_sprint "current")
  OUTPUT=$(cd "$ROOT" && bash "$INSIGHT_STATS" "$ID3" 2>&1)
  assert_contains "Historical Comparison" "$OUTPUT"
  assert_contains "总耗时" "$OUTPUT"
  assert_contains "Anchor 通过率" "$OUTPUT"
  assert_contains "Task 完成率" "$OUTPUT"
'

run_test "comparison table has trend indicators" '
  ID1=$(make_completed_sprint "trend 1")
  ID2=$(make_completed_sprint "trend 2")
  ID3=$(make_completed_sprint "trend current")
  OUTPUT=$(cd "$ROOT" && bash "$INSIGHT_STATS" "$ID3" 2>&1)
  # Should contain table structure
  assert_contains "| 指标 |" "$OUTPUT"
  assert_contains "| 本次 |" "$OUTPUT"
'

run_test "sprint with anchor data → anchor rate in output" '
  ID1=$(make_completed_sprint "anchor hist 1")
  # Inject anchor data into metrics
  echo "anchor_check|$(date +%s)|pass=3|fail=0|skip=0" >> "$SPRINT_DIR/$ID1/metrics.log"
  ID2=$(make_completed_sprint "anchor hist 2")
  echo "anchor_check|$(date +%s)|pass=2|fail=1|skip=0" >> "$SPRINT_DIR/$ID2/metrics.log"
  ID3=$(make_completed_sprint "anchor current")
  echo "anchor_check|$(date +%s)|pass=5|fail=0|skip=0" >> "$SPRINT_DIR/$ID3/metrics.log"
  OUTPUT=$(cd "$ROOT" && bash "$INSIGHT_STATS" "$ID3" 2>&1)
  assert_contains "Anchor 通过率" "$OUTPUT"
  assert_contains "100%" "$OUTPUT"
'

report
