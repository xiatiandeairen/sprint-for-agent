#!/usr/bin/env bats

load helpers.bash

setup()    { setup_sprint_env; }
teardown() { teardown_sprint_env; }

# ── evaluate ──────────────────────────────────────────────────────────────

@test "evaluate: all zero → plan,execute,insight only" {
  run bash "$SPRINT_CTL" evaluate 0 0 0
  assert_exit_ok
  assert_contains "plan,execute,insight"
  assert_contains "auto=0"
}

@test "evaluate: clarify=1 design=1 → brainstorm and design included" {
  run bash "$SPRINT_CTL" evaluate 1 1 0
  assert_exit_ok
  assert_contains "brainstorm,design,plan,execute,insight"
}

@test "evaluate: risk=1 → review included" {
  run bash "$SPRINT_CTL" evaluate 0 0 1
  assert_exit_ok
  assert_contains "plan,execute,review,insight"
}

@test "evaluate: keyword 'delete' forces risk even if RISK=0" {
  run bash "$SPRINT_CTL" evaluate 0 0 0 delete
  assert_exit_ok
  assert_contains "review"
}

@test "evaluate: keyword '迁移' (Chinese) forces risk" {
  run bash "$SPRINT_CTL" evaluate 0 0 0 迁移
  assert_exit_ok
  assert_contains "review"
}

@test "evaluate: auto=1 flag propagates to output" {
  run bash "$SPRINT_CTL" evaluate 1 0 0 auto=1
  assert_exit_ok
  assert_contains "auto=1"
}

@test "evaluate: --auto flag propagates to output" {
  run bash "$SPRINT_CTL" evaluate 1 0 0 --auto
  assert_exit_ok
  assert_contains "auto=1"
}

@test "evaluate: non-high-risk keyword does not force review" {
  run bash "$SPRINT_CTL" evaluate 0 0 0 refactor
  assert_exit_ok
  [[ "$output" != *"plan,execute,review"* ]] || { echo "review should NOT be included for 'refactor'" >&2; return 1; }
}

# ── create ────────────────────────────────────────────────────────────────

@test "create: writes state.json with required fields" {
  run bash "$SPRINT_CTL" create sprint "my task" "plan,execute,insight"
  assert_exit_ok
  local id; id=$(latest_sprint_id)
  [ -n "$id" ]
  local dir; dir=$(sprint_dir_for "$id")
  [ -f "$dir/state.json" ]
  [ "$(json_field "$dir/state.json" type)" = "sprint" ]
  [ "$(json_field "$dir/state.json" desc)" = "my task" ]
  [ "$(json_field "$dir/state.json" status)" = "created" ]
  [ "$(json_list_field "$dir/state.json" stages)" = "plan,execute,insight" ]
}

@test "create: complexity defaults to low, auto defaults to false" {
  run bash "$SPRINT_CTL" create sprint "t" "plan,execute,insight"
  local id; id=$(latest_sprint_id)
  local state; state=$(sprint_dir_for "$id")/state.json
  [ "$(json_field "$state" complexity)" = "low" ]
  [ "$(json_field "$state" auto)" = "False" ]
}

@test "create: complexity and auto flag accepted" {
  run bash "$SPRINT_CTL" create sprint "t" "plan,execute,insight" "medium" "1"
  local id; id=$(latest_sprint_id)
  local state; state=$(sprint_dir_for "$id")/state.json
  [ "$(json_field "$state" complexity)" = "medium" ]
  [ "$(json_field "$state" auto)" = "True" ]
}

@test "create: ID matches YYYYMMDD-HHMMSS-RRR pattern" {
  run bash "$SPRINT_CTL" create sprint "t" "plan,execute,insight"
  local id; id=$(latest_sprint_id)
  [[ "$id" =~ ^[0-9]{8}-[0-9]{6}-[0-9]{3}$ ]]
}

@test "create: initializes handoffs dir, anchors.txt, metrics.log" {
  run bash "$SPRINT_CTL" create sprint "t" "plan,execute,insight"
  local id; id=$(latest_sprint_id)
  local dir; dir=$(sprint_dir_for "$id")
  [ -d "$dir/handoffs" ]
  [ -f "$dir/anchors.txt" ]
  [ -f "$dir/metrics.log" ]
  grep -q "^sprint_start|$id|" "$dir/metrics.log"
}

@test "create: missing desc → error exit" {
  run bash "$SPRINT_CTL" create sprint "" "plan,execute,insight"
  assert_exit_fail
  assert_contains "description is required"
}

@test "create: missing stages → error exit" {
  run bash "$SPRINT_CTL" create sprint "t" ""
  assert_exit_fail
  assert_contains "stages are required"
}

# ── activate ──────────────────────────────────────────────────────────────

@test "activate: sets status=running and captures base_commit" {
  bash "$SPRINT_CTL" create sprint "t" "plan,execute,insight" >/dev/null
  local id; id=$(latest_sprint_id)
  run bash "$SPRINT_CTL" activate "$id"
  assert_exit_ok
  local state; state=$(sprint_dir_for "$id")/state.json
  [ "$(json_field "$state" status)" = "running" ]
  [ "$(json_field "$state" base_commit)" != "none" ]
  [ "$(json_field "$state" base_commit)" != "" ]
}

@test "activate: unknown id → error exit" {
  run bash "$SPRINT_CTL" activate "99999999-999999-999"
  assert_exit_fail
  assert_contains "not found"
}

# ── stage ─────────────────────────────────────────────────────────────────

@test "stage: running writes stage_start to metrics.log" {
  bash "$SPRINT_CTL" create sprint "t" "plan,execute,insight" >/dev/null
  local id; id=$(latest_sprint_id)
  bash "$SPRINT_CTL" activate "$id" >/dev/null
  run bash "$SPRINT_CTL" stage "$id" plan running
  assert_exit_ok
  local log; log=$(sprint_dir_for "$id")/metrics.log
  grep -q "^stage_start|plan|" "$log"
  local state; state=$(sprint_dir_for "$id")/state.json
  [ "$(json_field "$state" current_stage)" = "plan" ]
}

@test "stage: completed writes stage_end with duration" {
  bash "$SPRINT_CTL" create sprint "t" "plan,execute,insight" >/dev/null
  local id; id=$(latest_sprint_id)
  bash "$SPRINT_CTL" activate "$id" >/dev/null
  bash "$SPRINT_CTL" stage "$id" plan running >/dev/null
  run bash "$SPRINT_CTL" stage "$id" plan completed
  assert_exit_ok
  local log; log=$(sprint_dir_for "$id")/metrics.log
  grep -qE "^stage_end\|plan\|completed\|[0-9]+\|[0-9]+s$" "$log"
}

@test "stage: invalid status → error" {
  bash "$SPRINT_CTL" create sprint "t" "plan,execute,insight" >/dev/null
  local id; id=$(latest_sprint_id)
  run bash "$SPRINT_CTL" stage "$id" plan wat
  assert_exit_fail
  assert_contains "status must be"
}

@test "stage: skipped is valid status" {
  bash "$SPRINT_CTL" create sprint "t" "plan,execute,insight" >/dev/null
  local id; id=$(latest_sprint_id)
  run bash "$SPRINT_CTL" stage "$id" review skipped
  assert_exit_ok
}

# ── end ───────────────────────────────────────────────────────────────────

@test "end: marks status=completed and writes sprint_end to metrics.log" {
  bash "$SPRINT_CTL" create sprint "t" "plan,execute,insight" >/dev/null
  local id; id=$(latest_sprint_id)
  bash "$SPRINT_CTL" activate "$id" >/dev/null
  bash "$SPRINT_CTL" stage "$id" plan running >/dev/null
  bash "$SPRINT_CTL" stage "$id" plan completed >/dev/null
  run bash "$SPRINT_CTL" end "$id"
  assert_exit_ok
  local state; state=$(sprint_dir_for "$id")/state.json
  [ "$(json_field "$state" status)" = "completed" ]
  local log; log=$(sprint_dir_for "$id")/metrics.log
  grep -q "^sprint_end|$id|" "$log"
}

@test "end: appends summary.json entry" {
  bash "$SPRINT_CTL" create sprint "t" "plan,execute,insight" >/dev/null
  local id; id=$(latest_sprint_id)
  bash "$SPRINT_CTL" activate "$id" >/dev/null
  bash "$SPRINT_CTL" stage "$id" plan running >/dev/null
  bash "$SPRINT_CTL" stage "$id" plan completed >/dev/null
  bash "$SPRINT_CTL" end "$id" >/dev/null
  local sj="$SPRINT_HOME_TEST/projects/$(project_id)/summary.json"
  [ -f "$sj" ]
  python3 -c "
import json, sys
arr = json.load(open('$sj'))
assert isinstance(arr, list) and len(arr) >= 1, 'summary should be non-empty array'
entry = [e for e in arr if e['id']=='$id'][0]
assert entry['status']=='completed'
assert 'duration' in entry
assert 'stages' in entry
"
}

@test "end: appends global index.jsonl" {
  bash "$SPRINT_CTL" create sprint "t" "plan,execute,insight" >/dev/null
  local id; id=$(latest_sprint_id)
  bash "$SPRINT_CTL" activate "$id" >/dev/null
  bash "$SPRINT_CTL" stage "$id" plan running >/dev/null
  bash "$SPRINT_CTL" stage "$id" plan completed >/dev/null
  bash "$SPRINT_CTL" end "$id" >/dev/null
  grep -q "\"sprint_id\": \"$id\"" "$SPRINT_HOME_TEST/index.jsonl"
}

# ── list / report ─────────────────────────────────────────────────────────
#
# Prior smoke tests here (`list returns sprints` / `report runs on empty`) were
# removed per tests/unit/PRINCIPLES.md § Forbidden patterns: they only asserted
# exit 0 with no behavioral check. Absence-of-crash is not an invariant.
# Add real assertions here if/when list/report gain documented output contracts.
