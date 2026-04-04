#!/bin/bash
# common.sh — Sprint 插件共享工具
#
# 提供：sprint 状态读写、指标追加
# hook 日志/阻塞 API 复用项目 hook-common.sh
#
# 用法：source "$(dirname "$0")/common.sh" 或 source "$(dirname "$0")/../common.sh"

# ─── 路径 ───
if [ -z "${CLAUDE_PROJECT_DIR:-}" ]; then
    CLAUDE_PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi

SPRINT_STATE_DIR="$CLAUDE_PROJECT_DIR/.sprint"
SPRINT_STATE_FILE="$SPRINT_STATE_DIR/state.json"
SPRINT_METRICS_FILE="$SPRINT_STATE_DIR/metrics.jsonl"
SPRINT_OBSERVATIONS="$SPRINT_STATE_DIR/observations.md"

# ─── 复用项目 hook-common.sh（hook_deny/hook_allow/hook_warn/debug_log）───
_PROJECT_HOOK_COMMON="$CLAUDE_PROJECT_DIR/scripts/hook-common.sh"
if [ -f "$_PROJECT_HOOK_COMMON" ]; then
    source "$_PROJECT_HOOK_COMMON"
else
    # fallback: 最小实现（独立运行时）
    hook_start() { :; }
    debug_log() { :; }
    hook_deny() { echo "⛔ $*" >&2; exit 1; }
    hook_allow() { exit 0; }
    hook_warn() { echo "⚠ $*" >&2; }
    hook_error() { echo "💥 $*" >&2; exit 1; }
fi

# ─── Sprint 状态工具 ───

sprint_is_active() {
    [ -f "$SPRINT_STATE_FILE" ] && \
    [ "$(jq -r '.active // false' "$SPRINT_STATE_FILE" 2>/dev/null)" = "true" ]
}

sprint_get() {
    local field="$1"
    jq -r ".$field // empty" "$SPRINT_STATE_FILE" 2>/dev/null
}

sprint_set() {
    local field="$1" value="$2"
    local tmp
    tmp=$(mktemp)
    if jq ".$field = $value" "$SPRINT_STATE_FILE" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$SPRINT_STATE_FILE"
    else
        rm -f "$tmp"
        return 1
    fi
}

sprint_append_metric() {
    echo "$1" >> "$SPRINT_METRICS_FILE"
}

# ─── Journal（事件日志，始终写入）───

SPRINT_JOURNAL_FILE="$SPRINT_STATE_DIR/journal.jsonl"
SPRINT_GATES_DIR="$SPRINT_STATE_DIR/gates"
SPRINT_DEBUG_DIR="$SPRINT_STATE_DIR/debug"
SPRINT_RULES_FILE="$SPRINT_STATE_DIR/rules.json"

# 写入 journal 事件
# 用法: sprint_log_event "event_name" '"key":"value","key2":"value2"'
sprint_log_event() {
    local event="$1"
    shift
    local extra="${*:-}"
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%S)
    local line="{\"ts\":\"$ts\",\"event\":\"$event\""
    if [ -n "$extra" ]; then
        line+=",$extra"
    fi
    line+="}"
    mkdir -p "$SPRINT_STATE_DIR"
    echo "$line" >> "$SPRINT_JOURNAL_FILE"
}

# 保存 gate 快照
# 用法: sprint_save_gate_snapshot <chunk_num> <gate_json>
sprint_save_gate_snapshot() {
    local chunk_num="$1" gate_json="$2"
    mkdir -p "$SPRINT_GATES_DIR"
    echo "$gate_json" > "$SPRINT_GATES_DIR/chunk-${chunk_num}.json"
}

# 检查 debug 模式是否开启
sprint_debug_enabled() {
    [ -f "$SPRINT_STATE_FILE" ] && \
    [ "$(jq -r '.debug // false' "$SPRINT_STATE_FILE" 2>/dev/null)" = "true" ]
}

# Debug 模式下保存文件
# 用法: sprint_debug_save "chunk-3-prompt.md" "content"
sprint_debug_save() {
    if sprint_debug_enabled; then
        local filename="$1" content="$2"
        mkdir -p "$SPRINT_DEBUG_DIR"
        echo "$content" > "$SPRINT_DEBUG_DIR/$filename"
    fi
}
