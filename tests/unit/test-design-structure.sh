#!/usr/bin/env bash
# tests/unit/test-design-structure.sh — stages/design.md 结构单元测试

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
TARGET="$REPO_ROOT/stages/design.md"

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
  assert_contains "total: 5" "- total: 5"
}

test_step_count() {
  assert_count "5 steps" "^## Step [1-5]:" 5
}

test_step_names() {
  assert_contains "step 1" "## Step 1: Solution Approach"           || return 1
  assert_contains "step 2" "## Step 2: Solution Alignment"          || return 1
  assert_contains "step 3" "## Step 3: Implementation Priority Review" || return 1
  assert_contains "step 4" "## Step 4: System Design"               || return 1
  assert_contains "step 5" "## Step 5: Write Handoff"               || return 1
}

test_model_declarations() {
  assert_count "Model declarations" "^Model: (opus|sonnet|haiku)" 5
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

# ─── design-specific assertions ───

test_four_sub_layers() {
  assert_contains "Architecture sub-layer"     "Architecture"          || return 1
  assert_contains "Core Flow sub-layer"        "Core Flow"             || return 1
  assert_contains "Interface sub-layer"        "Interface & Protocol"  || return 1
  assert_contains "Algorithm sub-layer"        "Algorithm"             || return 1
}

test_suggested_task_boundaries() {
  assert_contains "task boundaries section" "Suggested Task Boundaries" || return 1
  assert_contains "boundaries column"       "Independence Rationale"     || return 1
}

test_spec_preferences_fields() {
  assert_contains "scope field"          "scope"          || return 1
  assert_contains "depth field"          "depth"          || return 1
  assert_contains "transition field"     "transition"     || return 1
  assert_contains "compatibility field"  "compatibility"  || return 1
}

test_spec_preferences_enum_values() {
  assert_contains "precise"        "precise"         || return 1
  assert_contains "extended"       "extended"        || return 1
  assert_contains "patch"          "patch"           || return 1
  assert_contains "root-cause"     "root-cause"      || return 1
  assert_contains "direct"         "direct"          || return 1
  assert_contains "incremental"    "incremental"     || return 1
  assert_contains "strict"         "strict"          || return 1
  assert_contains "internal-break" "internal-break"  || return 1
  assert_contains "undecided"      "undecided"       || return 1
}

test_decision_register_categories() {
  assert_contains "core category"   "core"   || return 1
  assert_contains "detail category" "detail" || return 1
}

test_decision_register_status() {
  assert_contains "confirmed status" "confirmed" || return 1
  assert_contains "direction status" "direction" || return 1
  assert_contains "open status"      "open"      || return 1
}

test_form_artifact_table() {
  # design Step 2 form-to-artifact mapping
  assert_contains "Feature form"          "Feature"                 || return 1
  assert_contains "Workflow form"         "Workflow"                || return 1
  assert_contains "Decision Policy form"  "Decision Policy"         || return 1
  assert_contains "Automation form"       "Automation"              || return 1
  assert_contains "Data Structure form"   "Data Structure"          || return 1
}

test_auto_mode_decision_ids() {
  # design has D2 / D3 / D4 self-check anchors
  assert_contains "D2 decision id" "D2-solution-approach" || return 1
  assert_contains "D3 decision id" "D3-design-decisions"  || return 1
  assert_contains "D4 decision id" "D4-system-design"     || return 1
}

test_handoff_template_sections() {
  assert_contains "handoff Conclusion"        "## Conclusion"        || return 1
  assert_contains "handoff Solution Approach" "## Solution Approach" || return 1
  assert_contains "handoff Design Content"    "## Design Content"    || return 1
  assert_contains "handoff File Structure"    "## File Structure"    || return 1
  assert_contains "handoff Decision Register" "## Decision Register" || return 1
  assert_contains "handoff Spec Preferences"  "## Spec Preferences"  || return 1
  assert_contains "handoff Downstream"        "## Downstream"        || return 1
}

test_exit_rules() {
  # No `open` status allowed; all `core` confirmed
  assert_contains "no open rule"      "No \`open\`"     || return 1
  assert_contains "all core confirmed" "core\` entries" || return 1
}

run_tests "$@"
