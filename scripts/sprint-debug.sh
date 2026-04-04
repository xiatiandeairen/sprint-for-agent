#!/bin/bash
# sprint-debug.sh — Sprint 调试诊断工具
#
# 用法:
#   sprint-debug.sh gate <chunk>    查看 chunk 的 gate 详情
#   sprint-debug.sh journal [N]     最近 N 条 journal 事件（默认 20）
#   sprint-debug.sh diff <chunk>    查看 chunk 变更文件
#   sprint-debug.sh compare <N> <M> 对比两个 chunk 的 gate
#   sprint-debug.sh hooks           Hook 执行记录
#   sprint-debug.sh files           列出所有数据文件

set -euo pipefail
source "$(dirname "$0")/common.sh"

ACTION="${1:?用法: sprint-debug.sh <gate|journal|diff|compare|hooks|files>}"
shift

case "$ACTION" in
    gate)
        CHUNK="${1:?用法: sprint-debug.sh gate <chunk-num>}"
        GATE_FILE="$SPRINT_GATES_DIR/chunk-${CHUNK}.json"
        if [ ! -f "$GATE_FILE" ]; then
            echo "无 chunk $CHUNK 的 gate 快照" >&2; exit 1
        fi
        echo "── Gate: Chunk $CHUNK ──"
        # 逐项展示
        jq -r '.gates[] | "\(.status) \(.id) \(.name)\(if .detail != "" then ": \(.detail)" else "" end)"' "$GATE_FILE" | while IFS= read -r line; do
            case "${line:0:4}" in
                PASS) echo "  ✅ ${line:5}" ;;
                WARN) echo "  ⚠️  ${line:5}" ;;
                FAIL) echo "  ❌ ${line:5}" ;;
                *) echo "  $line" ;;
            esac
        done
        echo ""
        jq '{status, diff_lines, test_count, timestamp}' "$GATE_FILE"
        ;;

    journal)
        N="${1:-20}"
        if [ ! -f "$SPRINT_JOURNAL_FILE" ]; then echo "无 journal"; exit 0; fi
        echo "── 最近 $N 条 ──"
        tail -n "$N" "$SPRINT_JOURNAL_FILE" | jq -r '
            "\(.ts | split("T")[1]) \(.event)" +
            (if .chunk then " chunk=\(.chunk)" else "" end) +
            (if .status then " [\(.status)]" else "" end) +
            (if .gate_status then " gate=\(.gate_status)" else "" end) +
            (if .desc and .desc != "" then " \(.desc)" else "" end) +
            (if .mode then " mode=\(.mode)" else "" end)
        ' 2>/dev/null
        ;;

    diff)
        CHUNK="${1:?用法: sprint-debug.sh diff <chunk-num>}"
        GATE_FILE="$SPRINT_GATES_DIR/chunk-${CHUNK}.json"
        if [ -f "$GATE_FILE" ]; then
            echo "── Chunk $CHUNK 变更 ──"
            jq -r '.changed_files[]' "$GATE_FILE" 2>/dev/null || echo "(无文件列表)"
            echo ""
            diff_lines=$(jq -r '.diff_lines' "$GATE_FILE")
            echo "总变更: $diff_lines 行"
        else
            echo "无 chunk $CHUNK 的数据"
        fi
        PATCH_FILE="$SPRINT_DEBUG_DIR/chunk-${CHUNK}-diff.patch"
        if [ -f "$PATCH_FILE" ]; then
            echo ""
            echo "── Patch ──"
            cat "$PATCH_FILE"
        fi
        ;;

    compare)
        N="${1:?用法: sprint-debug.sh compare <N> <M>}"
        M="${2:?用法: sprint-debug.sh compare <N> <M>}"
        FN="$SPRINT_GATES_DIR/chunk-${N}.json"
        FM="$SPRINT_GATES_DIR/chunk-${M}.json"
        [ ! -f "$FN" ] && echo "无 chunk $N 快照" >&2 && exit 1
        [ ! -f "$FM" ] && echo "无 chunk $M 快照" >&2 && exit 1

        echo "── Chunk $N vs $M ──"
        echo ""
        printf "%-15s %-8s %-8s\n" "Gate" "C$N" "C$M"
        printf "%-15s %-8s %-8s\n" "───────────" "──────" "──────"

        for gid in G1 G2 G3 G4 G5 G6 G7 G8 G9; do
            s1=$(jq -r ".gates[] | select(.id==\"$gid\") | .status" "$FN" 2>/dev/null)
            s2=$(jq -r ".gates[] | select(.id==\"$gid\") | .status" "$FM" 2>/dev/null)
            marker=""
            [ "$s1" != "$s2" ] && marker=" ←"
            printf "%-15s %-8s %-8s%s\n" "$gid" "$s1" "$s2" "$marker"
        done

        echo ""
        d1=$(jq '.diff_lines' "$FN"); d2=$(jq '.diff_lines' "$FM")
        echo "Diff: $d1 → $d2 行"
        ;;

    hooks)
        echo "── Hook 记录 ──"
        if [ -f "/tmp/loppy-sprint.log" ]; then
            tail -20 /tmp/loppy-sprint.log
        else
            echo "(无 hook 日志)"
        fi
        if [ -f "$SPRINT_JOURNAL_FILE" ]; then
            echo ""
            echo "── Journal Hook 事件 ──"
            jq -r 'select(.event | test("hook|post_chunk")) | "\(.ts | split("T")[1]) \(.event) \(.gate_status // "")"' "$SPRINT_JOURNAL_FILE" 2>/dev/null || echo "(无)"
        fi
        ;;

    files)
        echo "── Sprint 数据 ──"
        [ -f "$SPRINT_STATE_FILE" ] && echo "State:   $SPRINT_STATE_FILE"
        if [ -f "$SPRINT_JOURNAL_FILE" ]; then
            c=$(wc -l < "$SPRINT_JOURNAL_FILE" | tr -d ' ')
            echo "Journal: $SPRINT_JOURNAL_FILE ($c 事件)"
        fi
        if [ -d "$SPRINT_GATES_DIR" ]; then
            c=$(find "$SPRINT_GATES_DIR" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
            echo "Gates:   $SPRINT_GATES_DIR/ ($c 快照)"
        fi
        if [ -f "$SPRINT_METRICS_FILE" ] && [ -s "$SPRINT_METRICS_FILE" ]; then
            c=$(wc -l < "$SPRINT_METRICS_FILE" | tr -d ' ')
            echo "Metrics: $SPRINT_METRICS_FILE ($c 条)"
        fi
        if [ -d "$SPRINT_DEBUG_DIR" ]; then
            c=$(find "$SPRINT_DEBUG_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
            echo "Debug:   $SPRINT_DEBUG_DIR/ ($c 文件)"
        fi
        if [ -f "$SPRINT_OBSERVATIONS" ]; then
            obs=$(grep -cE '^\|[^-]' "$SPRINT_OBSERVATIONS" 2>/dev/null || echo 0)
            obs=$((obs > 1 ? obs - 1 : 0))
            echo "Observations: $obs 条"
        fi
        ;;

    *)
        echo "未知: $ACTION" >&2
        echo "用法: sprint-debug.sh <gate|journal|diff|compare|hooks|files>" >&2
        exit 1
        ;;
esac
