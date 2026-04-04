#!/bin/bash
# gate.sh — Sprint 完整质量门禁
#
# 用法: gate.sh <anchor-path> [chunk-number]
# 输出: JSON { status, chunk, gates[], summary, diff_lines, test_count }
# 返回: 0=PASS, 1=FAIL, 2=WARN
#
# 9 项检查:
#   G1 build        编译
#   G2 test         测试
#   G3 invariants   Anchor 不变量
#   G4 boundaries   文件边界
#   G5 diff-budget  Diff 预算
#   G6 temp-code    临时代码增量
#   G7 size-trend   Chunk 大小趋势
#   G8 test-coverage 测试覆盖
#   G9 test-count   测试数量基线

set -euo pipefail
source "$(dirname "$0")/common.sh"

ANCHOR_PATH="${1:?用法: gate.sh <anchor-path> [chunk-number]}"
CHUNK_NUM="${2:-0}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

declare -a GATES=()
OVERALL="PASS"
TEST_PASSED=0
TOTAL_DIFF=0

add_gate() {
    local id="$1" name="$2" status="$3" detail="$4"
    # 转义 detail 中的双引号
    detail=$(echo "$detail" | sed 's/"/\\"/g')
    GATES+=("{\"id\":\"$id\",\"name\":\"$name\",\"status\":\"$status\",\"detail\":\"$detail\"}")
    if [ "$status" = "FAIL" ]; then
        OVERALL="FAIL"
    elif [ "$status" = "WARN" ] && [ "$OVERALL" != "FAIL" ]; then
        OVERALL="WARN"
    fi
}

# ═════════════════════════════════════
# 第一层：编译 + 测试
# ═════════════════════════════════════

# G1: build
# 找到合适的构建方式
if [ -f "$CLAUDE_PROJECT_DIR/src/mac/Loppy.xcworkspace/contents.xcworkspacedata" ]; then
    build_output=$(cd "$CLAUDE_PROJECT_DIR" && xcodebuild -workspace src/mac/Loppy.xcworkspace -scheme guard -destination 'platform=macOS' build 2>&1 | tail -5)
    if echo "$build_output" | grep -q 'BUILD SUCCEEDED\|Build complete'; then
        add_gate "G1" "build" "PASS" ""
    else
        add_gate "G1" "build" "FAIL" "xcodebuild 失败"
    fi
elif [ -f "$CLAUDE_PROJECT_DIR/Package.swift" ]; then
    if (cd "$CLAUDE_PROJECT_DIR" && swift build 2>&1) | tail -1 | grep -q 'Build complete'; then
        add_gate "G1" "build" "PASS" ""
    else
        add_gate "G1" "build" "FAIL" "swift build 失败"
    fi
else
    add_gate "G1" "build" "PASS" "无构建配置，跳过"
fi

# G2: test
# 按模块跑测试（项目有多个 SPM package）
test_output=""
test_failed_total=0
test_passed_total=0

# 尝试各个模块目录
for pkg_dir in "$CLAUDE_PROJECT_DIR"/src/mac/Packages/*/; do
    if [ -f "$pkg_dir/Package.swift" ] && [ -d "$pkg_dir/Tests" ]; then
        pkg_test_output=$(cd "$pkg_dir" && swift test 2>&1 || true)
        passed=$(echo "$pkg_test_output" | grep -oE '[0-9]+ test[s]? passed' | grep -oE '[0-9]+' | head -1 || echo 0)
        failed=$(echo "$pkg_test_output" | grep -oE '[0-9]+ test[s]? failed' | grep -oE '[0-9]+' | head -1 || echo 0)
        test_passed_total=$((test_passed_total + ${passed:-0}))
        test_failed_total=$((test_failed_total + ${failed:-0}))
    fi
done

TEST_PASSED=$test_passed_total
if [ "$test_failed_total" -eq 0 ] && [ "$test_passed_total" -gt 0 ]; then
    add_gate "G2" "test" "PASS" "$test_passed_total passed"
elif [ "$test_passed_total" -eq 0 ] && [ "$test_failed_total" -eq 0 ]; then
    add_gate "G2" "test" "PASS" "无测试"
else
    add_gate "G2" "test" "FAIL" "$test_passed_total passed, $test_failed_total failed"
fi

# ═════════════════════════════════════
# 第二层：Anchor 不变量
# ═════════════════════════════════════

# G3: invariants
if [ -f "$ANCHOR_PATH" ]; then
    verify_output=$("$SCRIPT_DIR/anchor-verify.sh" "$ANCHOR_PATH" 2>/dev/null || true)
    verify_status=$(echo "$verify_output" | jq -r '.status // "ERROR"' 2>/dev/null)
    verify_detail=$(echo "$verify_output" | jq -r '.detail // ""' 2>/dev/null)
    add_gate "G3" "invariants" "$verify_status" "$verify_detail"
else
    add_gate "G3" "invariants" "WARN" "Anchor 文件不存在"
fi

# ═════════════════════════════════════
# 第三层：Scope 守卫
# ═════════════════════════════════════

# G4: boundaries
if [ -f "$ANCHOR_PATH" ]; then
    drift_output=$("$SCRIPT_DIR/drift-detect.sh" "$ANCHOR_PATH" 2>/dev/null || true)
    drifted=$(echo "$drift_output" | jq -r '.drifted // false' 2>/dev/null)
    if [ "$drifted" = "true" ]; then
        v_count=$(echo "$drift_output" | jq -r '.violation_count // 0' 2>/dev/null)
        v_files=$(echo "$drift_output" | jq -r '.violations[].file' 2>/dev/null | head -3 | tr '\n' ', ')
        add_gate "G4" "boundaries" "FAIL" "$v_count 个边界违反: $v_files"
    else
        add_gate "G4" "boundaries" "PASS" ""
    fi
else
    add_gate "G4" "boundaries" "PASS" "无 Anchor，跳过"
fi

# G5: diff budget
diff_stat=$(cd "$CLAUDE_PROJECT_DIR" && git diff --stat HEAD~1 2>/dev/null | tail -1 || echo "")
diff_insertions=$(echo "$diff_stat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
diff_deletions=$(echo "$diff_stat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo 0)
TOTAL_DIFF=$((${diff_insertions:-0} + ${diff_deletions:-0}))

diff_budget=150  # 默认
chunks_path=$(sprint_get 'chunks_path' 2>/dev/null || echo "")
if [ -f "$chunks_path" ] && [ "$CHUNK_NUM" -gt 0 ]; then
    budget=$(grep -A10 "Chunk $CHUNK_NUM" "$chunks_path" 2>/dev/null | grep -oE '≤ *[0-9]+' | grep -oE '[0-9]+' | head -1 || echo "")
    [ -n "$budget" ] && diff_budget=$budget
fi

if [ "$TOTAL_DIFF" -le "$diff_budget" ]; then
    add_gate "G5" "diff-budget" "PASS" "$TOTAL_DIFF 行 (预算 $diff_budget)"
else
    add_gate "G5" "diff-budget" "FAIL" "$TOTAL_DIFF 行 > 预算 $diff_budget"
fi

# G6: temp code
baseline_todo=$(sprint_get 'baselines.todo_count' 2>/dev/null || echo "0")
current_todo=$(cd "$CLAUDE_PROJECT_DIR" && grep -rE 'TODO|TEMP|HACK|FIXME' src/ 2>/dev/null | wc -l | tr -d ' ' || echo 0)
todo_delta=$((current_todo - baseline_todo))

if [ "$todo_delta" -le 0 ]; then
    add_gate "G6" "temp-code" "PASS" "delta: $todo_delta"
else
    add_gate "G6" "temp-code" "WARN" "新增 $todo_delta 个 TODO/TEMP/HACK"
fi

# ═════════════════════════════════════
# 第四层：质量衰减检测
# ═════════════════════════════════════

# G7: size trend
if [ -f "$SPRINT_METRICS_FILE" ] && [ -s "$SPRINT_METRICS_FILE" ] && [ "$CHUNK_NUM" -gt 1 ]; then
    recent_count=$(wc -l < "$SPRINT_METRICS_FILE" | tr -d ' ')
    if [ "$recent_count" -ge 2 ]; then
        avg_lines=$(jq -s '[.[].diff_lines] | add / length | floor' "$SPRINT_METRICS_FILE" 2>/dev/null || echo 0)
        if [ "$avg_lines" -gt 0 ] && [ "$TOTAL_DIFF" -gt $((avg_lines * 2)) ]; then
            add_gate "G7" "size-trend" "WARN" "当前 $TOTAL_DIFF 行 > 均值 ${avg_lines} 的 2 倍"
        else
            add_gate "G7" "size-trend" "PASS" ""
        fi
    else
        add_gate "G7" "size-trend" "PASS" "数据不足"
    fi
else
    add_gate "G7" "size-trend" "PASS" "首个 chunk"
fi

# G8: test coverage
changed_files=$(cd "$CLAUDE_PROJECT_DIR" && git diff --name-only HEAD~1 2>/dev/null || echo "")
src_changed=$(echo "$changed_files" | grep -cE '\.swift$' 2>/dev/null || echo 0)
test_changed=$(echo "$changed_files" | grep -ciE 'test' 2>/dev/null || echo 0)

if [ "$src_changed" -gt 0 ] && [ "$test_changed" -eq 0 ]; then
    add_gate "G8" "test-coverage" "WARN" "改了 $src_changed 个源文件但无测试变更"
else
    add_gate "G8" "test-coverage" "PASS" ""
fi

# G9: test count baseline
baseline_tests=$(sprint_get 'baselines.test_count' 2>/dev/null || echo "0")
if [ "$baseline_tests" -gt 0 ] && [ "$TEST_PASSED" -lt "$baseline_tests" ]; then
    add_gate "G9" "test-count" "FAIL" "测试数 $TEST_PASSED < 基线 $baseline_tests"
else
    add_gate "G9" "test-count" "PASS" "$TEST_PASSED ≥ $baseline_tests"
fi

# ═════════════════════════════════════
# 输出 JSON
# ═════════════════════════════════════

pass_count=$(printf '%s\n' "${GATES[@]}" | grep -c '"PASS"' || echo 0)
warn_count=$(printf '%s\n' "${GATES[@]}" | grep -c '"WARN"' || echo 0)
fail_count=$(printf '%s\n' "${GATES[@]}" | grep -c '"FAIL"' || echo 0)

gates_json=$(printf '%s,' "${GATES[@]}")
gates_json="${gates_json%,}"

cat <<EOF
{
  "status": "$OVERALL",
  "chunk": $CHUNK_NUM,
  "gates": [$gates_json],
  "summary": "$pass_count/9 PASS, $warn_count WARN, $fail_count FAIL",
  "diff_lines": $TOTAL_DIFF,
  "test_count": $TEST_PASSED
}
EOF

case "$OVERALL" in
    PASS) exit 0 ;;
    WARN) exit 2 ;;
    FAIL) exit 1 ;;
esac
