#!/bin/bash
set -euo pipefail

REPO_URL="https://github.com/xiatiandeairen/sprint-for-agent.git"
PLUGIN_PATH="~/.claude/plugins/sprint-for-agent"
INSTALL_DIR="$HOME/.claude/plugins/sprint-for-agent"
SETTINGS="$HOME/.claude/settings.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()  { printf "${GREEN}✓${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}!${NC} %s\n" "$1"; }
fail()  { printf "${RED}✗${NC} %s\n" "$1"; exit 1; }

# --- Check dependencies ---
command -v git >/dev/null 2>&1 || fail "git is required but not installed."

HAS_JQ=false
command -v jq >/dev/null 2>&1 && HAS_JQ=true

# --- Clone or update ---
if [ -d "$INSTALL_DIR" ]; then
  warn "Already installed at $INSTALL_DIR — updating..."
  git -C "$INSTALL_DIR" pull --quiet || fail "git pull failed."
  info "Updated to latest version."
else
  mkdir -p "$(dirname "$INSTALL_DIR")"
  git clone --quiet "$REPO_URL" "$INSTALL_DIR" || fail "git clone failed."
  info "Cloned to $INSTALL_DIR"
fi

# --- Register plugin in settings.json ---
register_with_jq() {
  if [ ! -f "$SETTINGS" ]; then
    echo '{}' | jq --arg p "$PLUGIN_PATH" '.plugins = [$p]' > "$SETTINGS"
  elif ! jq -e '.plugins' "$SETTINGS" >/dev/null 2>&1; then
    jq --arg p "$PLUGIN_PATH" '.plugins = [$p]' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  elif ! jq -e --arg p "$PLUGIN_PATH" '.plugins | index($p)' "$SETTINGS" >/dev/null 2>&1; then
    jq --arg p "$PLUGIN_PATH" '.plugins += [$p]' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  else
    return 0
  fi
}

register_without_jq() {
  if [ ! -f "$SETTINGS" ]; then
    mkdir -p "$(dirname "$SETTINGS")"
    printf '{\n  "plugins": ["%s"]\n}\n' "$PLUGIN_PATH" > "$SETTINGS"
  elif grep -q "sprint-for-agent" "$SETTINGS" 2>/dev/null; then
    return 0
  elif grep -q '"plugins"' "$SETTINGS" 2>/dev/null; then
    sed -i.bak 's|\("plugins":[[:space:]]*\[\)|\1"'"$PLUGIN_PATH"'", |' "$SETTINGS" && rm -f "$SETTINGS.bak"
  else
    sed -i.bak 's|{|{\n  "plugins": ["'"$PLUGIN_PATH"'"],|' "$SETTINGS" && rm -f "$SETTINGS.bak"
  fi
}

if [ "$HAS_JQ" = true ]; then
  register_with_jq
else
  register_without_jq
fi
info "Registered in $SETTINGS"

# --- Verify ---
if [ -f "$INSTALL_DIR/skills/sprint/SKILL.md" ]; then
  info "Verification passed."
else
  fail "Installation incomplete — SKILL.md not found."
fi

if grep -q "sprint-for-agent" "$SETTINGS" 2>/dev/null; then
  info "Plugin registered in settings."
else
  fail "Plugin not found in $SETTINGS."
fi

echo ""
info "sprint-for-agent installed successfully!"
echo "  Available commands: /sprint  /long-sprint  /todo"
echo "  Uninstall: bash $INSTALL_DIR/uninstall.sh"
