#!/usr/bin/env bash
# anchor-check.sh — Verify intent anchors for a sprint
# Usage: anchor-check.sh <sprint_id>

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SPRINT_DIR="$ROOT/.sprint"

ID="${1:-}"
if [[ -z "$ID" ]]; then
  echo "Usage: anchor-check.sh <sprint_id>" >&2
  exit 1
fi

DIR=$(find "$SPRINT_DIR" -maxdepth 1 -type d -name "${ID}*" 2>/dev/null | head -1)
if [[ -z "$DIR" ]]; then
  echo "Error: sprint '$ID' not found" >&2
  exit 1
fi

ANCHORS="$DIR/anchors.txt"
if [[ ! -f "$ANCHORS" ]]; then
  echo "No anchors.txt found for sprint $ID"
  exit 0
fi

BASE_COMMIT=$(python3 -c "import json; s=json.load(open('$DIR/state.json')); print(s.get('base_commit',''))" 2>/dev/null || echo "")

PASS=0
FAIL=0
SKIP=0

check() {
  local assertion="$1"
  local ok="$2"  # 0 = success
  if [[ "$ok" -eq 0 ]]; then
    echo "PASS: $assertion"
    PASS=$(( PASS + 1 ))
  else
    echo "FAIL: $assertion"
    FAIL=$(( FAIL + 1 ))
  fi
}

skip() {
  local assertion="$1"
  local reason="$2"
  echo "SKIP: $assertion ($reason)"
  SKIP=$(( SKIP + 1 ))
}

# ── Project config & type detection ──
# Priority: .sprint.json > CLAUDE.md > auto-detect from project root
# Aligned with quality.md Step 1 signal table

read_sprint_config() {
  local field="$1"
  if [[ -f "$ROOT/.sprint.json" ]]; then
    local val
    val=$(python3 -c "
import json, sys
try:
    c = json.load(open('$ROOT/.sprint.json'))
    print(c.get('$field', ''))
except json.JSONDecodeError:
    print('__INVALID_JSON__', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null) || {
      echo "Error: .sprint.json is not valid JSON" >&2
      exit 1
    }
    if [[ -n "$val" ]]; then echo "$val"; return; fi
  fi
}

detect_build_cmd() {
  # 1. .sprint.json
  local cfg
  cfg="$(read_sprint_config "build")"
  if [[ -n "$cfg" ]]; then echo "$cfg"; return; fi
  # 2. CLAUDE.md
  if [[ -f "$ROOT/CLAUDE.md" ]]; then
    local cmd
    cmd=$(grep -E '^\s*build_cmd\s*[:=]' "$ROOT/CLAUDE.md" 2>/dev/null | head -1 | sed 's/.*[:=]\s*//' | xargs)
    if [[ -n "$cmd" ]]; then echo "$cmd"; return; fi
  fi
  # 3. Auto-detect from project root
  if [[ -f "$ROOT/Package.swift" ]]; then echo "swift build"
  elif [[ -f "$ROOT/package.json" ]]; then echo "npm run build"
  elif [[ -f "$ROOT/Cargo.toml" ]]; then echo "cargo build"
  elif [[ -f "$ROOT/Makefile" ]]; then echo "make"
  elif [[ -f "$ROOT/pyproject.toml" ]]; then echo "pip install -e ."
  elif [[ -f "$ROOT/go.mod" ]]; then echo "go build ./..."
  elif [[ -f "$ROOT/Gemfile" ]]; then echo "bundle exec rake build"
  fi
}

detect_test_cmd() {
  # 1. .sprint.json
  local cfg
  cfg="$(read_sprint_config "test")"
  if [[ -n "$cfg" ]]; then echo "$cfg"; return; fi
  # 2. CLAUDE.md
  if [[ -f "$ROOT/CLAUDE.md" ]]; then
    local cmd
    cmd=$(grep -E '^\s*test_cmd\s*[:=]' "$ROOT/CLAUDE.md" 2>/dev/null | head -1 | sed 's/.*[:=]\s*//' | xargs)
    if [[ -n "$cmd" ]]; then echo "$cmd"; return; fi
  fi
  # 3. Auto-detect from project root
  if [[ -f "$ROOT/Package.swift" ]]; then echo "swift test"
  elif [[ -f "$ROOT/package.json" ]]; then echo "npm test"
  elif [[ -f "$ROOT/Cargo.toml" ]]; then echo "cargo test"
  elif [[ -f "$ROOT/Makefile" ]]; then echo "make test"
  elif [[ -f "$ROOT/pyproject.toml" ]]; then echo "pytest"
  elif [[ -f "$ROOT/go.mod" ]]; then echo "go test ./..."
  elif [[ -f "$ROOT/Gemfile" ]]; then echo "bundle exec rake test"
  fi
}

detect_lint_cmd() {
  # Only from .sprint.json (no CLAUDE.md or auto-detect fallback)
  read_sprint_config "lint"
}

detect_import_pattern() {
  # Returns grep pattern for import statements by project type
  local module="$1"
  if [[ -f "$ROOT/Package.swift" ]]; then echo "^import ${module}"
  elif [[ -f "$ROOT/go.mod" ]]; then echo "\"${module}\""
  elif [[ -f "$ROOT/pyproject.toml" ]] || [[ -f "$ROOT/setup.py" ]] || [[ -f "$ROOT/requirements.txt" ]]; then echo "(import ${module}|from ${module})"
  elif [[ -f "$ROOT/package.json" ]] || [[ -f "$ROOT/tsconfig.json" ]]; then echo "(import.*${module}|require.*${module})"
  elif [[ -f "$ROOT/Cargo.toml" ]]; then echo "use ${module}"
  elif [[ -f "$ROOT/Gemfile" ]]; then echo "require.*${module}"
  fi
}

BUILD_CMD="$(detect_build_cmd)"
TEST_CMD="$(detect_test_cmd)"

while IFS= read -r line; do
  # Skip blank lines and comments
  [[ -z "$line" || "$line" == \#* ]] && continue

  read -ra PARTS <<< "$line"
  ASSERT="${PARTS[0]}"

  case "$ASSERT" in

    MUST_BUILD)
      if [[ -z "$BUILD_CMD" ]]; then
        skip "$line" "no project type detected and no build_cmd in CLAUDE.md"
      else
        OUTPUT=$(cd "$ROOT" && eval "$BUILD_CMD" 2>&1) && RC=0 || RC=$?
        check "$line" $RC
      fi
      ;;

    MUST_TEST)
      if [[ -z "$TEST_CMD" ]]; then
        skip "$line" "no project type detected and no test_cmd in CLAUDE.md"
      else
        OUTPUT=$(cd "$ROOT" && eval "$TEST_CMD" 2>&1) && RC=0 || RC=$?
        check "$line" $RC
      fi
      ;;

    MUST_IMPORT)
      TARGET="${PARTS[1]}"
      MODULE="${PARTS[2]}"
      PATTERN="$(detect_import_pattern "$MODULE")"
      if [[ -z "$PATTERN" ]]; then
        skip "$line" "no project type detected for import pattern"
      elif [[ -d "$ROOT/$TARGET" ]]; then
        if grep -rqE "$PATTERN" "$ROOT/$TARGET/" 2>/dev/null; then
          check "$line" 0
        else
          check "$line" 1
        fi
      elif [[ -f "$ROOT/$TARGET" ]]; then
        if grep -qE "$PATTERN" "$ROOT/$TARGET" 2>/dev/null; then
          check "$line" 0
        else
          check "$line" 1
        fi
      else
        echo "FAIL: $line (target path not found: $TARGET)"
        FAIL=$(( FAIL + 1 ))
      fi
      ;;

    MUST_NOT_IMPORT)
      TARGET="${PARTS[1]}"
      MODULE="${PARTS[2]}"
      PATTERN="$(detect_import_pattern "$MODULE")"
      if [[ -z "$PATTERN" ]]; then
        skip "$line" "no project type detected for import pattern"
      elif [[ -d "$ROOT/$TARGET" ]]; then
        if grep -rqE "$PATTERN" "$ROOT/$TARGET/" 2>/dev/null; then
          check "$line" 1
        else
          check "$line" 0
        fi
      elif [[ -f "$ROOT/$TARGET" ]]; then
        if grep -qE "$PATTERN" "$ROOT/$TARGET" 2>/dev/null; then
          check "$line" 1
        else
          check "$line" 0
        fi
      else
        check "$line" 0
      fi
      ;;

    MUST_NOT_EXIST)
      PATH_ARG="${PARTS[1]}"
      if test -e "$ROOT/$PATH_ARG" 2>/dev/null; then
        check "$line" 1
      else
        check "$line" 0
      fi
      ;;

    MUST_EXIST)
      PATH_ARG="${PARTS[1]}"
      if test -e "$ROOT/$PATH_ARG" 2>/dev/null; then
        check "$line" 0
      else
        check "$line" 1
      fi
      ;;

    FILE_NOT_MODIFIED)
      PATH_ARG="${PARTS[1]}"
      if [[ -n "$BASE_COMMIT" ]]; then
        if git diff "$BASE_COMMIT" --name-only 2>/dev/null | grep -qF "$PATH_ARG"; then
          check "$line" 1
        else
          check "$line" 0
        fi
      else
        skip "$line" "no base_commit"
      fi
      ;;

    *)
      echo "UNKNOWN: $line"
      ;;
  esac

done < "$ANCHORS"

echo ""
echo "Anchor check: $PASS pass / $FAIL fail / $SKIP skip"

# Write to metrics.log
echo "anchor_check|$(date +%s)|pass=$PASS|fail=$FAIL|skip=$SKIP" >> "$DIR/metrics.log"

[[ $FAIL -eq 0 ]]
