#!/usr/bin/env bash
# tests/unit/test-plan-structure.sh — stages/plan.md 结构单元测试

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
TARGET="$REPO_ROOT/stages/plan.md"

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
  assert_contains "total: 6" "- total: 6"
}

test_step_count() {
  assert_count "6 steps" "^## Step [1-6]:" 6
}

test_step_names() {
  assert_contains "step 1" "## Step 1: Spec Preferences"   || return 1
  assert_contains "step 2" "## Step 2: Decision Points"    || return 1
  assert_contains "step 3" "## Step 3: Generate Anchors"   || return 1
  assert_contains "step 4" "## Step 4: Split Tasks"        || return 1
  assert_contains "step 5" "## Step 5: Confirm Execution"  || return 1
  assert_contains "step 6" "## Step 6: Write Handoff"      || return 1
}

test_model_declarations() {
  assert_count "Model declarations" "^Model: (opus|sonnet|haiku)" 6
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

# ─── plan-specific assertions ───

test_nine_anchor_types() {
  assert_contains "MUST_BUILD"        "MUST_BUILD"        || return 1
  assert_contains "MUST_EXIST"        "MUST_EXIST"        || return 1
  assert_contains "MUST_TEST"         "MUST_TEST"         || return 1
  assert_contains "MUST_IMPORT"       "MUST_IMPORT"       || return 1
  assert_contains "MUST_NOT_IMPORT"   "MUST_NOT_IMPORT"   || return 1
  assert_contains "MUST_NOT_EXIST"    "MUST_NOT_EXIST"    || return 1
  assert_contains "MUST_CONTAIN"      "MUST_CONTAIN"      || return 1
  assert_contains "MUST_NOT_CONTAIN"  "MUST_NOT_CONTAIN"  || return 1
  assert_contains "FILE_NOT_MODIFIED" "FILE_NOT_MODIFIED" || return 1
}

test_anchor_translation_rules() {
  # Anchor 翻译规则 table maps each rule to a 一句中文 template
  assert_contains "翻译规则 heading" "Anchor 翻译规则" || return 1
  assert_contains "translation column" "一句中文模板"   || return 1
}

test_anchor_recommendation_signals() {
  assert_contains "recommend section" "可能还需要补"           || return 1
  assert_contains "max 3 hint"        "最多 3 条"              || return 1
  assert_contains "do-not-touch sig"  "do-not-touch"           || return 1
}

test_complexity_size_table() {
  # S/M/L/XL classification
  assert_contains "S size"  "| S |"  || return 1
  assert_contains "M size"  "| M |"  || return 1
  assert_contains "L size"  "| L |"  || return 1
  assert_contains "XL size" "| XL |" || return 1
}

test_gate_merge_rule() {
  assert_contains "gate merge rule" "Gate merge rule" || return 1
  assert_contains "gate merge desc" "Steps 3+4+5"     || return 1
}

test_splitting_rules() {
  assert_contains "splitting rules"     "Splitting Rules"          || return 1
  assert_contains "independent verify"  "Independent verifiability" || return 1
  assert_contains "single responsibility" "Single responsibility"   || return 1
}

test_spec_preferences_dimensions() {
  # plan 继承 design Spec Preferences；4 core + 2 auxiliary dimensions
  assert_contains "Q1 scope"          "Q1"           || return 1
  assert_contains "Q2 depth"          "Q2"           || return 1
  assert_contains "Q3 transition"     "Q3"           || return 1
  assert_contains "Q4 compatibility"  "Q4"           || return 1
  assert_contains "auxiliary core split" "Auxiliary" || return 1
}

test_inherit_from_design() {
  assert_contains "inherit logic"    "Inherit from design"  || return 1
  assert_contains "undecided handle" "undecided"            || return 1
}

test_override_path() {
  assert_contains "override path"    "Override path"     || return 1
  assert_contains "override keyword" "重新决策"            || return 1
}

test_auto_mode_decision_id() {
  # plan has D5-task-split self-check
  assert_contains "D5 decision id" "D5-task-split"
}

test_handoff_template_sections() {
  assert_contains "handoff Execution Mode"   "## Execution Mode"   || return 1
  assert_contains "handoff Commit Pref"      "## Commit Preference" || return 1
  assert_contains "handoff Spec Pref"        "## Spec Preferences"  || return 1
  assert_contains "handoff Tasks"            "## Tasks"             || return 1
  assert_contains "handoff Expected Files"   "## Expected Files"    || return 1
  assert_contains "handoff Downstream"       "## Downstream"        || return 1
}

run_tests "$@"
