#!/usr/bin/env bash
# tests/unit/test-review-structure.sh — stages/review.md 结构单元测试
#
# 注：review 有 7 个 ## Step header (Step 0-6)，但 Progress total: 6——
# Step 0 (Cross-Task Regression) 是条件性 gate 不计入主流程。本测兼顾两者。

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
TARGET="$REPO_ROOT/stages/review.md"

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
  # 7 step headers (Step 0-6)
  assert_count "7 steps incl. Step 0" "^## Step [0-6]:" 7
}

test_step_names() {
  assert_contains "step 0" "## Step 0: Cross-Task Regression" || return 1
  assert_contains "step 1" "## Step 1: Change Understanding"  || return 1
  assert_contains "step 2" "## Step 2: Five-Layer Analysis"   || return 1
  assert_contains "step 3" "## Step 3: Governance Opportunities" || return 1
  assert_contains "step 4" "## Step 4: Present Findings"      || return 1
  assert_contains "step 5" "## Step 5: Write Handoff"         || return 1
  assert_contains "step 6" "## Step 6: User Decision"         || return 1
}

test_model_declarations() {
  # Multiple sub-sections declare Model (Depth Selection + 7 steps)
  local n
  n=$(grep -cE "^Model: " "$TARGET" 2>/dev/null || true)
  if [ "$n" -ge 7 ]; then return 0; fi
  echo "  expected ≥7 Model declarations, got $n"
  return 1
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

# ─── review-specific assertions ───

test_first_principle() {
  assert_contains "first principle"   "First principle"     || return 1
  assert_contains "future modification cost" "future modification cost" || return 1
}

test_five_layer_names() {
  assert_contains "L1 layer" "L1: Task-Level Residual Risk" || return 1
  assert_contains "L2 layer" "L2: Code Decision Quality"    || return 1
  assert_contains "L3 layer" "L3: Structural Quality"       || return 1
  assert_contains "L4 layer" "L4: Pattern Layer"            || return 1
  assert_contains "L5 layer" "L5: Evolution Layer"          || return 1
}

test_depth_selection() {
  assert_contains "Depth Selection heading" "Depth Selection" || return 1
  assert_contains "depth quick" "quick"  || return 1
  assert_contains "depth full"  "full"   || return 1
}

test_change_type_detection() {
  assert_contains "delete-migrate"             "delete-migrate"             || return 1
  assert_contains "add-feature-single-module"  "add-feature-single-module"  || return 1
  assert_contains "refactor-structural"        "refactor-structural"        || return 1
}

test_problem_template_fields() {
  # 12-field problem template
  assert_contains "Layer field"        "Layer"        || return 1
  assert_contains "Severity field"     "Severity"     || return 1
  assert_contains "Observation field"  "Observation"  || return 1
  assert_contains "Essence field"      "Essence"      || return 1
  assert_contains "Impact field"       "Impact"       || return 1
  assert_contains "Scope field"        "Scope"        || return 1
  assert_contains "Action field"       "Action"       || return 1
  assert_contains "Fix field"          "Fix"          || return 1
  assert_contains "Spread fix field"   "Spread fix"   || return 1
  assert_contains "Spread boundary"    "Spread boundary" || return 1
  assert_contains "Spread risk"        "Spread risk"  || return 1
  assert_contains "Automation field"   "Automation"   || return 1
}

test_severity_levels() {
  assert_contains "blocking severity"      "blocking"      || return 1
  assert_contains "important severity"     "important"     || return 1
  assert_contains "opportunistic severity" "opportunistic" || return 1
}

test_action_verdict_options() {
  # Step 4 G section verdict options
  assert_contains "verdict approve"        "approve"          || return 1
  assert_contains "approve with fixes"     "with targeted fixes" || return 1
  assert_contains "verdict cleanup"        "significant cleanup" || return 1
  assert_contains "verdict split"          "split refactor"      || return 1
}

test_findings_template_letters() {
  # A-G output structure
  assert_contains "section A" "## A. Change Understanding"  || return 1
  assert_contains "section B" "## B. Conclusion Overview"   || return 1
  assert_contains "section C" "## C. Core Issues"           || return 1
  assert_contains "section D" "## D. Pattern Signals"       || return 1
  assert_contains "section E" "## E. Autofix"               || return 1
  assert_contains "section F" "## F. Convention Candidates" || return 1
  assert_contains "section G" "## G. Action Decision"       || return 1
}

test_auto_mode_decision_id() {
  # review has D6-review-verdict self-check
  assert_contains "D6 decision id" "D6-review-verdict"
}

run_tests "$@"
