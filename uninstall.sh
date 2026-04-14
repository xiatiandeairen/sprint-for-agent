#!/bin/bash
set -euo pipefail

PLUGIN_PATH="~/.claude/plugins/sprint-for-agent"
INSTALL_DIR="$HOME/.claude/plugins/sprint-for-agent"
SETTINGS="$HOME/.claude/settings.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

info()  { printf "${GREEN}✓${NC} %s\n" "$1"; }
fail()  { printf "${RED}✗${NC} %s\n" "$1"; exit 1; }

HAS_JQ=false
command -v jq >/dev/null 2>&1 && HAS_JQ=true

# --- Remove from settings.json ---
if [ -f "$SETTINGS" ]; then
  if [ "$HAS_JQ" = true ]; then
    jq --arg p "$PLUGIN_PATH" '.plugins = [.plugins[] | select(. != $p)]' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  else
    if grep -q "sprint-for-agent" "$SETTINGS" 2>/dev/null; then
      sed -i.bak 's|"~/.claude/plugins/sprint-for-agent",\{0,1\}[[:space:]]*||g' "$SETTINGS" && rm -f "$SETTINGS.bak"
      sed -i.bak 's|,[[:space:]]*"~/.claude/plugins/sprint-for-agent"||g' "$SETTINGS" && rm -f "$SETTINGS.bak"
    fi
  fi
  info "Removed from $SETTINGS"
else
  info "No settings file found — skipping."
fi

# --- Remove directory ---
if [ -d "$INSTALL_DIR" ]; then
  rm -rf "$INSTALL_DIR"
  info "Removed $INSTALL_DIR"
else
  info "Directory not found — skipping."
fi

echo ""
info "sprint-for-agent uninstalled."
