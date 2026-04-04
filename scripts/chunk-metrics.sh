#!/bin/bash
# chunk-metrics.sh — Chunk 指标追踪与衰减检测
#
# 用法:
#   chunk-metrics.sh record <chunk-num> <gate-json>   记录指标
#   chunk-metrics.sh --decay-check                    衰减检测
#   chunk-metrics.sh --summary                        指标摘要

set -euo pipefail
source "$(dirname "$0")/common.sh"

ACTION="${1:---summary}"

case "$ACTION" in
    --decay-check)
        if [ ! -f "$SPRINT_METRICS_FILE" ] || [ ! -s "$SPRINT_METRICS_FILE" ]; then
            exit 0
        fi

        total=$(wc -l < "$SPRINT_METRICS_FILE" | tr -d ' ')
        if [ "$total" -lt 3 ]; then
            exit 0
        fi

        warnings=""

        # 检查 diff 大小连续递增（赶进度信号）
        prev_size=0
        increasing_count=0
        while IFS= read -r line; do
            size=$(echo "$line" | jq -r '.diff_lines // 0')
            if [ "$size" -gt "$prev_size" ] && [ "$prev_size" -gt 0 ]; then
                increasing_count=$((increasing_count + 1))
            else
                increasing_count=0
            fi
            prev_size=$size
        done < <(tail -4 "$SPRINT_METRICS_FILE")

        if [ "$increasing_count" -ge 2 ]; then
            warnings+="⚠ diff 大小连续递增（可能在赶进度）\n"
        fi

        # 检查最近 chunk 有代码变更但无测试新增
        last_entry=$(tail -1 "$SPRINT_METRICS_FILE")
        last_diff=$(echo "$last_entry" | jq -r '.diff_lines // 0')
        last_test_added=$(echo "$last_entry" | jq -r '.test_added // 0')
        if [ "$last_diff" -gt 20 ] && [ "$last_test_added" -eq 0 ]; then
            warnings+="⚠ 最近 chunk 有 $last_diff 行变更但无测试新增\n"
        fi

        # 检查门禁连续 WARN
        warn_streak=0
        while IFS= read -r line; do
            gs=$(echo "$line" | jq -r '.gate_status // ""')
            if [ "$gs" = "WARN" ]; then
                warn_streak=$((warn_streak + 1))
            else
                warn_streak=0
            fi
        done < <(tail -3 "$SPRINT_METRICS_FILE")

        if [ "$warn_streak" -ge 2 ]; then
            warnings+="⚠ 连续 $warn_streak 个 chunk 门禁 WARN\n"
        fi

        if [ -n "$warnings" ]; then
            echo -e "$warnings"
        fi
        ;;

    --summary)
        if [ ! -f "$SPRINT_METRICS_FILE" ] || [ ! -s "$SPRINT_METRICS_FILE" ]; then
            echo "无指标数据"
            exit 0
        fi

        total_chunks=$(wc -l < "$SPRINT_METRICS_FILE" | tr -d ' ')
        total_diff=$(jq -s '[.[].diff_lines] | add // 0' "$SPRINT_METRICS_FILE")
        avg_diff=$((total_diff / total_chunks))
        total_tests=$(jq -s 'last.test_count // 0' "$SPRINT_METRICS_FILE")
        pass_count=$(jq -r '.gate_status' "$SPRINT_METRICS_FILE" | grep -c 'PASS' || echo 0)
        warn_count=$(jq -r '.gate_status' "$SPRINT_METRICS_FILE" | grep -c 'WARN' || echo 0)
        fail_count=$(jq -r '.gate_status' "$SPRINT_METRICS_FILE" | grep -c 'FAIL' || echo 0)

        echo "Chunks: $total_chunks | 总 diff: $total_diff 行 | 均 diff: $avg_diff 行/chunk"
        echo "测试: $total_tests | 门禁: ${pass_count}P ${warn_count}W ${fail_count}F"
        ;;

    record)
        CHUNK_NUM="${2:?用法: chunk-metrics.sh record <chunk-num> <gate-json>}"
        GATE_JSON="${3:-\{\}}"

        mkdir -p "$SPRINT_STATE_DIR"

        diff_lines=$(echo "$GATE_JSON" | jq -r '.diff_lines // 0')
        test_count=$(echo "$GATE_JSON" | jq -r '.test_count // 0')
        gate_status=$(echo "$GATE_JSON" | jq -r '.status // "UNKNOWN"')

        # 计算测试新增数
        prev_test=0
        if [ -f "$SPRINT_METRICS_FILE" ] && [ -s "$SPRINT_METRICS_FILE" ]; then
            prev_test=$(tail -1 "$SPRINT_METRICS_FILE" | jq -r '.test_count // 0')
        fi
        test_added=$((test_count - prev_test))
        [ "$test_added" -lt 0 ] && test_added=0

        # 文件变更数
        files_changed=$(cd "$CLAUDE_PROJECT_DIR" && git diff --name-only HEAD~1 2>/dev/null | wc -l | tr -d ' ')

        echo "{\"chunk\":$CHUNK_NUM,\"diff_lines\":$diff_lines,\"files_changed\":$files_changed,\"test_count\":$test_count,\"test_added\":$test_added,\"gate_status\":\"$gate_status\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S)\"}" >> "$SPRINT_METRICS_FILE"
        ;;

    *)
        echo "未知操作: $ACTION" >&2
        echo "用法: chunk-metrics.sh <record|--decay-check|--summary>" >&2
        exit 1
        ;;
esac
