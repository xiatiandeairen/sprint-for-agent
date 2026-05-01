#!/usr/bin/env bash
# tests/unit/test-insight-structure.sh — stages/insight.md 结构单元测试
#
# 注：insight 有 6 个 ## Step header (Step 1, 1.5, 2, 3, 4, 5)，
# 但 Progress total: 5——Step 1.5 是 D 规则强制前置 sub-step 不计入主流程。

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
TARGET="$REPO_ROOT/stages/insight.md"

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

test_step_count_main() {
  # 5 main steps (1, 2, 3, 4, 5)
  assert_count "5 main steps" "^## Step [1-5]:" 5
}

test_step_one_and_half() {
  # 强制前置 sub-step
  assert_contains "Step 1.5"  "## Step 1.5: Counter-Evidence" || return 1
}

test_step_names() {
  assert_contains "step 1" "## Step 1: End Sprint"          || return 1
  assert_contains "step 2" "## Step 2: Deviation Analysis"  || return 1
  assert_contains "step 3" "## Step 3: Process Evaluation"  || return 1
  assert_contains "step 4" "## Step 4: Lessons"             || return 1
  assert_contains "step 5" "## Step 5: 自动审视汇总"         || return 1
}

test_model_declarations() {
  # Each step + 1.5 declare Model = 6
  assert_count "6 Model declarations" "^Model: (opus|sonnet|haiku)" 6
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

# ─── insight-specific assertions ───

test_sprint_ctl_end_call() {
  assert_contains "SPRINT_CTL var" '$SPRINT_CTL'  || return 1
  assert_contains "end command"    'end "{id}"'   || return 1
}

test_counter_evidence_d_rule() {
  # Step 1.5 D 规则强制 ≥2 反例
  assert_contains "D rule label"     "D 规则"  || return 1
  assert_contains "min 2 counter"    "≥2 条反例" || return 1
}

test_deviation_classifications() {
  assert_contains "improvement class"     "improvement"     || return 1
  assert_contains "issue class"           "issue"           || return 1
  assert_contains "change-request class"  "change-request"  || return 1
}

test_process_evaluation_thresholds() {
  # Time flags: >40% too heavy, <5% too light
  assert_contains "too heavy"  "too heavy"  || return 1
  assert_contains "too light"  "too light"  || return 1
  assert_contains "essential"  "essential"  || return 1
  assert_contains "could skip" "could skip" || return 1
}

test_lessons_filter_pipeline() {
  # Lesson → Memory pipeline
  assert_contains "lesson memory pipeline" "Lesson → Memory Pipeline" || return 1
  assert_contains "discard task-specific"  "discard"                  || return 1
  assert_contains "persist memory"         "persist to auto memory"   || return 1
}

test_auto_summary_table_columns() {
  # Step 5 表格版 列名
  assert_contains "ID column"          "| ID |"          || return 1
  assert_contains "Stage column"       "Stage"           || return 1
  assert_contains "决策 column"         "决策"            || return 1
  assert_contains "G1 risk column"     "G1 风险"          || return 1
  assert_contains "G2 reject column"   "G2 拒选"          || return 1
  assert_contains "G3 blindspot column" "G3 盲点"        || return 1
}

test_auto_summary_decision_ids() {
  # All 6 decision IDs referenced (D1 sample)
  assert_contains "D1 sample" "D1-demand-lock" || return 1
}

test_auto_summary_command_handling() {
  # approve / 重跑 / 审视
  assert_contains "approve cmd" "approve"  || return 1
  assert_contains "rerun cmd"   "重跑"     || return 1
  assert_contains "review cmd"  "审视"     || return 1
}

test_human_readable_first_rule() {
  # B2: 人话版在前
  assert_contains "B2 rule"             "B2 规则"   || return 1
  assert_contains "human first"         "人话版在前" || return 1
}

test_history_compare_script() {
  assert_contains "stats script" "sprint-insight-stats.sh"
}

test_terminal_no_handoff() {
  # insight is terminal — no handoff
  assert_contains "no handoff" "No handoff"
}

run_tests "$@"
