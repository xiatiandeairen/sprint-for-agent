#!/bin/bash
# sprint-insight.sh — Sprint 洞察引擎
#
# 用法:
#   sprint-insight.sh health          健康度评分（0-100）
#   sprint-insight.sh anomaly         异常模式检测
#   sprint-insight.sh suggest         基于异常给出建议
#   sprint-insight.sh retro           完整复盘报告

set -euo pipefail
source "$(dirname "$0")/common.sh"

ACTION="${1:-health}"

check_data() {
    if [ ! -f "$SPRINT_JOURNAL_FILE" ] || [ ! -s "$SPRINT_JOURNAL_FILE" ]; then
        echo "无 journal 数据"
        exit 0
    fi
}

# ─── 健康度评分子系统 ───

score_direction() {
    # 方向稳定性：基于 G3 (invariants) 和 G4 (boundaries) 结果
    local score=100
    if [ ! -d "$SPRINT_GATES_DIR" ]; then echo "$score"; return; fi

    local g3_warns=0 g3_fails=0 g4_fails=0
    for f in "$SPRINT_GATES_DIR"/chunk-*.json; do
        [ -f "$f" ] || continue
        local s3=$(jq -r '.gates[] | select(.id=="G3") | .status' "$f" 2>/dev/null)
        local s4=$(jq -r '.gates[] | select(.id=="G4") | .status' "$f" 2>/dev/null)
        [ "$s3" = "WARN" ] && g3_warns=$((g3_warns + 1))
        [ "$s3" = "FAIL" ] && g3_fails=$((g3_fails + 1))
        [ "$s4" = "FAIL" ] && g4_fails=$((g4_fails + 1))
    done
    score=$((score - g3_warns * 10 - g3_fails * 25 - g4_fails * 25))
    [ "$score" -lt 0 ] && score=0
    echo "$score"
}

score_scope() {
    # Scope 控制：基于 G5 (diff budget) 和 G6 (temp code)
    local score=100
    if [ ! -d "$SPRINT_GATES_DIR" ]; then echo "$score"; return; fi

    local g5_warns=0 g5_fails=0 g6_warns=0
    for f in "$SPRINT_GATES_DIR"/chunk-*.json; do
        [ -f "$f" ] || continue
        local s5=$(jq -r '.gates[] | select(.id=="G5") | .status' "$f" 2>/dev/null)
        local s6=$(jq -r '.gates[] | select(.id=="G6") | .status' "$f" 2>/dev/null)
        [ "$s5" = "WARN" ] && g5_warns=$((g5_warns + 1))
        [ "$s5" = "FAIL" ] && g5_fails=$((g5_fails + 1))
        [ "$s6" = "WARN" ] && g6_warns=$((g6_warns + 1))
    done
    score=$((score - g5_warns * 10 - g5_fails * 20 - g6_warns * 5))
    [ "$score" -lt 0 ] && score=0
    echo "$score"
}

score_quality_trend() {
    # 质量趋势：diff 是否递增 + 测试密度是否下降
    local score=100
    if [ ! -f "$SPRINT_METRICS_FILE" ] || [ ! -s "$SPRINT_METRICS_FILE" ]; then
        echo "$score"; return
    fi

    local count=$(wc -l < "$SPRINT_METRICS_FILE" | tr -d ' ')
    if [ "$count" -lt 2 ]; then echo "$score"; return; fi

    # 检查 diff 递增
    local prev=0 increasing=0
    while IFS= read -r line; do
        local curr=$(echo "$line" | jq -r '.diff_lines // 0')
        if [ "$curr" -gt "$prev" ] && [ "$prev" -gt 0 ]; then
            increasing=$((increasing + 1))
        fi
        prev=$curr
    done < "$SPRINT_METRICS_FILE"

    score=$((score - increasing * 15))

    # 检查无测试的 chunk
    local no_test_chunks=$(jq -r 'select(.test_added == 0 and .diff_lines > 20) | .chunk' "$SPRINT_METRICS_FILE" 2>/dev/null | wc -l | tr -d ' ')
    score=$((score - no_test_chunks * 15))

    [ "$score" -lt 0 ] && score=0
    echo "$score"
}

score_efficiency() {
    # 流程效率：非执行阶段占比
    local score=80  # 默认（无阶段数据时）
    # 简化：检查是否有过多返工
    if [ -f "$SPRINT_JOURNAL_FILE" ]; then
        local rework_events=$(grep -c '"gate_result"' "$SPRINT_JOURNAL_FILE" 2>/dev/null || echo 0)
        local chunks=$(sprint_get 'current_chunk' 2>/dev/null || echo 1)
        [ "$chunks" -eq 0 ] && chunks=1
        local rework=$((rework_events - chunks))
        [ "$rework" -lt 0 ] && rework=0
        score=$((score - rework * 10))
    fi
    [ "$score" -lt 0 ] && score=0
    echo "$score"
}

make_bar() {
    local score=$1 width=10
    local filled=$((score * width / 100))
    local empty=$((width - filled))
    printf '%*s' "$filled" '' | tr ' ' '█'
    printf '%*s' "$empty" '' | tr ' ' '░'
}

case "$ACTION" in
    health)
        check_data

        dir_score=$(score_direction)
        scope_score=$(score_scope)
        quality_score=$(score_quality_trend)
        eff_score=$(score_efficiency)

        # 加权总分
        total=$(( (dir_score * 30 + scope_score * 25 + quality_score * 25 + eff_score * 20) / 100 ))

        echo "Sprint Health: $total/100"
        echo ""
        printf "  %-16s %3d/100  %s\n" "方向稳定性" "$dir_score" "$(make_bar $dir_score)"
        printf "  %-16s %3d/100  %s\n" "Scope 控制" "$scope_score" "$(make_bar $scope_score)"
        printf "  %-16s %3d/100  %s\n" "质量趋势" "$quality_score" "$(make_bar $quality_score)"
        printf "  %-16s %3d/100  %s\n" "流程效率" "$eff_score" "$(make_bar $eff_score)"

        # 自动给出建议（如果有低分项）
        echo ""
        suggestions=0
        if [ "$dir_score" -lt 70 ]; then
            echo "  💡 [方向] invariant/boundary 有违反，建议检查 anchor 定义是否需要调整"
            suggestions=$((suggestions + 1))
        fi
        if [ "$scope_score" -lt 70 ]; then
            echo "  💡 [Scope] diff 超预算或临时代码增加，建议检查 chunk 拆分是否合理"
            suggestions=$((suggestions + 1))
        fi
        if [ "$quality_score" -lt 70 ]; then
            echo "  💡 [质量] diff 递增或测试缺失，建议放慢节奏或补充测试"
            suggestions=$((suggestions + 1))
        fi
        if [ "$eff_score" -lt 70 ]; then
            echo "  💡 [效率] 返工较多，建议检查 plan 质量或 chunk 粒度"
            suggestions=$((suggestions + 1))
        fi
        if [ "$suggestions" -eq 0 ]; then
            echo "  ✅ 各维度健康"
        fi
        ;;

    anomaly)
        check_data
        echo "── 异常模式检测 ──"
        echo ""

        anomalies=0

        # 1. 赶进度：diff 连续递增
        if [ -f "$SPRINT_METRICS_FILE" ] && [ "$(wc -l < "$SPRINT_METRICS_FILE" | tr -d ' ')" -ge 3 ]; then
            prev=0; streak=0
            while IFS= read -r line; do
                curr=$(echo "$line" | jq -r '.diff_lines // 0')
                if [ "$curr" -gt "$prev" ] && [ "$prev" -gt 0 ]; then
                    streak=$((streak + 1))
                else
                    streak=0
                fi
                prev=$curr
            done < "$SPRINT_METRICS_FILE"
            if [ "$streak" -ge 2 ]; then
                echo "⚠ [rushing] diff 连续 $((streak + 1)) chunk 递增"
                anomalies=$((anomalies + 1))
            fi
        fi

        # 2. 测试缺失
        if [ -f "$SPRINT_METRICS_FILE" ]; then
            no_test=$(jq -r 'select(.test_added == 0 and .diff_lines > 20)' "$SPRINT_METRICS_FILE" 2>/dev/null | grep -c "chunk" 2>/dev/null || echo 0)
            if [ "$no_test" -gt 0 ]; then
                echo "⚠ [silent_failure] $no_test 个 chunk 有代码变更但无测试新增"
                anomalies=$((anomalies + 1))
            fi
        fi

        # 3. Plan 牢笼：连续 WARN 无 pivot
        if [ -f "$SPRINT_JOURNAL_FILE" ]; then
            warn_streak=0
            has_pivot=$(grep -c '"pivot"' "$SPRINT_JOURNAL_FILE" 2>/dev/null || echo 0)
            while IFS= read -r line; do
                status=$(echo "$line" | jq -r '.status // ""' 2>/dev/null)
                if [ "$status" = "WARN" ]; then
                    warn_streak=$((warn_streak + 1))
                else
                    warn_streak=0
                fi
            done < <(jq -c 'select(.event=="gate_result")' "$SPRINT_JOURNAL_FILE" 2>/dev/null)

            if [ "$warn_streak" -ge 3 ] && [ "$has_pivot" -eq 0 ]; then
                echo "⚠ [plan_prison] 连续 $warn_streak 个 WARN 且无 pivot"
                anomalies=$((anomalies + 1))
            fi
        fi

        # 4. 晚期返工
        if [ -f "$SPRINT_JOURNAL_FILE" ]; then
            total=$(sprint_get 'total_chunks' 2>/dev/null || echo 0)
            if [ "$total" -gt 2 ]; then
                threshold=$(( total * 60 / 100 ))
                late_rework=0
                for i in $(seq $((threshold + 1)) "$total"); do
                    gate_count=$(jq -r "select(.event==\"gate_result\" and .chunk==$i)" "$SPRINT_JOURNAL_FILE" 2>/dev/null | grep -c "gate_result" 2>/dev/null || echo 0)
                    [ "$gate_count" -gt 1 ] && late_rework=$((late_rework + 1))
                done
                if [ "$late_rework" -gt 0 ]; then
                    echo "⚠ [late_rework] 后半段有 $late_rework 个 chunk 返工"
                    anomalies=$((anomalies + 1))
                fi
            fi
        fi

        # 5. Gate 盲区：特定 gate 总是 PASS（可能门禁太松）
        if [ -d "$SPRINT_GATES_DIR" ]; then
            file_count=$(find "$SPRINT_GATES_DIR" -name "chunk-*.json" | wc -l | tr -d ' ')
            if [ "$file_count" -ge 5 ]; then
                for gid in G3 G4 G5 G6 G8; do
                    all_pass=true
                    for f in "$SPRINT_GATES_DIR"/chunk-*.json; do
                        s=$(jq -r ".gates[] | select(.id==\"$gid\") | .status" "$f" 2>/dev/null)
                        [ "$s" != "PASS" ] && all_pass=false && break
                    done
                    if [ "$all_pass" = true ] && [ "$file_count" -ge 5 ]; then
                        echo "ℹ [gate_lax] $gid 在 $file_count 个 chunk 中全 PASS（门禁可能太松）"
                    fi
                done
            fi
        fi

        if [ "$anomalies" -eq 0 ]; then
            echo "✅ 未检测到异常模式"
        else
            echo ""
            echo "共 $anomalies 个异常。运行 sprint-insight.sh suggest 获取建议。"
        fi
        ;;

    suggest)
        check_data
        echo "── 改进建议 ──"
        echo ""

        suggestions=0

        # 基于 anomaly 检测结果给建议
        # 赶进度
        if [ -f "$SPRINT_METRICS_FILE" ] && [ "$(wc -l < "$SPRINT_METRICS_FILE" | tr -d ' ')" -ge 3 ]; then
            prev=0; streak=0; last_diff=0
            while IFS= read -r line; do
                curr=$(echo "$line" | jq -r '.diff_lines // 0')
                if [ "$curr" -gt "$prev" ] && [ "$prev" -gt 0 ]; then
                    streak=$((streak + 1))
                else
                    streak=0
                fi
                prev=$curr
                last_diff=$curr
            done < "$SPRINT_METRICS_FILE"

            if [ "$streak" -ge 2 ]; then
                avg=$(jq -s '[.[].diff_lines] | add / length | floor' "$SPRINT_METRICS_FILE" 2>/dev/null || echo 0)
                echo "1. [rushing] diff 递增: 最近 chunk $last_diff 行, 均值 $avg 行"
                echo "   建议: 将下一个 chunk 拆为 2 个更小的 chunk"
                echo "   验证: 拆分后各 chunk diff < $avg 行"
                echo "   操作: /sprint:pivot"
                echo ""
                suggestions=$((suggestions + 1))
            fi
        fi

        # 测试缺失
        if [ -f "$SPRINT_METRICS_FILE" ]; then
            no_test_chunks=$(jq -r 'select(.test_added == 0 and .diff_lines > 20) | .chunk' "$SPRINT_METRICS_FILE" 2>/dev/null)
            if [ -n "$no_test_chunks" ]; then
                chunk_list=$(echo "$no_test_chunks" | tr '\n' ',' | sed 's/,$//')
                echo "$((suggestions + 1)). [silent_failure] Chunk $chunk_list 有代码变更但无测试"
                echo "   建议: 补充测试或确认变更不需要测试覆盖"
                echo "   验证: /sprint:check 后 G8 为 PASS"
                echo ""
                suggestions=$((suggestions + 1))
            fi
        fi

        # G6 WARN 建议
        if [ -d "$SPRINT_GATES_DIR" ]; then
            g6_warns=0
            for f in "$SPRINT_GATES_DIR"/chunk-*.json; do
                [ -f "$f" ] || continue
                s=$(jq -r '.gates[] | select(.id=="G6") | .status' "$f" 2>/dev/null)
                [ "$s" = "WARN" ] && g6_warns=$((g6_warns + 1))
            done
            if [ "$g6_warns" -gt 0 ]; then
                echo "$((suggestions + 1)). [temp_code] G6 (temp-code) 有 $g6_warns 次 WARN"
                echo "   建议: 检查新增的 TODO/TEMP/HACK 是否必要"
                echo "   → 如果是迁移中间态: 在最后一个 chunk 的完成标准中确保清理"
                echo "   → 如果不必要: 立即删除"
                echo ""
                suggestions=$((suggestions + 1))
            fi
        fi

        if [ "$suggestions" -eq 0 ]; then
            echo "✅ 当前无改进建议"
        fi
        ;;

    retro)
        check_data
        echo "# Sprint Retrospective"
        echo ""

        # 概况
        mode=$(sprint_get 'mode' 2>/dev/null || echo "?")
        current=$(sprint_get 'current_chunk' 2>/dev/null || echo 0)
        total=$(sprint_get 'total_chunks' 2>/dev/null || echo 0)
        total_diff=0
        if [ -f "$SPRINT_METRICS_FILE" ] && [ -s "$SPRINT_METRICS_FILE" ]; then
            total_diff=$(jq -s '[.[].diff_lines] | add // 0' "$SPRINT_METRICS_FILE")
        fi

        echo "## 概况"
        echo "- 模式: $mode | Chunks: $current/$total"
        echo "- 总 diff: $total_diff 行"
        echo ""

        # 健康度
        echo "## 健康度"
        dir_score=$(score_direction)
        scope_score=$(score_scope)
        quality_score=$(score_quality_trend)
        eff_score=$(score_efficiency)
        total_score=$(( (dir_score * 30 + scope_score * 25 + quality_score * 25 + eff_score * 20) / 100 ))
        echo "- 总分: $total_score/100"
        echo "- 方向: $dir_score | Scope: $scope_score | 质量: $quality_score | 效率: $eff_score"
        echo ""

        # Gate 分析
        echo "## 门禁分析"
        if [ -d "$SPRINT_GATES_DIR" ]; then
            total_files=$(find "$SPRINT_GATES_DIR" -name "chunk-*.json" | wc -l | tr -d ' ')
            total_checks=$((total_files * 9))
            total_pass=0
            for f in "$SPRINT_GATES_DIR"/chunk-*.json; do
                [ -f "$f" ] || continue
                p=$(jq '[.gates[] | select(.status=="PASS")] | length' "$f" 2>/dev/null || echo 0)
                total_pass=$((total_pass + p))
            done
            echo "- 通过率: $total_pass/$total_checks ($(( total_pass * 100 / (total_checks > 0 ? total_checks : 1) ))%)"

            # 最脆弱的 gate
            echo "- 最脆弱:"
            for gid in G1 G2 G3 G4 G5 G6 G7 G8 G9; do
                issues=0
                for f in "$SPRINT_GATES_DIR"/chunk-*.json; do
                    [ -f "$f" ] || continue
                    s=$(jq -r ".gates[] | select(.id==\"$gid\") | .status" "$f" 2>/dev/null)
                    [ "$s" != "PASS" ] && issues=$((issues + 1))
                done
                if [ "$issues" -gt 0 ]; then
                    gname=$(jq -r ".gates[] | select(.id==\"$gid\") | .name" "$(find "$SPRINT_GATES_DIR" -name "chunk-*.json" | head -1)" 2>/dev/null || echo "?")
                    echo "  - $gid ($gname): $issues 次非 PASS"
                fi
            done
        fi
        echo ""

        # 异常
        echo "## 异常事件"
        anomaly_output=$("$(dirname "$0")/sprint-insight.sh" anomaly 2>/dev/null | grep "^⚠" || echo "")
        if [ -n "$anomaly_output" ]; then
            echo "$anomaly_output" | while read -r line; do
                echo "- $line"
            done
        else
            echo "- 无异常 ✅"
        fi
        echo ""

        # 建议
        echo "## 闭环沉淀建议"
        suggest_output=$("$(dirname "$0")/sprint-insight.sh" suggest 2>/dev/null | grep -v "^──\|^$\|^✅" || echo "")
        if [ -n "$suggest_output" ]; then
            echo "$suggest_output"
        else
            echo "- 无改进建议"
        fi
        echo ""

        echo "→ 确认后可写入 .sprint/rules.json 供下次 sprint 参考"
        ;;

    *)
        echo "未知操作: $ACTION" >&2
        echo "用法: sprint-insight.sh <health|anomaly|suggest|retro>" >&2
        exit 1
        ;;
esac
