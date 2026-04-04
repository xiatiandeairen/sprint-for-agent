#!/bin/bash
# anchor-verify.sh — 逐条执行 Anchor Invariants 检查
#
# 用法: anchor-verify.sh <anchor-path>
# 输出: JSON { status, detail, checks[] }
#
# Invariants 表格格式:
#   | # | 描述 | 检查命令 | 预期 |
# 预期格式: = N | ≤ N | ≥ N | PASS | CONTAINS text

set -euo pipefail
source "$(dirname "$0")/common.sh"

ANCHOR_PATH="${1:?用法: anchor-verify.sh <anchor-path>}"

declare -a CHECKS=()
OVERALL="PASS"
TOTAL=0
PASSED=0

# 解析 Invariants 段落
in_invariants=false
while IFS= read -r line; do
    if echo "$line" | grep -q '^## Invariants'; then
        in_invariants=true
        continue
    fi
    if echo "$line" | grep -q '^## ' && [ "$in_invariants" = true ]; then
        break
    fi
    if [ "$in_invariants" != true ]; then
        continue
    fi

    # 匹配数据行: | N | desc | `cmd` | expected |
    if ! echo "$line" | grep -qE '^\| *[0-9]+ *\|'; then
        continue
    fi

    # 提取 4 个字段
    inv_id=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$2); print $2}')
    inv_desc=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}')
    # 命令字段：去掉反引号
    inv_cmd=$(echo "$line" | awk -F'|' '{print $4}' | sed 's/^ *`\{0,1\}//;s/`\{0,1\} *$//' | sed 's/^ *//;s/ *$//')
    inv_expect=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$5); print $5}')

    if [ -z "$inv_cmd" ] || [ -z "$inv_expect" ]; then
        continue
    fi

    TOTAL=$((TOTAL + 1))

    # 执行检查命令（在项目根目录）
    actual=$(cd "$CLAUDE_PROJECT_DIR" && eval "$inv_cmd" 2>/dev/null | tr -d '[:space:]' || echo "__ERROR__")

    # 解析预期格式并比较
    check_status="PASS"

    if echo "$inv_expect" | grep -q '^= '; then
        expected_val=$(echo "$inv_expect" | sed 's/^= *//')
        [ "$actual" != "$expected_val" ] && check_status="FAIL"

    elif echo "$inv_expect" | grep -q '^≤ '; then
        expected_val=$(echo "$inv_expect" | sed 's/^≤ *//')
        [ "$actual" -gt "$expected_val" ] 2>/dev/null && check_status="FAIL"

    elif echo "$inv_expect" | grep -q '^≥ '; then
        expected_val=$(echo "$inv_expect" | sed 's/^≥ *//')
        [ "$actual" -lt "$expected_val" ] 2>/dev/null && check_status="FAIL"

    elif echo "$inv_expect" | grep -q '^PASS'; then
        (cd "$CLAUDE_PROJECT_DIR" && eval "$inv_cmd" >/dev/null 2>&1) || check_status="FAIL"

    elif echo "$inv_expect" | grep -q '^CONTAINS '; then
        expected_text=$(echo "$inv_expect" | sed 's/^CONTAINS *//')
        full_actual=$(cd "$CLAUDE_PROJECT_DIR" && eval "$inv_cmd" 2>/dev/null || echo "")
        echo "$full_actual" | grep -q "$expected_text" || check_status="FAIL"

    else
        # 尝试精确匹配
        [ "$actual" != "$(echo "$inv_expect" | tr -d '[:space:]')" ] && check_status="FAIL"
    fi

    if [ "$check_status" = "PASS" ]; then
        PASSED=$((PASSED + 1))
    else
        OVERALL="FAIL"
    fi

    # 转义 JSON 特殊字符
    inv_desc_escaped=$(echo "$inv_desc" | sed 's/"/\\"/g')
    actual_escaped=$(echo "$actual" | sed 's/"/\\"/g')

    CHECKS+=("{\"id\":\"$inv_id\",\"desc\":\"$inv_desc_escaped\",\"status\":\"$check_status\",\"expected\":\"$inv_expect\",\"actual\":\"$actual_escaped\"}")

done < "$ANCHOR_PATH"

# 输出 JSON
checks_json=""
if [ ${#CHECKS[@]} -gt 0 ]; then
    checks_json=$(printf '%s,' "${CHECKS[@]}")
    checks_json="${checks_json%,}"  # 去尾逗号
fi

cat <<EOF
{
  "status": "$OVERALL",
  "detail": "$PASSED/$TOTAL invariants passed",
  "checks": [$checks_json]
}
EOF

[ "$OVERALL" = "PASS" ] && exit 0 || exit 1
