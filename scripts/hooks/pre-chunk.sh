#!/bin/bash
# pre-chunk.sh — Sprint PreToolUse:Agent 硬阻塞门禁
#
# 不在活跃 sprint → 放行
# 在 sprint 中 → 检查前置条件，失败 hook_deny 阻塞

source "$(dirname "$0")/../common.sh"
hook_start "sprint-pre-chunk" ""

# ─── 检查 0：是否在活跃 sprint 中 ───
if ! sprint_is_active; then
    debug_log "无活跃 sprint，放行"
    hook_allow
fi

debug_log "活跃 sprint 检测到，执行前置检查"

# ─── 检查 1：上一个 chunk 门禁状态 ───
last_gate_status=$(sprint_get 'last_gate.status')
if [ "$last_gate_status" = "FAIL" ]; then
    hook_deny "上一个 chunk 门禁未通过 (FAIL)。请先修复问题，然后运行 /sprint check"
fi

# ─── 检查 2：Anchor Assumptions 确认状态 ───
anchor_path=$(sprint_get 'anchor_path')
if [ -f "$anchor_path" ]; then
    in_assumptions=false
    unchecked=0
    while IFS= read -r line; do
        if echo "$line" | grep -q '^## Assumptions'; then
            in_assumptions=true
            continue
        fi
        if echo "$line" | grep -q '^## ' && [ "$in_assumptions" = true ]; then
            break
        fi
        if [ "$in_assumptions" = true ] && echo "$line" | grep -q '^\- \[ \]'; then
            unchecked=$((unchecked + 1))
        fi
    done < "$anchor_path"

    if [ "$unchecked" -gt 0 ]; then
        hook_deny "Anchor 有 $unchecked 个未确认假设。请先在 $anchor_path 中确认所有 Assumptions"
    fi
    debug_log "Assumptions 全部已确认"
fi

# ─── 检查 3：Chunk Plan needs-pivot 标记 ───
chunks_path=$(sprint_get 'chunks_path')
if [ -f "$chunks_path" ]; then
    if grep -q 'needs-pivot' "$chunks_path" 2>/dev/null; then
        hook_deny "Chunk Plan 标记了 needs-pivot。请先运行 /sprint pivot 调整计划"
    fi
    debug_log "Chunk Plan 无 needs-pivot 标记"
fi

debug_log "所有前置检查通过"
hook_allow
