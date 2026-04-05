#!/bin/bash
# chunk-metrics.sh -- Chunk 指标追踪与衰减检测
#
# 用法:
#   chunk-metrics.sh record <chunk-num> <gate-json>   记录指标
#   chunk-metrics.sh --decay-check                    衰减检测
#   chunk-metrics.sh --summary                        指标摘要

set -euo pipefail
source "$(dirname "$0")/common.sh"

sprint_db_ensure
SID=$(sprint_current_id)

ACTION="${1:---summary}"

case "$ACTION" in
    --decay-check)
        total=$(sprint_db "SELECT COUNT(*) FROM sprint_chunks WHERE sprint_id='$SID' AND status='completed';")
        if [ "$total" -lt 3 ]; then
            exit 0
        fi

        warnings=""

        # 检查 diff 大小连续递增
        prev_size=0
        increasing_count=0
        while IFS= read -r size; do
            [ -z "$size" ] && continue
            if [ "$size" -gt "$prev_size" ] && [ "$prev_size" -gt 0 ]; then
                increasing_count=$((increasing_count + 1))
            else
                increasing_count=0
            fi
            prev_size=$size
        done < <(sprint_db "SELECT diff_lines FROM sprint_chunks
                            WHERE sprint_id='$SID' AND status='completed'
                            ORDER BY chunk_num DESC LIMIT 4;")

        if [ "$increasing_count" -ge 2 ]; then
            warnings+="[WARN] diff 大小连续递增（可能在赶进度）\n"
        fi

        # 最近 chunk 有变更但无测试新增
        last_row=$(sprint_db -separator '|' \
            "SELECT diff_lines, COALESCE(test_added,0) FROM sprint_chunks
             WHERE sprint_id='$SID' AND status='completed'
             ORDER BY chunk_num DESC LIMIT 1;")
        if [ -n "$last_row" ]; then
            IFS='|' read -r last_diff last_ta <<< "$last_row"
            if [ "${last_diff:-0}" -gt 20 ] && [ "${last_ta:-0}" -eq 0 ]; then
                warnings+="[WARN] 最近 chunk 有 $last_diff 行变更但无测试新增\n"
            fi
        fi

        # 门禁连续 WARN
        warn_streak=0
        while IFS= read -r overall; do
            [ -z "$overall" ] && continue
            if [ "$overall" = "WARN" ]; then
                warn_streak=$((warn_streak + 1))
            else
                warn_streak=0
            fi
        done < <(sprint_db "SELECT g.overall FROM sprint_gates g
                            JOIN sprint_chunks c ON g.sprint_id=c.sprint_id AND g.chunk_num=c.chunk_num
                            WHERE g.sprint_id='$SID' AND c.status='completed'
                            AND g.id = (SELECT MAX(id) FROM sprint_gates
                                        WHERE sprint_id=g.sprint_id AND chunk_num=g.chunk_num)
                            ORDER BY c.chunk_num DESC LIMIT 3;")

        if [ "$warn_streak" -ge 2 ]; then
            warnings+="[WARN] 连续 $warn_streak 个 chunk 门禁 WARN\n"
        fi

        if [ -n "$warnings" ]; then
            echo -e "$warnings"
        fi
        ;;

    --summary)
        total_chunks=$(sprint_db "SELECT COUNT(*) FROM sprint_chunks WHERE sprint_id='$SID' AND status='completed';")
        if [ "$total_chunks" -eq 0 ]; then
            echo "无指标数据"
            exit 0
        fi

        total_diff=$(sprint_db "SELECT COALESCE(SUM(diff_lines),0) FROM sprint_chunks WHERE sprint_id='$SID' AND status='completed';")
        avg_diff=$((total_diff / total_chunks))
        total_tests=$(sprint_db "SELECT COALESCE(MAX(test_count),0) FROM sprint_chunks WHERE sprint_id='$SID';")
        pass_count=$(sprint_db "SELECT COUNT(*) FROM sprint_gates WHERE sprint_id='$SID' AND overall='PASS';")
        warn_count=$(sprint_db "SELECT COUNT(*) FROM sprint_gates WHERE sprint_id='$SID' AND overall='WARN';")
        fail_count=$(sprint_db "SELECT COUNT(*) FROM sprint_gates WHERE sprint_id='$SID' AND overall='FAIL';")

        echo "Chunks: $total_chunks | Diff: $total_diff 行 | Avg: $avg_diff 行/chunk"
        echo "Tests: $total_tests | Gate: ${pass_count}P ${warn_count}W ${fail_count}F"
        ;;

    record)
        CHUNK_NUM="${2:?用法: chunk-metrics.sh record <chunk-num> <gate-json>}"
        GATE_JSON="${3:-\{\}}"

        diff_lines=$(echo "$GATE_JSON" | jq -r '.diff_lines // 0')
        test_count=$(echo "$GATE_JSON" | jq -r '.test_count // 0')

        prev_test=$(sprint_db "SELECT COALESCE(
            (SELECT test_count FROM sprint_chunks
             WHERE sprint_id='$SID' AND chunk_num < $CHUNK_NUM
             ORDER BY chunk_num DESC LIMIT 1), 0);")
        test_added=$((test_count - prev_test))
        [ "$test_added" -lt 0 ] && test_added=0

        files_changed=$(cd "$CLAUDE_PROJECT_DIR" && git diff --name-only HEAD~1 2>/dev/null | wc -l | tr -d ' ')
        commit_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

        sprint_record_chunk "$SID" "$CHUNK_NUM" "$diff_lines" "$files_changed" "$test_count" "$test_added" "$commit_hash"
        ;;

    *)
        echo "未知操作: $ACTION" >&2
        echo "用法: chunk-metrics.sh <record|--decay-check|--summary>" >&2
        exit 1
        ;;
esac
