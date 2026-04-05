#!/bin/bash
# common.sh -- Sprint 插件共享工具
#
# 提供：DB 连接、查询 API、事件日志、hook API

# ─── 路径 ───
if [ -z "${CLAUDE_PROJECT_DIR:-}" ]; then
    CLAUDE_PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi

SPRINT_DB="${SPRINT_DB:-${XDG_DATA_HOME:-$HOME/.local/share}/sprint/sprint.db}"
SPRINT_DIR="$CLAUDE_PROJECT_DIR/.sprint"
SPRINT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# ─── Hook API ───
_PROJECT_HOOK_COMMON="$CLAUDE_PROJECT_DIR/scripts/hook-common.sh"
if [ -f "$_PROJECT_HOOK_COMMON" ]; then
    source "$_PROJECT_HOOK_COMMON"
else
    hook_start() { :; }
    debug_log() { :; }
    hook_deny() { echo "{\"decision\":\"deny\",\"reason\":\"$*\"}"; exit 0; }
    hook_allow() { echo "{\"decision\":\"allow\"}"; exit 0; }
    hook_warn() { echo "[WARN] $*" >&2; }
    hook_error() { echo "{\"decision\":\"deny\",\"reason\":\"$*\"}"; exit 1; }
fi

# ─── SQLite ───

sprint_db() {
    sqlite3 "$SPRINT_DB" "$@"
}

sprint_db_init() {
    mkdir -p "$(dirname "$SPRINT_DB")"
    if [ ! -f "$SPRINT_DB" ]; then
        sprint_db < "$SPRINT_SCRIPT_DIR/migrations/v1.sql"
    fi
}

sprint_db_ensure() {
    [ -f "$SPRINT_DB" ] || sprint_db_init
}

# ─── 查询 API ───

# 当前活跃 sprint ID（最近更新的）
sprint_current_id() {
    sprint_db "SELECT id FROM sprints WHERE status IN ('running','retrying') ORDER BY updated_at DESC LIMIT 1;"
}

# 活跃 sprint 数量
sprint_active_count() {
    sprint_db "SELECT COUNT(*) FROM sprints WHERE status IN ('running','retrying');"
}

# 是否有活跃 sprint
sprint_has_active() {
    [ "$(sprint_active_count)" -gt 0 ]
}

# 获取 sprint 字段
# 用法: sprint_field {id} {column}
sprint_field() {
    sprint_db "SELECT $2 FROM sprints WHERE id='$1';"
}

# 获取 sprint 工作目录
# 用法: sprint_work_dir {id}
sprint_work_dir() {
    local dir_name
    dir_name=$(sprint_field "$1" "dir_name")
    echo "$SPRINT_DIR/active/$dir_name"
}

# 获取 sprint 目录路径
sprint_anchors_dir() { echo "$(sprint_work_dir "$1")/anchors"; }
sprint_handoffs_dir() { echo "$(sprint_work_dir "$1")/handoffs"; }
sprint_reports_dir() { echo "$(sprint_work_dir "$1")/reports"; }

# 获取 plan anchor 路径（gate/verify 用）
sprint_anchor_path() {
    echo "$(sprint_work_dir "$1")/anchors/plan.md"
}

# 获取 chunks 路径
sprint_chunks_path() {
    echo "$(sprint_work_dir "$1")/handoffs/plan-chunks.md"
}

# 获取最近一次 gate 状态
sprint_last_gate_status() {
    sprint_db "SELECT COALESCE(
        (SELECT overall FROM sprint_gates
         WHERE sprint_id='$1'
         ORDER BY run_at DESC LIMIT 1), 'PASS');"
}

# 获取基线值
# 用法: sprint_baseline {id} {key}
sprint_baseline() {
    sprint_db "SELECT COALESCE(
        (SELECT value FROM sprint_baselines
         WHERE sprint_id='$1' AND key='$2'), 0);"
}

# 记录基线值
# 用法: sprint_set_baseline {id} {key} {value}
sprint_set_baseline() {
    sprint_db "INSERT OR REPLACE INTO sprint_baselines (sprint_id, key, value)
               VALUES ('$1', '$2', $3);"
}

# 记录 gate 结果（主表），返回 gate_id
# 用法: sprint_record_gate {id} {chunk} {overall} {diff} {tests}
sprint_record_gate() {
    sprint_db "INSERT INTO sprint_gates (sprint_id, chunk_num, overall, diff_lines, test_count)
               VALUES ('$1', $2, '$3', $4, $5);
               SELECT last_insert_rowid();"
}

# 记录 gate 详情（逐项）
# 用法: sprint_record_gate_item {gate_id} {item_id} {name} {status} {detail}
sprint_record_gate_item() {
    local detail_escaped
    detail_escaped=$(echo "$5" | sed "s/'/''/g")
    sprint_db "INSERT INTO sprint_gate_items (gate_id, item_id, name, status, detail)
               VALUES ($1, '$2', '$3', '$4', '$detail_escaped');"
}

# 记录 chunk 指标
# 用法: sprint_record_chunk {id} {chunk_num} {diff} {files} {tests} {test_added} {commit}
sprint_record_chunk() {
    sprint_db "UPDATE sprint_chunks SET
        diff_lines=$3, files_changed=$4, test_count=$5, test_added=$6,
        commit_hash='$7', status='completed',
        completed_at=strftime('%Y-%m-%dT%H:%M:%SZ','now')
        WHERE sprint_id='$1' AND chunk_num=$2;"
}

# ─── 事件日志 ───

sprint_log_event() {
    local sid="$1" event="$2"
    shift 2
    local detail="${*:-}"
    sprint_db_ensure
    sprint_db "INSERT INTO sprint_events (sprint_id, event, detail)
               VALUES ('$sid', '$event', '$detail');"
}
