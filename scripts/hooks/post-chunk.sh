#!/bin/bash
# post-chunk.sh — Sprint PostToolUse:Agent 门禁报告
#
# 不在活跃 sprint → 跳过
# 非 implementer agent → 跳过
# implementer 完成 → 跑门禁 + 记录指标 + 输出报告

source "$(dirname "$0")/../common.sh"
hook_start "sprint-post-chunk" ""

if ! sprint_is_active; then
    debug_log "无活跃 sprint，跳过"
    hook_allow
fi

# 只对 implementer agent 跑门禁，reviewer 等跳过
INPUT=$(cat)
AGENT_DESC=$(echo "$INPUT" | jq -r '.description // ""' 2>/dev/null || echo "")
if ! echo "$AGENT_DESC" | grep -qi "implement"; then
    debug_log "非 implementer agent ($AGENT_DESC)，跳过门禁"
    hook_allow
fi
debug_log "implementer agent 检测到，运行门禁"

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
anchor_path=$(sprint_get 'anchor_path')
current_chunk=$(sprint_get 'current_chunk')

# chunk 还没推进（= 0）→ 跳过
if [ "$current_chunk" -eq 0 ]; then
    debug_log "chunk = 0（未开始），跳过门禁"
    hook_allow
fi

debug_log "运行门禁: anchor=$anchor_path chunk=$current_chunk"

# 运行完整门禁
gate_result=$("$SCRIPT_DIR/gate.sh" "$anchor_path" "$current_chunk" 2>/dev/null || echo '{"status":"ERROR","summary":"门禁执行异常","gates":[],"diff_lines":0,"test_count":0}')
gate_status=$(echo "$gate_result" | jq -r '.status // "ERROR"' 2>/dev/null)

debug_log "门禁结果: $gate_status"

# 更新 state.json
sprint_set 'last_gate' "{\"chunk\": $current_chunk, \"status\": \"$gate_status\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S)\"}"
sprint_log_event "post_chunk_gate" "\"chunk\":$current_chunk,\"gate_status\":\"$gate_status\",\"agent_desc\":\"$AGENT_DESC\""
sprint_debug_save "chunk-${current_chunk}-gate-detail.json" "$gate_result"

# 记录指标
"$SCRIPT_DIR/chunk-metrics.sh" record "$current_chunk" "$gate_result" 2>/dev/null || true

# 衰减检测
decay_warning=$("$SCRIPT_DIR/chunk-metrics.sh" --decay-check 2>/dev/null || echo "")

# 构建报告
summary=$(echo "$gate_result" | jq -r '.summary // ""' 2>/dev/null)
gates_detail=""
while IFS= read -r g; do
    [ -z "$g" ] && continue
    gid=$(echo "$g" | jq -r '.id')
    gname=$(echo "$g" | jq -r '.name')
    gstatus=$(echo "$g" | jq -r '.status')
    gdetail=$(echo "$g" | jq -r '.detail // ""')
    icon="✅"
    [ "$gstatus" = "WARN" ] && icon="⚠️"
    [ "$gstatus" = "FAIL" ] && icon="❌"
    gates_detail+="  $icon $gid $gname"
    [ -n "$gdetail" ] && gates_detail+=": $gdetail"
    gates_detail+="\n"
done < <(echo "$gate_result" | jq -c '.gates[]' 2>/dev/null)

# 输出门禁报告到 stderr（给用户看）
echo "" >&2
echo "── Sprint Gate — Chunk $current_chunk ──" >&2
echo "状态: $gate_status | $summary" >&2
if [ -n "$gates_detail" ]; then
    echo -e "$gates_detail" >&2
fi
if [ -n "$decay_warning" ]; then
    echo "质量衰减警告: $decay_warning" >&2
fi
if [ "$gate_status" = "FAIL" ]; then
    echo "⛔ 门禁未通过。修复后运行 /sprint check。下一个 chunk 将被阻塞。" >&2
fi

hook_allow
