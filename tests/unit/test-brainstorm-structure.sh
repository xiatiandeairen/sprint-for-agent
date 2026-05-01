#!/usr/bin/env bash
# tests/unit/test-brainstorm-structure.sh — stages/brainstorm.md 结构单元测试

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
TARGET="$REPO_ROOT/stages/brainstorm.md"

# shellcheck source=test-stage-helpers.sh
source "$SCRIPT_DIR/test-stage-helpers.sh"

# ─── general assertions ───

test_file_exists() {
  [ -f "$TARGET" ] && return 0
  echo "  file not found: $TARGET"
  return 1
}

test_progress_section() {
  assert_contains "progress" "## Progress"
}

test_progress_total() {
  assert_contains "total: 2" "- total: 2"
}

test_step_count() {
  assert_count "2 steps" "^## Step [1-2]:" 2
}

test_step_names() {
  assert_contains "step 1" "## Step 1: Demand Modeling" || return 1
  assert_contains "step 2" "## Step 2: Converge" || return 1
}

test_model_declarations() {
  # 2 Steps + 1 Optional Extension (Value Mining) each declare Model
  assert_count "Model declarations" "^Model: (opus|sonnet|haiku)" 3
}

test_hard_rules_section() {
  assert_contains "Hard Rules" "## Hard Rules"
}

test_completion_section() {
  assert_contains "Completion" "## Completion"
}

test_recovery_section() {
  assert_contains "Recovery" "## Recovery"
}

# ─── brainstorm-specific assertions ───

test_six_slot_frame() {
  assert_contains "Goal slot"       "Goal" || return 1
  assert_contains "Object slot"     "Object" || return 1
  assert_contains "Constraint slot" "Constraint" || return 1
  assert_contains "Context slot"    "Context" || return 1
  assert_contains "Success slot"    "Success" || return 1
  assert_contains "Priority slot"   "Priority" || return 1
}

test_sanity_gate_questions() {
  # Sanity Gate Q1-Q5
  assert_contains "Q1" "Is the real pain" || return 1
  assert_contains "Q2" "deleting the requirement" || return 1
  assert_contains "Q3" "existing tool" || return 1
  assert_contains "Q4" "minimum path" || return 1
  assert_contains "Q5" "assumptions all verifiable" || return 1
}

test_pushback_trigger_column() {
  assert_contains "Pushback trigger" "Pushback trigger"
}

test_q3_market_subquestions() {
  assert_contains "Q3a" "Q3a" || return 1
  assert_contains "Q3b" "Q3b" || return 1
  assert_contains "Q3c" "Q3c" || return 1
}

test_q4_feasibility_subquestions() {
  assert_contains "Q4a" "Q4a" || return 1
  assert_contains "Q4b" "Q4b" || return 1
  assert_contains "Q4c" "Q4c" || return 1
}

test_q3_same_category_constraint() {
  assert_contains "same-category" "same-category" || return 1
  assert_contains "competitor table" "同品类" || return 1
}

test_ambiguity_triage_signals() {
  assert_contains "Verb ambiguity"    "Verb ambiguity" || return 1
  assert_contains "Scope ambiguity"   "Scope ambiguity" || return 1
  assert_contains "Outcome ambiguity" "Outcome ambiguity" || return 1
}

test_assumptions_block_format() {
  assert_contains "Assumptions header" "## Assumptions" || return 1
  assert_contains "A1 marker" "[A1]" || return 1
  assert_contains "A2 marker" "[A2]" || return 1
  assert_contains "A3 marker" "[A3]" || return 1
}

test_value_mining_section() {
  assert_contains "Value Mining heading" "Value Mining"
}

test_value_mining_diagnostics() {
  # 6 个诊断问题
  assert_contains "diag repeated"   "Task done repeatedly"     || return 1
  assert_contains "diag manual"     "Manual step eliminable"   || return 1
  assert_contains "diag silent"     "Could fail silently"      || return 1
  assert_contains "diag reusable"   "Output reusable elsewhere" || return 1
  assert_contains "diag implicit"   "Implicit decision"        || return 1
  assert_contains "diag recurring"  "Recurring pattern"        || return 1
}

test_handoff_template_sections() {
  assert_contains "handoff Conclusion"   "## Conclusion"   || return 1
  assert_contains "handoff Demand Frame" "## Demand Frame" || return 1
  assert_contains "handoff Scope"        "## Scope"        || return 1
  assert_contains "handoff Value Points" "## Value Points" || return 1
  assert_contains "handoff Downstream"   "## Downstream"   || return 1
}

test_auto_mode_self_check_marker() {
  assert_contains "D1 decision id" "D1-demand-lock"
}

run_tests "$@"
