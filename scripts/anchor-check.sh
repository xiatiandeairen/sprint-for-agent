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

while IFS= read -r line; do
  # Skip blank lines and comments
  [[ -z "$line" || "$line" == \#* ]] && continue

  read -ra PARTS <<< "$line"
  ASSERT="${PARTS[0]}"

  case "$ASSERT" in

    MUST_NOT_IMPORT)
      TARGET="${PARTS[1]}"
      MODULE="${PARTS[2]}"
      grep -rq "^import ${MODULE}" "$ROOT/src/mac/Packages/${TARGET}/" 2>/dev/null
      check "$line" $((! $?))
      ;;

    MUST_IMPORT)
      TARGET="${PARTS[1]}"
      MODULE="${PARTS[2]}"
      grep -rq "^import ${MODULE}" "$ROOT/src/mac/Packages/${TARGET}/" 2>/dev/null
      check "$line" $?
      ;;

    MUST_NOT_EXIST)
      PATH_ARG="${PARTS[1]}"
      test -f "$ROOT/$PATH_ARG" 2>/dev/null
      check "$line" $((! $?))
      ;;

    MUST_EXIST)
      PATH_ARG="${PARTS[1]}"
      test -f "$ROOT/$PATH_ARG" 2>/dev/null
      check "$line" $?
      ;;

    MUST_BUILD)
      OUTPUT=$(cd "$ROOT/src/mac/Packages" && swift build 2>&1 | tail -1)
      echo "$OUTPUT" | grep -q "Build complete"
      check "$line" $?
      ;;

    MUST_TEST)
      OUTPUT=$(cd "$ROOT/src/mac/Packages" && swift test 2>&1)
      echo "$OUTPUT" | grep -q "0 failures"
      check "$line" $?
      ;;

    FILE_NOT_MODIFIED)
      PATH_ARG="${PARTS[1]}"
      if [[ -n "$BASE_COMMIT" ]]; then
        git diff "$BASE_COMMIT" --name-only 2>/dev/null | grep -qF "$PATH_ARG"
        check "$line" $((! $?))
      else
        echo "SKIP: $line (no base_commit)"
      fi
      ;;

    *)
      echo "UNKNOWN: $line"
      ;;
  esac

done < "$ANCHORS"

echo ""
echo "Anchor check: $PASS pass / $FAIL fail"

# Write to metrics.log
echo "anchor_check|$(date +%s)|pass=$PASS|fail=$FAIL" >> "$DIR/metrics.log"

[[ $FAIL -eq 0 ]]
