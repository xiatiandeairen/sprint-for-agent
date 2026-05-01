#!/usr/bin/env bash
# tests/unit/test-execute-structure.sh — stages/execute.md 结构单元测试
#
# 注：execute.md 不使用 `## Step N:` 标题；其 4 个 step 用具名 section 表达
# (Stage Start / Step-by-step Mode / Parallel Mode / Write Handoff)。本测按
# 该形态断言。

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
TARGET="$REPO_ROOT/stages/execute.md"

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
  assert_contains "total: 4" "- total: 4"
}

test_named_sections() {
  # execute uses named sections instead of `## Step N:`
  assert_contains "task tracking"  "## Stage Start: Task Tracking" || return 1
  assert_contains "step-by-step"   "## Step-by-step Mode"          || return 1
  assert_contains "parallel mode"  "## Parallel Mode"              || return 1
  assert_contains "write handoff"  "## Write Handoff"              || return 1
}

test_model_declarations() {
  # Stage Start + Step-by-step + Parallel + Write Handoff = 4 minimum;
  # parallel + step-by-step have sub-sections that may add more
  local n
  n=$(grep -cE "^Model: " "$TARGET" 2>/dev/null || true)
  if [ "$n" -ge 4 ]; then return 0; fi
  echo "  expected ≥4 Model declarations, got $n"
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

# ─── execute-specific assertions ───

test_anchor_check_invocation() {
  # execute must call anchor-check.sh after each task
  assert_contains "anchor-check var" "ANCHOR_CHECK"      || return 1
  assert_contains "anchor-check run" "anchor-check"      || return 1
}

test_default_anchors_section() {
  # MUST_BUILD auto-add for typed languages
  assert_contains "Default Anchors heading" "## Default Anchors" || return 1
  assert_contains "MUST_BUILD default"      "MUST_BUILD"         || return 1
}

test_tdd_process() {
  # Code task type uses TDD: write test → FAIL → implement → PASS
  assert_contains "TDD line"       "TDD"          || return 1
  assert_contains "TDD fail"       "FAIL"         || return 1
  assert_contains "TDD pass"       "PASS"         || return 1
}

test_observer_synthesizer_rule() {
  # B rule: handoff 禁止 verdict / 结论
  assert_contains "Observer/Synthesizer" "Observer/Synthesizer" || return 1
  assert_contains "禁止 verdict"          "verdict"             || return 1
}

test_handoff_handover_scope_rule() {
  # B6-b: 跨 sprint 信息不走 handoff
  assert_contains "B6-b rule" "B6-b" || return 1
}

test_doc_mode_handling() {
  assert_contains "doc mode" "Doc mode" || return 1
}

test_parallel_worktree() {
  assert_contains "EnterWorktree" "EnterWorktree" || return 1
  assert_contains "ExitWorktree"  "ExitWorktree"  || return 1
}

test_subagent_recovery() {
  # 1st retry, 2nd upgrade, 3rd stop
  assert_contains "subagent recovery" "1st failure" || return 1
  assert_contains "model upgrade"     "sonnet → opus" || return 1
}

test_handoff_template_sections() {
  assert_contains "handoff Summary"            "## Summary"            || return 1
  assert_contains "handoff Tasks"              "## Tasks"              || return 1
  assert_contains "handoff Raw Observations"   "## Raw Observations"   || return 1
  assert_contains "handoff Open Questions"     "## Open Questions"     || return 1
  assert_contains "handoff Downstream"         "## Downstream"         || return 1
}

test_forbidden_handoff_content() {
  # explicit ban list
  assert_contains "forbid keep/drop"   "keep/drop"      || return 1
  assert_contains "forbid recommendation" "Recommendation" || return 1
}

test_cooldown_check() {
  # >10 data points or >1800s triggers Cooldown
  assert_contains "Cooldown Check" "Cooldown Check" || return 1
}

run_tests "$@"
