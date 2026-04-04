#!/bin/bash
# sprint-ctl.sh — Sprint 生命周期管理
#
# 用法:
#   sprint-ctl.sh init <anchor-path> <chunks-path> [mode]
#   sprint-ctl.sh advance
#   sprint-ctl.sh status
#   sprint-ctl.sh end
#   sprint-ctl.sh set-baseline <key> <value>

set -euo pipefail
source "$(dirname "$0")/common.sh"

ACTION="${1:?用法: sprint-ctl.sh <init|advance|status|end|set-baseline>}"
shift

case "$ACTION" in
    init)
        ANCHOR_PATH="${1:?缺少 anchor-path}"
        CHUNKS_PATH="${2:?缺少 chunks-path}"
        MODE="${3:-checked}"

        mkdir -p "$SPRINT_STATE_DIR"

        # 计算 chunk 总数（匹配 ### Chunk N 格式）
        total_chunks=0
        if [ -f "$CHUNKS_PATH" ]; then
            total_chunks=$(grep -cE '^### Chunk [0-9]+' "$CHUNKS_PATH" 2>/dev/null || echo 0)
        fi

        # 写入状态文件
        cat > "$SPRINT_STATE_FILE" <<SEOF
{
  "active": true,
  "anchor_path": "$ANCHOR_PATH",
  "chunks_path": "$CHUNKS_PATH",
  "mode": "$MODE",
  "current_chunk": 0,
  "total_chunks": $total_chunks,
  "last_gate": {
    "chunk": 0,
    "status": "PASS",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S)"
  },
  "baselines": {}
}
SEOF

        # 初始化观察日志
        cat > "$SPRINT_OBSERVATIONS" <<OEOF
# 观察日志

> Sprint 执行过程中发现的改进机会（不在当前 scope 内）。
> 任务结束后 review 此文件决定哪些值得单独处理。

| 时间 | 文件 | 观察 |
|------|------|------|
OEOF

        # 清空指标文件
        > "$SPRINT_METRICS_FILE"

        echo "✅ Sprint 初始化完成"
        echo "  模式: $MODE"
        echo "  Chunks: $total_chunks"
        echo "  Anchor: $ANCHOR_PATH"
        echo "  State: $SPRINT_STATE_FILE"
        ;;

    advance)
        if ! sprint_is_active; then
            echo "⚠ 无活跃 sprint" >&2
            exit 1
        fi

        current=$(sprint_get 'current_chunk')
        total=$(sprint_get 'total_chunks')
        next=$((current + 1))

        if [ "$next" -gt "$total" ]; then
            echo "✅ 所有 chunk 已完成（$total/$total）"
            exit 0
        fi

        sprint_set 'current_chunk' "$next"
        echo "→ Chunk $next/$total"
        ;;

    status)
        if ! sprint_is_active; then
            echo "无活跃 sprint"
            exit 0
        fi

        current=$(sprint_get 'current_chunk')
        total=$(sprint_get 'total_chunks')
        mode=$(sprint_get 'mode')
        last_status=$(sprint_get 'last_gate.status')
        anchor=$(sprint_get 'anchor_path')

        echo "Sprint [$mode]"
        echo "  进度: Chunk $current/$total"
        echo "  Anchor: $anchor"
        echo "  上次门禁: $last_status"

        # 指标摘要
        if [ -f "$SPRINT_METRICS_FILE" ] && [ -s "$SPRINT_METRICS_FILE" ]; then
            total_diff=$(jq -s '[.[].diff_lines] | add // 0' "$SPRINT_METRICS_FILE")
            avg_diff=$((total_diff / $(wc -l < "$SPRINT_METRICS_FILE" | tr -d ' ')))
            pass_count=$(jq -r '.gate_status' "$SPRINT_METRICS_FILE" | grep -c 'PASS' || echo 0)
            warn_count=$(jq -r '.gate_status' "$SPRINT_METRICS_FILE" | grep -c 'WARN' || echo 0)
            fail_count=$(jq -r '.gate_status' "$SPRINT_METRICS_FILE" | grep -c 'FAIL' || echo 0)
            echo "  累计 diff: ${total_diff} 行（均 ${avg_diff} 行/chunk）"
            echo "  门禁: ${pass_count}P ${warn_count}W ${fail_count}F"
        fi
        ;;

    end)
        if ! sprint_is_active; then
            echo "无活跃 sprint"
            exit 0
        fi

        sprint_set 'active' 'false'
        echo "✅ Sprint 已结束"

        # 最终指标
        if [ -f "$SPRINT_METRICS_FILE" ] && [ -s "$SPRINT_METRICS_FILE" ]; then
            echo ""
            echo "─── 最终指标 ───"
            total_chunks=$(wc -l < "$SPRINT_METRICS_FILE" | tr -d ' ')
            total_diff=$(jq -s '[.[].diff_lines] | add // 0' "$SPRINT_METRICS_FILE")
            echo "  Chunks 完成: $total_chunks"
            echo "  累计 diff: $total_diff 行"
        fi

        # 观察日志统计
        if [ -f "$SPRINT_OBSERVATIONS" ]; then
            obs_count=$(grep -cE '^\|[^-]' "$SPRINT_OBSERVATIONS" 2>/dev/null || echo 0)
            obs_count=$((obs_count > 1 ? obs_count - 1 : 0))  # 减表头
            if [ "$obs_count" -gt 0 ]; then
                echo "  观察日志: $obs_count 条待处理"
            fi
        fi
        ;;

    set-baseline)
        KEY="${1:?缺少 key}"
        VAL="${2:?缺少 value}"

        if ! sprint_is_active; then
            echo "⚠ 无活跃 sprint" >&2
            exit 1
        fi

        sprint_set "baselines.$KEY" "$VAL"
        echo "基线: $KEY = $VAL"
        ;;

    *)
        echo "未知操作: $ACTION" >&2
        echo "用法: sprint-ctl.sh <init|advance|status|end|set-baseline>" >&2
        exit 1
        ;;
esac
