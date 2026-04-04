#!/bin/bash
# sprint-metrics.sh — Sprint 度量分析
#
# 用法:
#   sprint-metrics.sh summary     概览
#   sprint-metrics.sh gates       Gate 通过率分析
#   sprint-metrics.sh chunks      Chunk 详情
#   sprint-metrics.sh rework      返工分析

set -euo pipefail
source "$(dirname "$0")/common.sh"

ACTION="${1:-summary}"

case "$ACTION" in
    summary)
        mode=$(sprint_get 'mode' 2>/dev/null || echo "?")
        current=$(sprint_get 'current_chunk' 2>/dev/null || echo 0)
        total=$(sprint_get 'total_chunks' 2>/dev/null || echo 0)
        echo "Sprint [$mode] — $current/$total chunks"
        echo ""

        if [ -f "$SPRINT_METRICS_FILE" ] && [ -s "$SPRINT_METRICS_FILE" ]; then
            printf "%-6s %-7s %-7s %-7s %-7s\n" "Chunk" "Diff" "Tests" "+Test" "Gate"
            printf "%-6s %-7s %-7s %-7s %-7s\n" "─────" "─────" "─────" "─────" "─────"
            while IFS= read -r line; do
                c=$(echo "$line" | jq -r '.chunk')
                d=$(echo "$line" | jq -r '.diff_lines')
                t=$(echo "$line" | jq -r '.test_count')
                ta=$(echo "$line" | jq -r '.test_added')
                g=$(echo "$line" | jq -r '.gate_status')
                printf "%-6s %-7s %-7s %-7s %-7s\n" "$c" "$d" "$t" "+$ta" "$g"
            done < "$SPRINT_METRICS_FILE"
            echo ""
            td=$(jq -s '[.[].diff_lines] | add // 0' "$SPRINT_METRICS_FILE")
            tc=$(wc -l < "$SPRINT_METRICS_FILE" | tr -d ' ')
            avg=$((td / (tc > 0 ? tc : 1)))
            echo "Total: $tc chunks, $td lines (avg $avg/chunk)"
        else
            echo "(无 chunk 数据)"
        fi
        ;;

    gates)
        echo "── Gate 通过率 ──"
        echo ""
        if [ ! -d "$SPRINT_GATES_DIR" ]; then echo "无 gate 数据"; exit 0; fi

        gate_files=$(find "$SPRINT_GATES_DIR" -name "chunk-*.json" 2>/dev/null | sort -V)
        total_files=$(echo "$gate_files" | grep -c "chunk" 2>/dev/null || echo 0)
        [ "$total_files" -eq 0 ] && echo "无 gate 快照" && exit 0

        printf "%-18s %-6s %-6s %-6s\n" "Gate" "PASS" "WARN" "FAIL"
        printf "%-18s %-6s %-6s %-6s\n" "────────────────" "────" "────" "────"

        total_pass_all=0
        for gid in G1 G2 G3 G4 G5 G6 G7 G8 G9; do
            pass=0; warn=0; fail=0
            for f in $gate_files; do
                s=$(jq -r ".gates[] | select(.id==\"$gid\") | .status" "$f" 2>/dev/null)
                case "$s" in
                    PASS) pass=$((pass + 1)) ;;
                    WARN) warn=$((warn + 1)) ;;
                    FAIL) fail=$((fail + 1)) ;;
                esac
            done
            total_pass_all=$((total_pass_all + pass))
            gname=$(jq -r ".gates[] | select(.id==\"$gid\") | .name" "$(echo "$gate_files" | head -1)" 2>/dev/null || echo "?")
            marker=""
            [ "$warn" -gt 0 ] && marker=" ⚠"
            [ "$fail" -gt 0 ] && marker=" ❌"
            printf "%-18s %-6s %-6s %-6s%s\n" "$gid $gname" "$pass" "$warn" "$fail" "$marker"
        done

        total_checks=$((total_files * 9))
        pct=$((total_pass_all * 100 / (total_checks > 0 ? total_checks : 1)))
        echo ""
        echo "通过率: $total_pass_all/$total_checks ($pct%)"
        ;;

    chunks)
        echo "── Chunk 详情 ──"
        echo ""
        if [ ! -f "$SPRINT_METRICS_FILE" ] || [ ! -s "$SPRINT_METRICS_FILE" ]; then
            echo "无数据"; exit 0
        fi

        printf "%-6s %-7s %-7s %-7s %-7s %-6s\n" "Chunk" "Diff" "Tests" "+Test" "Gate" "Files"
        printf "%-6s %-7s %-7s %-7s %-7s %-6s\n" "─────" "─────" "─────" "─────" "─────" "─────"
        while IFS= read -r line; do
            c=$(echo "$line" | jq -r '.chunk')
            d=$(echo "$line" | jq -r '.diff_lines')
            t=$(echo "$line" | jq -r '.test_count')
            ta=$(echo "$line" | jq -r '.test_added')
            g=$(echo "$line" | jq -r '.gate_status')
            fc=$(echo "$line" | jq -r '.files_changed')
            printf "%-6s %-7s %-7s %-7s %-7s %-6s\n" "$c" "$d" "$t" "+$ta" "$g" "$fc"
        done < "$SPRINT_METRICS_FILE"
        ;;

    rework)
        echo "── 返工分析 ──"
        echo ""
        if [ ! -f "$SPRINT_JOURNAL_FILE" ]; then echo "无 journal 数据"; exit 0; fi

        total_chunks=$(sprint_get 'total_chunks' 2>/dev/null || echo 0)
        rework_total=0

        for i in $(seq 1 "$total_chunks"); do
            gate_count=$(jq -c "select(.event==\"gate_result\" and .chunk==$i)" "$SPRINT_JOURNAL_FILE" 2>/dev/null | wc -l | tr -d ' ')
            if [ "$gate_count" -gt 1 ]; then
                rework_total=$((rework_total + gate_count - 1))
                echo "  Chunk $i: $gate_count 次门禁 ($((gate_count - 1)) 次返工)"
                jq -r "select(.event==\"gate_result\" and .chunk==$i) | \"    \(.ts | split(\"T\")[1]) [\(.status)] \(.summary // \"\")\"" "$SPRINT_JOURNAL_FILE" 2>/dev/null
            fi
        done

        if [ "$rework_total" -eq 0 ]; then
            echo "  无返工 ✅"
        else
            echo ""
            rework_rate=$((rework_total * 100 / (total_chunks > 0 ? total_chunks : 1)))
            echo "总返工: $rework_total 次 ($rework_rate%)"
        fi
        ;;

    *)
        echo "未知: $ACTION" >&2
        echo "用法: sprint-metrics.sh <summary|gates|chunks|rework>" >&2
        exit 1
        ;;
esac
