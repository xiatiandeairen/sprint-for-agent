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
