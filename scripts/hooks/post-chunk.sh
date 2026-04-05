#!/bin/bash
# post-chunk.sh -- Sprint PostToolUse:Agent 门禁报告
#
# 不在活跃 sprint -> 跳过
# 非 implementer agent -> 跳过
# implementer 完成 -> 跑门禁 + 记录指标 + 输出报告

source "$(dirname "$0")/../common.sh"
hook_start "sprint-post-chunk" ""

sprint_db_ensure
SID=$(sprint_current_id)

if ! sprint_has_active; then
    debug_log "无活跃 sprint，跳过"
    hook_allow
fi

# 只对 implementer agent 跑门禁
INPUT=$(cat)
AGENT_DESC=$(echo "$INPUT" | jq -r '.description // ""' 2>/dev/null || echo "")
if ! echo "$AGENT_DESC" | grep -qi "implement"; then
    debug_log "非 implementer agent ($AGENT_DESC)，跳过门禁"
    hook_allow
fi
debug_log "implementer agent 检测到，运行门禁"

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
anchor_path=$(sprint_anchor_path "$SID")

# 从 sprint_chunks 获取当前 running 的 chunk
current_chunk=$(sprint_db "SELECT COALESCE(
    (SELECT chunk_num FROM sprint_chunks
     WHERE sprint_id='$SID' AND status='running'
     ORDER BY chunk_num DESC LIMIT 1), 0);")

if [ "$current_chunk" -eq 0 ]; then
    debug_log "无 running chunk，跳过门禁"
    hook_allow
fi

debug_log "运行门禁: anchor=$anchor_path chunk=$current_chunk"

# 运行门禁
gate_result=$("$SCRIPT_DIR/gate.sh" "$anchor_path" "$current_chunk" 2>/dev/null || echo '{"status":"ERROR","summary":"gate error","gates":[],"diff_lines":0,"test_count":0}')
gate_status=$(echo "$gate_result" | jq -r '.status // "ERROR"' 2>/dev/null)

debug_log "门禁结果: $gate_status"

# 记录指标
"$SCRIPT_DIR/chunk-metrics.sh" record "$current_chunk" "$gate_result" 2>/dev/null || true

# 衰减检测
decay_warning=$("$SCRIPT_DIR/chunk-metrics.sh" --decay-check 2>/dev/null || echo "")

# 输出报告
summary=$(echo "$gate_result" | jq -r '.summary // ""' 2>/dev/null)
echo "" >&2
echo "-- Sprint Gate -- Chunk $current_chunk --" >&2
echo "状态: $gate_status | $summary" >&2

while IFS= read -r g; do
    [ -z "$g" ] && continue
    gid=$(echo "$g" | jq -r '.id')
    gname=$(echo "$g" | jq -r '.name')
    gstatus=$(echo "$g" | jq -r '.status')
    gdetail=$(echo "$g" | jq -r '.detail // ""')
    icon="[ok]"
    [ "$gstatus" = "WARN" ] && icon="[WARN]"
    [ "$gstatus" = "FAIL" ] && icon="[FAIL]"
    line="  $icon $gid $gname"
    [ -n "$gdetail" ] && line+=": $gdetail"
    echo "$line" >&2
done < <(echo "$gate_result" | jq -c '.gates[]' 2>/dev/null)

if [ -n "$decay_warning" ]; then
    echo "质量衰减: $decay_warning" >&2
fi
if [ "$gate_status" = "FAIL" ]; then
    echo "[deny] 门禁未通过。修复后运行 /sprint check。" >&2
fi

hook_allow
