#!/usr/bin/env bash
# sprint-ctl.sh — Sprint lifecycle tracker
# Usage: sprint-ctl.sh <create|activate|stage|end|list> [args...]

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SPRINT_DIR="$ROOT/.sprint"

get_sprint_dir() {
  local id="$1"
  local dir
  dir=$(find "$SPRINT_DIR" -maxdepth 1 -type d -name "${id}*" 2>/dev/null | head -1)
  if [[ -z "$dir" ]]; then
    echo "Error: sprint '$id' not found" >&2
    exit 1
  fi
  echo "$dir"
}

now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

now_ts() {
  date +%s
}

cmd="${1:-}"
shift || true

case "$cmd" in

create)
  TYPE="${1:-simple}"
  DESC="${2:-}"
  STAGES="${3:-}"
  ID="$(date +%Y%m%d-%H%M%S)-$(printf '%03d' $((RANDOM % 1000)))"
  DIR="$SPRINT_DIR/$ID"
  mkdir -p "$DIR/handoffs"
  touch "$DIR/anchors.txt"

  # Build stages JSON array
  STAGES_JSON="["
  IFS=',' read -ra STAGE_ARR <<< "$STAGES"
  for i in "${!STAGE_ARR[@]}"; do
    stage="$(echo "${STAGE_ARR[$i]}" | tr -d ' ')"
    [[ $i -gt 0 ]] && STAGES_JSON+=","
    STAGES_JSON+="\"$stage\""
  done
  STAGES_JSON+="]"

  BASE_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo "none")"
  CREATED_AT="$(now_iso)"

  cat > "$DIR/state.json" <<EOF
{
  "id": "$ID",
  "type": "$TYPE",
  "desc": "$DESC",
  "stages": $STAGES_JSON,
  "status": "created",
  "current_stage": "",
  "base_commit": "$BASE_COMMIT",
  "created_at": "$CREATED_AT"
}
EOF

  echo "sprint_start|$ID|$(now_ts)" >> "$DIR/metrics.log"

  echo "Sprint created: $ID"
  echo "Type: $TYPE | Stages: $STAGES"
  echo "Dir: $DIR"
  ;;

activate)
  ID="${1:-}"
  DIR="$(get_sprint_dir "$ID")"
  BASE_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo "none")"

  # Update state.json
  TMP="$(mktemp)"
  python3 -c "
import json, sys
with open('$DIR/state.json') as f:
    s = json.load(f)
s['status'] = 'running'
s['base_commit'] = '$BASE_COMMIT'
print(json.dumps(s, indent=2))
" > "$TMP" && mv "$TMP" "$DIR/state.json"

  echo "Sprint $ID activated (base: $BASE_COMMIT)"
  ;;

stage)
  ID="${1:-}"
  STAGE="${2:-}"
  STATUS="${3:-}"
  DIR="$(get_sprint_dir "$ID")"
  TS="$(now_ts)"

  case "$STATUS" in
    running)
      echo "stage_start|$STAGE|$TS" >> "$DIR/metrics.log"
      ;;
    completed|skipped)
      # Find last stage_start for this stage
      LAST_START=$(grep "^stage_start|$STAGE|" "$DIR/metrics.log" 2>/dev/null | tail -1 | cut -d'|' -f3 || echo "$TS")
      DURATION=$(( TS - LAST_START ))
      echo "stage_end|$STAGE|$STATUS|$TS|${DURATION}s" >> "$DIR/metrics.log"
      ;;
    *)
      echo "Error: status must be running, completed, or skipped" >&2
      exit 1
      ;;
  esac

  TMP="$(mktemp)"
  python3 -c "
import json
with open('$DIR/state.json') as f:
    s = json.load(f)
s['current_stage'] = '$STAGE'
print(json.dumps(s, indent=2))
" > "$TMP" && mv "$TMP" "$DIR/state.json"

  echo "Stage $STAGE → $STATUS"
  ;;

end)
  ID="${1:-}"
  DIR="$(get_sprint_dir "$ID")"
  TS="$(now_ts)"

  TMP="$(mktemp)"
  python3 -c "
import json
with open('$DIR/state.json') as f:
    s = json.load(f)
s['status'] = 'completed'
print(json.dumps(s, indent=2))
" > "$TMP" && mv "$TMP" "$DIR/state.json"

  echo "sprint_end|$ID|$TS" >> "$DIR/metrics.log"

  # Read state for summary
  BASE_COMMIT=$(python3 -c "import json; s=json.load(open('$DIR/state.json')); print(s.get('base_commit',''))")
  SPRINT_START_TS=$(grep "^sprint_start" "$DIR/metrics.log" | head -1 | cut -d'|' -f3)
  TOTAL_DURATION=$(( TS - SPRINT_START_TS ))
  TOTAL_MIN=$(( TOTAL_DURATION / 60 ))

  echo ""
  echo "> [完成] Sprint #$ID"
  echo ""

  # Per-stage durations
  while IFS='|' read -r event stage status end_ts dur; do
    printf "> %-15s %s\n" "$stage" "$dur"
  done < <(grep "^stage_end" "$DIR/metrics.log")

  echo "> ─────────────────────────"
  printf "> %-15s %dm\n" "总计" "$TOTAL_MIN"

  # Anchor results
  PASS=$(grep "^anchor_check" "$DIR/metrics.log" | grep -o "pass=[0-9]*" | tail -1 | cut -d= -f2 || echo "?")
  FAIL=$(grep "^anchor_check" "$DIR/metrics.log" | grep -o "fail=[0-9]*" | tail -1 | cut -d= -f2 || echo "?")
  echo "> anchor         $PASS pass / $FAIL fail"

  # Scope creep detection
  if [[ -f "$DIR/handoffs/plan.md" ]] && [[ "$BASE_COMMIT" != "none" ]] && [[ -n "$BASE_COMMIT" ]]; then
    EXPECTED=$(grep -A 100 "## Expected Files" "$DIR/handoffs/plan.md" 2>/dev/null | tail -n +2 | grep "^- " | sed 's/^- //' || true)
    ACTUAL=$(git diff "$BASE_COMMIT" --name-only 2>/dev/null || true)
    CREEP=0
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      if ! echo "$EXPECTED" | grep -qF "$f"; then
        CREEP=$(( CREEP + 1 ))
      fi
    done <<< "$ACTUAL"
    echo "> creep          $CREEP files"
  fi
  ;;

list)
  if [[ ! -d "$SPRINT_DIR" ]]; then
    echo "No sprints found."
    exit 0
  fi
  FOUND=0
  for state in "$SPRINT_DIR"/*/state.json; do
    [[ -f "$state" ]] || continue
    FOUND=1
    python3 -c "
import json
s = json.load(open('$state'))
print(f\"{s['id']:<26} {s['type']:<10} {s['status']:<12} {s['desc']}\")
"
  done
  if [[ $FOUND -eq 0 ]]; then echo "No sprints found."; fi
  ;;

*)
  echo "Usage: sprint-ctl.sh <create|activate|stage|end|list> [args]"
  echo "  create  <type> <desc> <stages>   Create a new sprint"
  echo "  activate <id>                    Activate a sprint"
  echo "  stage   <id> <stage> <status>    Update stage status (running|completed|skipped)"
  echo "  end     <id>                     Complete sprint and print summary"
  echo "  list                             List all sprints"
  exit 1
  ;;

esac
