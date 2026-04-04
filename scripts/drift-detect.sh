#!/bin/bash
# drift-detect.sh — 检测代码变更是否偏离 Anchor 边界
#
# 用法: drift-detect.sh <anchor-path>
# 输出: JSON { drifted, violation_count, violations[] }

set -euo pipefail
source "$(dirname "$0")/common.sh"

ANCHOR_PATH="${1:?用法: drift-detect.sh <anchor-path>}"

declare -a VIOLATIONS=()

# 获取最近一次 commit 的变更文件
changed_files=$(cd "$CLAUDE_PROJECT_DIR" && git diff --name-only HEAD~1 2>/dev/null || echo "")

if [ -z "$changed_files" ]; then
    cat <<EOF
{"drifted":false,"violation_count":0,"violations":[]}
EOF
    exit 0
fi

# 解析 "不触碰的模块/目录" 段落
in_nottouch=false
while IFS= read -r line; do
    # 进入"不触碰"段
    if echo "$line" | grep -q '不触碰'; then
        in_nottouch=true
        continue
    fi
    # 离开段落
    if echo "$line" | grep -qE '^###|^## ' && [ "$in_nottouch" = true ]; then
        in_nottouch=false
        continue
    fi
    if [ "$in_nottouch" != true ]; then
        continue
    fi

    # 提取路径（- path/to/dir/ 格式）
    path=$(echo "$line" | sed -n 's/^- *\([A-Za-z][A-Za-z0-9_/.()-]*\/\).*/\1/p')
    if [ -z "$path" ]; then
        continue
    fi

    # 检查是否有变更文件匹配此路径
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        if echo "$f" | grep -q "^$path\|/$path"; then
            f_escaped=$(echo "$f" | sed 's/"/\\"/g')
            path_escaped=$(echo "$path" | sed 's/"/\\"/g')
            VIOLATIONS+=("{\"type\":\"boundary\",\"file\":\"$f_escaped\",\"forbidden\":\"$path_escaped\"}")
        fi
    done <<< "$changed_files"

done < "$ANCHOR_PATH"

# 输出
drifted=false
[ ${#VIOLATIONS[@]} -gt 0 ] && drifted=true

violations_json=""
if [ ${#VIOLATIONS[@]} -gt 0 ]; then
    violations_json=$(printf '%s,' "${VIOLATIONS[@]}")
    violations_json="${violations_json%,}"
fi

cat <<EOF
{
  "drifted": $drifted,
  "violation_count": ${#VIOLATIONS[@]},
  "violations": [$violations_json]
}
EOF

[ "$drifted" = true ] && exit 1 || exit 0
