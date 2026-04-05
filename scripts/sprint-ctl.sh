#!/bin/bash
# sprint-ctl.sh — Sprint 生命周期管理（SQLite）
#
# 用法:
#   sprint-ctl.sh create <id> <type> "<desc>"
#   sprint-ctl.sh activate <id>
#   sprint-ctl.sh end <id>
#   sprint-ctl.sh fail <id> "<reason>"
#   sprint-ctl.sh retry <id>
#   sprint-ctl.sh stop <id>
#   sprint-ctl.sh abandon <id>
#   sprint-ctl.sh archive <id>
#   sprint-ctl.sh list
#   sprint-ctl.sh stage-update <id> <stage> <status>
#   sprint-ctl.sh skip-stage <id> [stage]
#   sprint-ctl.sh log-event <id> <event> "<detail>"
#   sprint-ctl.sh set-baseline <id> <key> <value>
#   sprint-ctl.sh anchor-check <id>
#   sprint-ctl.sh rollback-stage <id>
#   sprint-ctl.sh pivot <id>
#   sprint-ctl.sh verify <id>
#   sprint-ctl.sh init-db

set -euo pipefail
source "$(dirname "$0")/common.sh"

ACTION="${1:?用法: sprint-ctl.sh <command> [args...]}"
shift

# 确保 DB 存在
sprint_db_ensure

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

case "$ACTION" in
    init-db)
        sprint_db_init
        echo "[ok] DB 初始化完成: $SPRINT_DB"
        ;;

    create)
        TYPE="${1:?缺少 type}"
        DESC="${2:?缺少 description}"

        # description 必须是英文（仅允许 ASCII 可打印字符）
        if echo "$DESC" | LC_ALL=C grep -q '[^[:print:]]'; then
            echo "[FAIL] description 必须是英文: $DESC" >&2
            exit 1
        fi

        BASE_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

        # 自动生成 ID: YYYYMMDD-HHmmss-毫秒
        ID=$(date +%Y%m%d-%H%M%S)-$(python3 -c "import time; print(f'{int(time.time()*1000)%1000:03d}')")

        # 生成 dir_name: ID-slug
        DIR_SLUG=$(echo "$DESC" | LC_ALL=C tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | head -c 30 | sed 's/-$//')
        DIR_NAME="${ID}-${DIR_SLUG}"

        sprint_db "INSERT INTO sprints (id, dir_name, description, type, status, base_commit, created_at, updated_at)
                   VALUES ('$ID', '$DIR_NAME', '$DESC', '$TYPE', 'created', '$BASE_COMMIT', '$NOW', '$NOW');"

        # 插入阶段列表（第 3 个参数，逗号分隔的阶段名）
        STAGES="${3:-}"
        if [ -n "$STAGES" ]; then
            SEQ=1
            IFS=',' read -ra STAGE_ARR <<< "$STAGES"
            for STAGE in "${STAGE_ARR[@]}"; do
                STAGE=$(echo "$STAGE" | tr -d ' ')
                sprint_db "INSERT INTO sprint_stages (sprint_id, stage, seq, status)
                           VALUES ('$ID', '$STAGE', $SEQ, 'pending');"
                SEQ=$((SEQ + 1))
            done
        fi

        # 创建工作目录
        mkdir -p "$SPRINT_DIR/active/$DIR_NAME"/{anchors,handoffs,reports,execute,tmp}

        sprint_log_event "$ID" "sprint_created" "{\"type\":\"$TYPE\"}"
        echo "[ok] Sprint #$ID 创建完成"
        echo "  类型: $TYPE"
        echo "  目录: .sprint/active/$DIR_NAME"
        echo "  base_commit: $BASE_COMMIT"
        echo "  id: $ID"
        ;;

    activate)
        ID="${1:?缺少 id}"
        STATUS=$(sprint_field "$ID" "status")

        if [ "$STATUS" != "created" ] && [ "$STATUS" != "retrying" ] && [ "$STATUS" != "stopped" ]; then
            echo "[FAIL] Sprint #$ID status=$STATUS,无法激活" >&2
            exit 1
        fi

        sprint_db "UPDATE sprints SET status='running', updated_at='$NOW' WHERE id='$ID';"
        sprint_log_event "$ID" "sprint_activated" "{\"from\":\"$STATUS\"}"
        echo "[ok] Sprint #$ID -> running"
        ;;

    end)
        ID="${1:?缺少 id}"
        STATUS=$(sprint_field "$ID" "status")

        if [ "$STATUS" != "running" ]; then
            echo "[FAIL] Sprint #$ID status=$STATUS,无法结束" >&2
            exit 1
        fi

        sprint_db "UPDATE sprints SET status='completed', updated_at='$NOW' WHERE id='$ID';"

        # 输出指标
        COMPLETED=$(sprint_db "SELECT COUNT(*) FROM sprint_stages WHERE sprint_id='$ID' AND status='completed';")
        SKIPPED=$(sprint_db "SELECT COUNT(*) FROM sprint_stages WHERE sprint_id='$ID' AND status='skipped';")
        TOTAL=$(sprint_db "SELECT COUNT(*) FROM sprint_stages WHERE sprint_id='$ID';")

        sprint_log_event "$ID" "sprint_ended" "{\"stages_completed\":$COMPLETED}"
        echo "[ok] Sprint #$ID 完成"
        echo "  阶段: $COMPLETED/$TOTAL 完成, $SKIPPED 跳过"
        ;;

    status)
        ID="${1:?缺少 id}"

        # 基本信息
        ROW=$(sprint_db -separator '|' \
            "SELECT description, type, status, created_at, base_commit FROM sprints WHERE id='$ID';")
        if [ -z "$ROW" ]; then
            echo "[FAIL] Sprint #$ID 不存在" >&2
            exit 1
        fi

        IFS='|' read -r DESC TYPE STATUS CREATED BASE <<< "$ROW"
        echo "Sprint #$ID"
        echo "  描述: $DESC"
        echo "  类型: $TYPE"
        echo "  状态: $STATUS"
        echo "  创建: $CREATED"
        echo "  base: ${BASE:0:7}"

        # 阶段进度
        STAGES=$(sprint_db -separator '|' \
            "SELECT seq, stage, status, started_at, completed_at
             FROM sprint_stages WHERE sprint_id='$ID' ORDER BY seq;")

        if [ -n "$STAGES" ]; then
            echo ""
            echo "  阶段:"
            while IFS='|' read -r seq stage st started completed; do
                case "$st" in
                    completed)
                        s_start=$(echo "$started" | cut -c1-16)
                        s_end=$(echo "$completed" | cut -c1-16)
                        printf "    %d. %-12s [completed]  %s -> %s\n" "$seq" "$stage" "$s_start" "$s_end"
                        ;;
                    running)
                        s_start=$(echo "$started" | cut -c1-16)
                        printf "    %d. %-12s [running]    %s ->\n" "$seq" "$stage" "$s_start"
                        ;;
                    skipped)
                        printf "    %d. %-12s [skipped]\n" "$seq" "$stage"
                        ;;
                    *)
                        printf "    %d. %-12s [pending]\n" "$seq" "$stage"
                        ;;
                esac
            done <<< "$STAGES"
        fi

        # 错误信息
        ERR=$(sprint_db -separator '|' \
            "SELECT stage, message, retry_count, occurred_at
             FROM sprint_errors WHERE sprint_id='$ID' ORDER BY occurred_at DESC LIMIT 1;")

        echo ""
        if [ -n "$ERR" ]; then
            IFS='|' read -r e_stage e_msg e_retry e_time <<< "$ERR"
            echo "  错误:"
            echo "    阶段: $e_stage"
            echo "    原因: $e_msg"
            echo "    重试: $e_retry 次"
            echo "    时间: $e_time"
        else
            echo "  错误: (无)"
        fi
        ;;

    list)
        # 停止检测: running 超 30 分钟自动标记 stopped
        sprint_db "UPDATE sprints SET status='stopped', updated_at='$NOW'
                   WHERE status='running'
                   AND strftime('%s', '$NOW') - strftime('%s', updated_at) > 1800;"

        # ANSI 颜色
        C_RED='\033[0;31m'
        C_YEL='\033[0;33m'
        C_GRN='\033[0;32m'
        C_RST='\033[0m'

        # 按状态排序: running -> retrying -> created -> stopped -> failed
        ROWS=$(sprint_db -separator '|' \
            "SELECT id, type, status, description,
                    COALESCE((SELECT stage FROM sprint_stages WHERE sprint_id=sprints.id AND status='running' LIMIT 1),
                             (SELECT stage FROM sprint_stages WHERE sprint_id=sprints.id AND status='pending' ORDER BY seq LIMIT 1),
                             'done') as current_stage
             FROM sprints
             WHERE status NOT IN ('completed', 'archived')
             ORDER BY
                 CASE status
                     WHEN 'running' THEN 1
                     WHEN 'retrying' THEN 2
                     WHEN 'created' THEN 3
                     WHEN 'stopped' THEN 4
                     WHEN 'failed' THEN 5
                 END,
                 created_at DESC;")

        if [ -z "$ROWS" ]; then
            echo "无活跃 sprint"
            exit 0
        fi

        echo "Sprint 列表:"
        echo ""
        PREV_GROUP=""
        while IFS='|' read -r id type status desc stage; do
            # 分组标签
            case "$status" in
                running|retrying) GROUP="running" ;;
                stopped)          GROUP="stopped" ;;
                failed)           GROUP="failed" ;;
                *)                GROUP="other" ;;
            esac
            if [ "$GROUP" != "$PREV_GROUP" ]; then
                [ -n "$PREV_GROUP" ] && echo ""
                PREV_GROUP="$GROUP"
            fi

            # 状态着色
            case "$status" in
                running|retrying) color="$C_GRN" ;;
                stopped)          color="$C_YEL" ;;
                failed)           color="$C_RED" ;;
                *)                color="" ;;
            esac

            printf "  #%-16s  %-7s  %b%-8s%b  %-20s  -> %s\n" \
                "$id" "$type" "$color" "$status" "$C_RST" "$desc" "$stage"
        done <<< "$ROWS"
        ;;

    fail)
        ID="${1:?缺少 id}"
        REASON="${2:?缺少 reason}"
        STATUS=$(sprint_field "$ID" "status")

        if [ "$STATUS" != "running" ] && [ "$STATUS" != "retrying" ]; then
            echo "[FAIL] Sprint #$ID status=$STATUS,无法标记失败" >&2
            exit 1
        fi

        STAGE=$(sprint_db "SELECT stage FROM sprint_stages WHERE sprint_id='$ID' AND status='running' LIMIT 1;")
        RETRY_COUNT=$(sprint_db "SELECT COALESCE(MAX(retry_count),0) FROM sprint_errors WHERE sprint_id='$ID' AND stage='$STAGE';")

        sprint_db "UPDATE sprints SET status='failed', updated_at='$NOW' WHERE id='$ID';"
        sprint_db "UPDATE sprint_stages SET status='failed' WHERE sprint_id='$ID' AND stage='$STAGE';"
        sprint_db "INSERT INTO sprint_errors (sprint_id, stage, message, retry_count, occurred_at)
                   VALUES ('$ID', '$STAGE', '$REASON', $((RETRY_COUNT + 1)), '$NOW');"

        sprint_log_event "$ID" "sprint_failed" "{\"stage\":\"$STAGE\",\"reason\":\"$REASON\"}"
        echo "[FAIL] Sprint #$ID 失败"
        echo "  阶段: $STAGE"
        echo "  原因: $REASON"
        echo "  重试次数: $((RETRY_COUNT + 1))"
        ;;

    retry)
        ID="${1:?缺少 id}"
        STATUS=$(sprint_field "$ID" "status")

        if [ "$STATUS" != "failed" ]; then
            echo "[FAIL] Sprint #$ID status=$STATUS,无法重试" >&2
            exit 1
        fi

        # 恢复失败阶段为 pending
        sprint_db "UPDATE sprint_stages SET status='pending', started_at=NULL, completed_at=NULL
                   WHERE sprint_id='$ID' AND status='failed';"
        sprint_db "UPDATE sprints SET status='retrying', updated_at='$NOW' WHERE id='$ID';"

        sprint_log_event "$ID" "sprint_retrying" ""
        echo "[ok] Sprint #$ID -> retrying"
        ;;

    stop)
        ID="${1:?缺少 id}"
        sprint_db "UPDATE sprints SET status='stopped', updated_at='$NOW' WHERE id='$ID';"
        sprint_log_event "$ID" "sprint_stopped" ""
        echo "[ok] Sprint #$ID -> stopped"
        ;;

    abandon)
        ID="${1:?缺少 id}"
        STATUS=$(sprint_field "$ID" "status")
        BASE_COMMIT=$(sprint_field "$ID" "base_commit")

        if [ "$STATUS" != "failed" ] && [ "$STATUS" != "stopped" ]; then
            echo "[FAIL] Sprint #$ID status=$STATUS,无法放弃（需要先 fail 或 stop）" >&2
            exit 1
        fi

        # revert 到 base_commit
        if [ -n "$BASE_COMMIT" ] && [ "$BASE_COMMIT" != "unknown" ]; then
            CURRENT=$(git rev-parse HEAD 2>/dev/null || echo "")
            if [ "$CURRENT" != "$BASE_COMMIT" ]; then
                echo "  revert 到 $BASE_COMMIT ..."
                git revert --no-commit "$BASE_COMMIT..HEAD" 2>/dev/null || true
                git commit -m "revert: abandon sprint #$ID" 2>/dev/null || true
            fi
        fi

        sprint_db "UPDATE sprints SET status='archived', updated_at='$NOW' WHERE id='$ID';"

        # 移动目录到 archive
        DIR_NAME=$(sprint_field "$ID" "dir_name")
        if [ -d "$SPRINT_DIR/active/$DIR_NAME" ]; then
            mkdir -p "$SPRINT_DIR/archive"
            mv "$SPRINT_DIR/active/$DIR_NAME" "$SPRINT_DIR/archive/" 2>/dev/null || true
        fi

        sprint_log_event "$ID" "sprint_abandoned" ""
        echo "[ok] Sprint #$ID 已放弃并归档"
        ;;

    archive)
        ID="${1:?缺少 id}"
        STATUS=$(sprint_field "$ID" "status")

        if [ "$STATUS" != "completed" ]; then
            echo "[FAIL] Sprint #$ID status=$STATUS,只有 completed 可归档" >&2
            exit 1
        fi

        sprint_db "UPDATE sprints SET status='archived', updated_at='$NOW' WHERE id='$ID';"

        DIR_NAME=$(sprint_field "$ID" "dir_name")
        if [ -d "$SPRINT_DIR/active/$DIR_NAME" ]; then
            mkdir -p "$SPRINT_DIR/archive"
            mv "$SPRINT_DIR/active/$DIR_NAME" "$SPRINT_DIR/archive/" 2>/dev/null || true
        fi

        sprint_log_event "$ID" "sprint_archived" ""
        echo "[ok] Sprint #$ID 已归档"
        ;;

    stage-update)
        ID="${1:?缺少 id}"
        STAGE="${2:?缺少 stage}"
        NEW_STATUS="${3:?缺少 status}"

        case "$NEW_STATUS" in
            running)
                sprint_db "UPDATE sprint_stages SET status='running', started_at='$NOW' WHERE sprint_id='$ID' AND stage='$STAGE';"
                ;;
            completed)
                sprint_db "UPDATE sprint_stages SET status='completed', completed_at='$NOW' WHERE sprint_id='$ID' AND stage='$STAGE';"
                ;;
            failed)
                sprint_db "UPDATE sprint_stages SET status='failed' WHERE sprint_id='$ID' AND stage='$STAGE';"
                ;;
            *)
                sprint_db "UPDATE sprint_stages SET status='$NEW_STATUS' WHERE sprint_id='$ID' AND stage='$STAGE';"
                ;;
        esac

        sprint_db "UPDATE sprints SET updated_at='$NOW' WHERE id='$ID';"
        sprint_log_event "$ID" "stage_update" "{\"stage\":\"$STAGE\",\"status\":\"$NEW_STATUS\"}"
        echo "[ok] Sprint #$ID $STAGE -> $NEW_STATUS"
        ;;

    skip-stage)
        ID="${1:?缺少 id}"
        TARGET_STAGE="${2:-}"

        if [ -n "$TARGET_STAGE" ]; then
            STAGE="$TARGET_STAGE"
        else
            # 无指定则跳过当前 running 或第一个 pending 阶段
            STAGE=$(sprint_db "SELECT stage FROM sprint_stages
                WHERE sprint_id='$ID' AND status IN ('running','pending')
                ORDER BY CASE status WHEN 'running' THEN 1 ELSE 2 END, seq LIMIT 1;")
        fi

        if [ -z "$STAGE" ]; then
            echo "[WARN] 无可跳过的阶段" >&2
            exit 1
        fi

        sprint_db "UPDATE sprint_stages SET status='skipped' WHERE sprint_id='$ID' AND stage='$STAGE';"
        sprint_db "UPDATE sprints SET updated_at='$NOW' WHERE id='$ID';"
        sprint_log_event "$ID" "stage_skipped" "{\"stage\":\"$STAGE\"}"
        echo "[ok] Sprint #$ID $STAGE -> skipped"
        ;;

    log-event)
        ID="${1:?缺少 id}"
        EVENT="${2:?缺少 event}"
        DETAIL="${3:-}"

        sprint_db "INSERT INTO sprint_events (sprint_id, event, detail, ts)
                   VALUES ('$ID', '$EVENT', '$DETAIL', '$NOW');"
        ;;

    set-baseline)
        ID="${1:?缺少 id}"
        KEY="${2:?缺少 key}"
        VAL="${3:?缺少 value}"

        sprint_set_baseline "$ID" "$KEY" "$VAL"
        echo "基线: $KEY = $VAL"
        ;;

    anchor-check)
        ID="${1:?缺少 id}"
        ANCHOR=$(sprint_anchor_path "$ID")

        if [ ! -f "$ANCHOR" ]; then
            echo "[ok] 无 anchor 文件，跳过"
            exit 0
        fi

        # 检查 invariants
        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
        verify_output=$("$SCRIPT_DIR/anchor-verify.sh" "$ANCHOR" 2>/dev/null || true)
        verify_status=$(echo "$verify_output" | jq -r '.status // "ERROR"' 2>/dev/null)

        if [ "$verify_status" = "FAIL" ]; then
            verify_detail=$(echo "$verify_output" | jq -r '.detail // ""' 2>/dev/null)
            echo "[FAIL] Anchor 不变量违反: $verify_detail"
            exit 1
        fi

        # 检查 boundary drift
        drift_output=$("$SCRIPT_DIR/drift-detect.sh" "$ANCHOR" 2>/dev/null || true)
        drifted=$(echo "$drift_output" | jq -r '.drifted // false' 2>/dev/null)

        if [ "$drifted" = "true" ]; then
            v_count=$(echo "$drift_output" | jq -r '.violation_count // 0' 2>/dev/null)
            echo "[FAIL] Boundary drift 检测到 $v_count 个违反"
            exit 1
        fi

        echo "[ok] Anchor 检查通过"
        ;;

    rollback-stage)
        ID="${1:?缺少 id}"

        # 找当前阶段和上一阶段
        CURRENT=$(sprint_db "SELECT stage FROM sprint_stages
            WHERE sprint_id='$ID' AND status IN ('running','failed')
            ORDER BY seq DESC LIMIT 1;")
        PREV=$(sprint_db "SELECT stage FROM sprint_stages
            WHERE sprint_id='$ID' AND status='completed'
            ORDER BY seq DESC LIMIT 1;")

        if [ -z "$PREV" ]; then
            echo "[FAIL] 无可回退的阶段" >&2
            exit 1
        fi

        # 当前阶段 -> pending，上一阶段 -> pending
        sprint_db "UPDATE sprint_stages SET status='pending', started_at=NULL, completed_at=NULL
                   WHERE sprint_id='$ID' AND stage='$CURRENT';"
        sprint_db "UPDATE sprint_stages SET status='pending', started_at=NULL, completed_at=NULL
                   WHERE sprint_id='$ID' AND stage='$PREV';"
        sprint_db "UPDATE sprints SET updated_at='$NOW' WHERE id='$ID';"

        sprint_log_event "$ID" "stage_rollback" "{\"from\":\"$CURRENT\",\"to\":\"$PREV\"}"
        echo "[ok] 回退: $CURRENT -> $PREV (两个阶段重置为 pending)"
        ;;

    pivot)
        ID="${1:?缺少 id}"

        # 标记当前阶段为 pending（重做）
        CURRENT=$(sprint_db "SELECT stage FROM sprint_stages
            WHERE sprint_id='$ID' AND status IN ('running','failed')
            ORDER BY seq DESC LIMIT 1;")

        if [ -n "$CURRENT" ]; then
            sprint_db "UPDATE sprint_stages SET status='pending', started_at=NULL
                       WHERE sprint_id='$ID' AND stage='$CURRENT';"
        fi

        sprint_db "UPDATE sprints SET updated_at='$NOW' WHERE id='$ID';"
        sprint_log_event "$ID" "pivot" "{\"stage\":\"$CURRENT\"}"
        echo "[ok] Pivot: $CURRENT 重置，请更新 anchor/chunks 后继续"
        ;;

    verify)
        ID="${1:?缺少 id}"
        PASS_COUNT=0
        FAIL_COUNT=0
        TOTAL=5

        STATUS=$(sprint_field "$ID" "status")
        WORK_DIR=$(sprint_work_dir "$ID")

        # 1. state 一致性
        case "$STATUS" in
            running|retrying)
                HAS_ACTIVE=$(sprint_db "SELECT COUNT(*) FROM sprint_stages
                    WHERE sprint_id='$ID' AND status IN ('running','pending');")
                if [ "$HAS_ACTIVE" -gt 0 ]; then
                    echo "  [ok] state 一致性: $STATUS + $HAS_ACTIVE 个活跃阶段"
                    PASS_COUNT=$((PASS_COUNT + 1))
                else
                    echo "  [FAIL] state 一致性: status=$STATUS 但无活跃阶段"
                    FAIL_COUNT=$((FAIL_COUNT + 1))
                fi
                ;;
            completed)
                INCOMPLETE=$(sprint_db "SELECT COUNT(*) FROM sprint_stages
                    WHERE sprint_id='$ID' AND status NOT IN ('completed','skipped');")
                if [ "$INCOMPLETE" -eq 0 ]; then
                    echo "  [ok] state 一致性: completed + 所有阶段完成/跳过"
                    PASS_COUNT=$((PASS_COUNT + 1))
                else
                    echo "  [FAIL] state 一致性: status=completed 但 $INCOMPLETE 个阶段未完成"
                    FAIL_COUNT=$((FAIL_COUNT + 1))
                fi
                ;;
            failed)
                HAS_FAILED=$(sprint_db "SELECT COUNT(*) FROM sprint_stages
                    WHERE sprint_id='$ID' AND status='failed';")
                if [ "$HAS_FAILED" -gt 0 ]; then
                    echo "  [ok] state 一致性: failed + $HAS_FAILED 个失败阶段"
                    PASS_COUNT=$((PASS_COUNT + 1))
                else
                    echo "  [FAIL] state 一致性: status=failed 但无失败阶段"
                    FAIL_COUNT=$((FAIL_COUNT + 1))
                fi
                ;;
            *)
                echo "  [ok] state 一致性: $STATUS"
                PASS_COUNT=$((PASS_COUNT + 1))
                ;;
        esac

        # 2. 文件完整性
        FILE_OK=true
        FILE_ISSUES=""
        COMPLETED_STAGES=$(sprint_db "SELECT stage FROM sprint_stages
            WHERE sprint_id='$ID' AND status='completed';")
        for STAGE in $COMPLETED_STAGES; do
            # 每个 completed 阶段检查 handoffs 文件存在
            case "$STAGE" in
                brainstorm) [ ! -f "$WORK_DIR/handoffs/brainstorm.md" ] && FILE_OK=false && FILE_ISSUES+=" handoffs/brainstorm.md" ;;
                research)   [ ! -f "$WORK_DIR/handoffs/research.md" ] && FILE_OK=false && FILE_ISSUES+=" handoffs/research.md" ;;
                design)     [ ! -f "$WORK_DIR/handoffs/design.md" ] && FILE_OK=false && FILE_ISSUES+=" handoffs/design.md" ;;
                plan)       [ ! -f "$WORK_DIR/anchors/plan.md" ] && FILE_OK=false && FILE_ISSUES+=" anchors/plan.md"
                            [ ! -f "$WORK_DIR/handoffs/plan-chunks.md" ] && FILE_OK=false && FILE_ISSUES+=" handoffs/plan-chunks.md" ;;
            esac
        done
        if [ "$FILE_OK" = true ]; then
            echo "  [ok] 文件完整性"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            echo "  [FAIL] 文件完整性: 缺失$FILE_ISSUES"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi

        # 3. gate 一致性
        GATE_BAD=$(sprint_db "SELECT COUNT(*) FROM sprint_chunks c
            JOIN sprint_gates g ON c.sprint_id=g.sprint_id AND c.chunk_num=g.chunk_num
            WHERE c.sprint_id='$ID' AND c.status='completed'
            AND g.id = (SELECT MAX(id) FROM sprint_gates
                        WHERE sprint_id=c.sprint_id AND chunk_num=c.chunk_num)
            AND g.overall='FAIL';")
        if [ "${GATE_BAD:-0}" -eq 0 ]; then
            echo "  [ok] gate 一致性"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            echo "  [FAIL] gate 一致性: $GATE_BAD 个 completed chunk 最终 gate 为 FAIL"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi

        # 4. 阶段连续性
        GAP=$(sprint_db "SELECT COUNT(*) FROM sprint_stages s1
            JOIN sprint_stages s2 ON s1.sprint_id=s2.sprint_id AND s1.seq=s2.seq-1
            WHERE s1.sprint_id='$ID'
            AND s1.status NOT IN ('completed','skipped')
            AND s2.status='completed';")
        if [ "${GAP:-0}" -eq 0 ]; then
            echo "  [ok] 阶段连续性"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            echo "  [FAIL] 阶段连续性: 有后续阶段 completed 但前置阶段未完成"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi

        # 5. chunk 计数（只在 execute 阶段开始后检查）
        EXEC_STATUS=$(sprint_db "SELECT COALESCE(
            (SELECT status FROM sprint_stages WHERE sprint_id='$ID' AND stage='execute'), 'none');")
        if [ "$EXEC_STATUS" = "none" ] || [ "$EXEC_STATUS" = "pending" ]; then
            echo "  [ok] chunk 计数: execute 未开始，跳过"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            DB_CHUNKS=$(sprint_db "SELECT COUNT(*) FROM sprint_chunks WHERE sprint_id='$ID';")
            if [ -f "$WORK_DIR/plan/chunks.md" ]; then
                FILE_CHUNKS=$(grep -cE '^### Chunk' "$WORK_DIR/plan/chunks.md" 2>/dev/null || echo 0)
                if [ "$DB_CHUNKS" -eq "$FILE_CHUNKS" ]; then
                    echo "  [ok] chunk 计数: $DB_CHUNKS"
                    PASS_COUNT=$((PASS_COUNT + 1))
                else
                    echo "  [FAIL] chunk 计数: DB=$DB_CHUNKS, 文件=$FILE_CHUNKS"
                    FAIL_COUNT=$((FAIL_COUNT + 1))
                fi
            else
                echo "  [ok] chunk 计数: $DB_CHUNKS (无 chunks.md)"
                PASS_COUNT=$((PASS_COUNT + 1))
            fi
        fi

        # 汇总
        echo ""
        if [ "$FAIL_COUNT" -eq 0 ]; then
            echo "[ok] Sprint #$ID 验证通过($PASS_COUNT/$TOTAL)"
        else
            echo "[FAIL] Sprint #$ID 验证失败($PASS_COUNT/$TOTAL)"
            exit 1
        fi
        ;;

    # ═══════════════════════════════════
    # Long Task 命令组
    # ═══════════════════════════════════

    long-goal)
        ID="${1:?缺少 sprint id}"
        SUB="${2:?缺少子命令 (add|achieve|list|drop)}"
        shift 2

        case "$SUB" in
            add)
                DESC="${1:?缺少目标描述}"
                VERIFY="${2:?缺少验证方式}"
                SEQ=$(sprint_db "SELECT COALESCE(MAX(seq),0)+1 FROM long_task_goals WHERE sprint_id='$ID';")
                sprint_db "INSERT INTO long_task_goals (sprint_id, seq, description, verifiable, status)
                           VALUES ('$ID', $SEQ, '$DESC', '$VERIFY', 'pending');"
                echo "[ok] 目标 #$SEQ: $DESC"
                ;;
            achieve)
                GOAL_SEQ="${1:?缺少目标序号}"
                CHILD_ID="${2:-}"
                sprint_db "UPDATE long_task_goals SET status='achieved', achieved_by='$CHILD_ID',
                           updated_at='$NOW' WHERE sprint_id='$ID' AND seq=$GOAL_SEQ;"
                echo "[ok] 目标 #$GOAL_SEQ -> achieved"
                ;;
            drop)
                GOAL_SEQ="${1:?缺少目标序号}"
                sprint_db "UPDATE long_task_goals SET status='dropped',
                           updated_at='$NOW' WHERE sprint_id='$ID' AND seq=$GOAL_SEQ;"
                echo "[ok] 目标 #$GOAL_SEQ -> dropped"
                ;;
            list)
                echo "目标清单 (Sprint #$ID):"
                sprint_db "SELECT seq, status, description FROM long_task_goals
                           WHERE sprint_id='$ID' ORDER BY seq;" | while IFS='|' read -r seq status desc; do
                    case "$status" in
                        achieved) mark="[x]" ;;
                        dropped)  mark="[-]" ;;
                        *)        mark="[ ]" ;;
                    esac
                    echo "  $mark #$seq: $desc"
                done
                TOTAL=$(sprint_db "SELECT COUNT(*) FROM long_task_goals WHERE sprint_id='$ID';")
                DONE=$(sprint_db "SELECT COUNT(*) FROM long_task_goals WHERE sprint_id='$ID' AND status='achieved';")
                echo "  ($DONE/$TOTAL achieved)"
                ;;
            *)
                echo "未知子命令: $SUB (add|achieve|list|drop)" >&2
                exit 1
                ;;
        esac
        ;;

    long-round)
        ID="${1:?缺少 sprint id}"
        SUB="${2:?缺少子命令 (start|end)}"
        shift 2

        case "$SUB" in
            start)
                CHILD_ID="${1:?缺少子 sprint id}"
                EST_COST="${2:?缺少预估成本}"
                ROUND_NUM=$(sprint_db "SELECT COALESCE(MAX(round_num),0)+1 FROM long_task_rounds WHERE parent_id='$ID';")
                GOALS_BEFORE=$(sprint_db "SELECT COUNT(*) FROM long_task_goals WHERE sprint_id='$ID' AND status='achieved';")
                sprint_db "INSERT INTO long_task_rounds (parent_id, child_id, round_num, cost_estimated, goals_before)
                           VALUES ('$ID', '$CHILD_ID', $ROUND_NUM, $EST_COST, $GOALS_BEFORE);"
                echo "[ok] 轮次 #$ROUND_NUM 开始 (子 sprint: $CHILD_ID, 预估: ${EST_COST} 行)"
                ;;
            end)
                CHILD_ID="${1:?缺少子 sprint id}"
                ACTUAL_COST="${2:?缺少实际成本}"
                GOALS_AFTER=$(sprint_db "SELECT COUNT(*) FROM long_task_goals WHERE sprint_id='$ID' AND status='achieved';")
                ROUND_NUM=$(sprint_db "SELECT round_num FROM long_task_rounds WHERE parent_id='$ID' AND child_id='$CHILD_ID';")
                GOALS_BEFORE=$(sprint_db "SELECT goals_before FROM long_task_rounds WHERE parent_id='$ID' AND child_id='$CHILD_ID';")
                GOAL_DELTA=$((GOALS_AFTER - GOALS_BEFORE))
                if [ "$ACTUAL_COST" -gt 0 ]; then
                    ROI=$(python3 -c "print(round($GOAL_DELTA / ($ACTUAL_COST / 100), 2))")
                else
                    ROI=0
                fi
                sprint_db "UPDATE long_task_rounds SET cost_actual=$ACTUAL_COST, goals_after=$GOALS_AFTER,
                           roi=$ROI WHERE parent_id='$ID' AND child_id='$CHILD_ID';"
                echo "[ok] 轮次 #$ROUND_NUM 完成 (实际: ${ACTUAL_COST} 行, 目标: +$GOAL_DELTA, ROI: $ROI)"
                ;;
            *)
                echo "未知子命令: $SUB (start|end)" >&2
                exit 1
                ;;
        esac
        ;;

    long-risk)
        ID="${1:?缺少 sprint id}"
        FLAGS=""
        DETAILS=""
        STATUS="ok"

        # R1: 方向偏移 — 最近一轮 goal_delta=0 且 cost>50
        LAST_ROUND=$(sprint_db "SELECT cost_actual, goals_after - goals_before FROM long_task_rounds
                     WHERE parent_id='$ID' ORDER BY round_num DESC LIMIT 1;" 2>/dev/null)
        if [ -n "$LAST_ROUND" ]; then
            LAST_COST=$(echo "$LAST_ROUND" | cut -d'|' -f1)
            LAST_DELTA=$(echo "$LAST_ROUND" | cut -d'|' -f2)
            if [ "${LAST_DELTA:-0}" -eq 0 ] && [ "${LAST_COST:-0}" -gt 50 ]; then
                FLAGS="${FLAGS}R1,"
                DETAILS="${DETAILS}\"R1\":\"goal_delta=0, cost=$LAST_COST\","
                STATUS="halt"
            fi
        fi

        # R2: ROI 连续下降 — 连续 2 轮下降
        ROI_TREND=$(sprint_db "SELECT roi FROM long_task_rounds
                    WHERE parent_id='$ID' AND roi IS NOT NULL ORDER BY round_num DESC LIMIT 3;" 2>/dev/null)
        ROI_COUNT=0
        if [ -n "$ROI_TREND" ]; then
            ROI_COUNT=$(echo "$ROI_TREND" | wc -l | tr -d ' ')
        fi
        if [ "$ROI_COUNT" -ge 3 ]; then
            R1_VAL=$(echo "$ROI_TREND" | sed -n '1p')
            R2_VAL=$(echo "$ROI_TREND" | sed -n '2p')
            R3_VAL=$(echo "$ROI_TREND" | sed -n '3p')
            DECLINING=$(python3 -c "print('yes' if $R1_VAL < $R2_VAL < $R3_VAL else 'no')" 2>/dev/null || echo "no")
            if [ "$DECLINING" = "yes" ]; then
                FLAGS="${FLAGS}R2,"
                DETAILS="${DETAILS}\"R2\":\"ROI trend: $R3_VAL -> $R2_VAL -> $R1_VAL\","
                STATUS="halt"
            fi
        fi

        # R3: 成本超预估 — 最近一轮 actual > estimated * 1.5
        COST_CHECK=$(sprint_db "SELECT cost_estimated, cost_actual FROM long_task_rounds
                     WHERE parent_id='$ID' AND cost_estimated IS NOT NULL AND cost_actual IS NOT NULL
                     ORDER BY round_num DESC LIMIT 1;" 2>/dev/null)
        if [ -n "$COST_CHECK" ]; then
            C_EST=$(echo "$COST_CHECK" | cut -d'|' -f1)
            C_ACT=$(echo "$COST_CHECK" | cut -d'|' -f2)
            if [ "$C_EST" -gt 0 ]; then
                OVER=$(python3 -c "print('yes' if $C_ACT > $C_EST * 1.5 else 'no')" 2>/dev/null || echo "no")
                if [ "$OVER" = "yes" ]; then
                    FLAGS="${FLAGS}R3,"
                    DETAILS="${DETAILS}\"R3\":\"estimated=$C_EST, actual=$C_ACT\","
                    [ "$STATUS" = "ok" ] && STATUS="warn"
                fi
            fi
        fi

        # R4: 质量恶化 — 最近子 sprint 有 gate FAIL
        LAST_CHILD=$(sprint_db "SELECT child_id FROM long_task_rounds
                     WHERE parent_id='$ID' ORDER BY round_num DESC LIMIT 1;" 2>/dev/null)
        if [ -n "$LAST_CHILD" ]; then
            FAIL_GATES=$(sprint_db "SELECT COUNT(*) FROM sprint_gates
                         WHERE sprint_id='$LAST_CHILD' AND overall='FAIL';" 2>/dev/null)
            if [ "${FAIL_GATES:-0}" -gt 0 ]; then
                FLAGS="${FLAGS}R4,"
                DETAILS="${DETAILS}\"R4\":\"child $LAST_CHILD has $FAIL_GATES FAIL gates\","
                STATUS="halt"
            fi
        fi

        # 清理尾部逗号
        FLAGS=$(echo "$FLAGS" | sed 's/,$//')
        DETAILS=$(echo "$DETAILS" | sed 's/,$//')

        if [ -z "$FLAGS" ]; then
            echo "{\"status\":\"$STATUS\",\"flags\":[],\"details\":{}}"
        else
            echo "{\"status\":\"$STATUS\",\"flags\":[$(echo "$FLAGS" | sed 's/\([^,]*\)/"\1"/g')],\"details\":{$DETAILS}}"
        fi
        ;;

    long-summary)
        ID="${1:?缺少 sprint id}"
        echo "=== Long Task Summary: Sprint #$ID ==="
        echo ""

        # 目标
        echo "--- 目标 ---"
        TOTAL_GOALS=$(sprint_db "SELECT COUNT(*) FROM long_task_goals WHERE sprint_id='$ID';")
        ACHIEVED=$(sprint_db "SELECT COUNT(*) FROM long_task_goals WHERE sprint_id='$ID' AND status='achieved';")
        DROPPED=$(sprint_db "SELECT COUNT(*) FROM long_task_goals WHERE sprint_id='$ID' AND status='dropped';")
        PENDING=$((TOTAL_GOALS - ACHIEVED - DROPPED))
        echo "  完成: $ACHIEVED | 放弃: $DROPPED | 待定: $PENDING | 总计: $TOTAL_GOALS"
        sprint_db "SELECT seq, status, description FROM long_task_goals
                   WHERE sprint_id='$ID' ORDER BY seq;" | while IFS='|' read -r seq status desc; do
            case "$status" in
                achieved) mark="[x]" ;;
                dropped)  mark="[-]" ;;
                *)        mark="[ ]" ;;
            esac
            echo "  $mark #$seq: $desc"
        done

        echo ""
        echo "--- 轮次 ---"
        sprint_db "SELECT round_num, child_id, cost_estimated, cost_actual, goals_after - goals_before, roi
                   FROM long_task_rounds WHERE parent_id='$ID' ORDER BY round_num;" | while IFS='|' read -r rn cid est act delta roi; do
            echo "  #$rn | 子sprint: $cid | 预估: ${est:-?} | 实际: ${act:-?} | 目标: +${delta:-0} | ROI: ${roi:-?}"
        done

        TOTAL_ROUNDS=$(sprint_db "SELECT COUNT(*) FROM long_task_rounds WHERE parent_id='$ID';")
        TOTAL_COST=$(sprint_db "SELECT COALESCE(SUM(cost_actual),0) FROM long_task_rounds WHERE parent_id='$ID';")
        AVG_ROI=$(sprint_db "SELECT COALESCE(ROUND(AVG(roi),2),'N/A') FROM long_task_rounds WHERE parent_id='$ID' AND roi IS NOT NULL;")
        echo ""
        echo "--- 汇总 ---"
        echo "  轮次: $TOTAL_ROUNDS | 总成本: ${TOTAL_COST} 行 | 平均 ROI: $AVG_ROI"
        echo "  目标完成率: $ACHIEVED/$TOTAL_GOALS"
        ;;

    *)
        echo "未知操作: $ACTION" >&2
        echo "用法: sprint-ctl.sh <create|activate|end|fail|retry|stop|abandon|archive|list|status|stage-update|skip-stage|log-event|verify|init-db|long-goal|long-round|long-risk|long-summary>" >&2
        exit 1
        ;;
esac
