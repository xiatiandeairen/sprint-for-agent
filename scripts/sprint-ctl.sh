#!/usr/bin/env bash
# sprint-ctl.sh — Sprint lifecycle tracker
# Usage: sprint-ctl.sh <create|activate|stage|end|list> [args...]

set -euo pipefail

command -v python3 >/dev/null 2>&1 || { echo "Error: python3 is required but not found. Install Python 3 and retry." >&2; exit 1; }

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
  if [[ -z "$DESC" ]]; then
    echo "Error: description is required. Usage: sprint-ctl.sh create <type> <desc> <stages>" >&2
    exit 1
  fi
  if [[ -z "$STAGES" ]]; then
    echo "Error: stages are required. Usage: sprint-ctl.sh create <type> <desc> <stages>" >&2
    exit 1
  fi
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

  COMPLEXITY="${4:-low}"
  cat > "$DIR/state.json" <<EOF
{
  "id": "$ID",
  "type": "$TYPE",
  "desc": "$DESC",
  "stages": $STAGES_JSON,
  "status": "created",
  "current_stage": "",
  "complexity": "$COMPLEXITY",
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
  while IFS='|' read -r _event stage _status _end_ts dur; do
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

  # Check after-triggers: find sprints waiting for this one to complete
  TRIGGERS_FILE="$SPRINT_DIR/triggers.json"
  if [[ -f "$TRIGGERS_FILE" ]]; then
    # Extract sprint IDs of triggered targets
    TRIGGERED=$(python3 -c "
import json, sys
with open('$TRIGGERS_FILE') as f:
    triggers = json.load(f)
found = [t for t in triggers if t.get('type') == 'after' and t.get('spec') == '$ID']
for t in found:
    print(t['sprint_id'])
" 2>/dev/null || true)
    if [[ -n "$TRIGGERED" ]]; then
      echo ""
      echo "> [trigger] after-sprints ready to resume:"
      while IFS= read -r tid; do
        echo ">   /todo $tid"
      done <<< "$TRIGGERED"
    fi
  fi
  ;;

evaluate)
  # Usage: sprint-ctl.sh evaluate <clarify> <design> <risk> [keywords...]
  # Input: 3 binary parameters (0 or 1)
  # Output: stage list
  CLARIFY="${1:-0}"; DESIGN="${2:-0}"; RISK="${3:-0}"; _COMP="${4:-low}"
  shift 4 2>/dev/null || shift 3 2>/dev/null || true
  KEYWORDS="$*"

  # ── Keyword override: high-risk keywords force risk=1 ──
  for kw in $KEYWORDS; do
    case "$kw" in
      delete|migrate|migration|payment|production|permission|数据|删除|迁移|权限|支付|生产)
        RISK=1 ;;
    esac
  done

  # ── Build stage list ──
  STAGES=""
  [[ $CLARIFY -eq 1 ]] && STAGES="brainstorm"
  [[ $DESIGN -eq 1 ]] && STAGES="${STAGES:+$STAGES,}design"
  STAGES="${STAGES:+$STAGES,}plan,execute,quality"
  [[ $RISK -eq 1 ]] && STAGES="${STAGES},review"
  STAGES="${STAGES},insight"

  # ── Complexity assessment ──
  # Binary: high if explicitly flagged, low otherwise
  # AI caller sets COMPLEXITY based on: files >5 OR cross-module (>1 top-level dir) → high
  COMPLEXITY="${4:-low}"
  if [[ "$COMPLEXITY" != "high" && "$COMPLEXITY" != "low" ]]; then
    COMPLEXITY="low"
  fi

  # ── Output ──
  echo "INPUT"
  echo "  clarify=$CLARIFY  design=$DESIGN  risk=$RISK  complexity=$COMPLEXITY"
  echo ""
  echo "STAGES"
  echo "  $STAGES"
  echo ""

  echo "DETAIL"

  # brainstorm
  if [[ $CLARIFY -eq 1 ]]; then
    echo "  brainstorm  INCLUDED   goal unclear, needs exploration"
  else
    echo "  brainstorm  SKIP       goal is clear"
  fi

  # design
  if [[ $DESIGN -eq 1 ]]; then
    echo "  design      INCLUDED   scope needs architectural design"
  else
    echo "  design      SKIP       scope is small, no design needed"
  fi

  # plan
  echo "  plan        ALWAYS     task breakdown required"

  # execute
  echo "  execute     ALWAYS     implementation"

  # quality
  echo "  quality     ALWAYS     verification"

  # review
  if [[ $RISK -eq 1 ]]; then
    echo "  review      INCLUDED   high-risk, needs human review"
  else
    echo "  review      SKIP       risk is low, no review needed"
  fi

  # insight
  echo "  insight     ALWAYS     retrospective"

  echo ""
  echo "COMPLEXITY"
  echo "  $COMPLEXITY"
  if [[ "$COMPLEXITY" == "high" ]]; then
    echo "  design gates: all steps enabled"
  else
    echo "  design gates: optional steps default skip (1/2/3/5)"
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

stats)
  # Usage: sprint-ctl.sh stats [--last N] [--status STATUS]
  if [[ ! -d "$SPRINT_DIR" ]]; then
    echo "No sprints found."
    exit 0
  fi

  LAST=""
  FILTER_STATUS=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --last) LAST="$2"; shift 2 ;;
      --status) FILTER_STATUS="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  python3 -c "
import json, os, re, sys

sprint_dir = '$SPRINT_DIR'
last_n = int('$LAST') if '$LAST' else None
filter_status = '$FILTER_STATUS' or None

# Collect sprint data
sprints = []
for name in sorted(os.listdir(sprint_dir)):
    state_path = os.path.join(sprint_dir, name, 'state.json')
    if not os.path.isfile(state_path):
        continue
    try:
        state = json.load(open(state_path))
    except (json.JSONDecodeError, IOError):
        continue
    if filter_status and state.get('status') != filter_status:
        continue
    sprints.append((name, state))

# Sort by created_at descending, take last N
sprints.sort(key=lambda x: x[1].get('created_at', ''), reverse=True)
if last_n:
    sprints = sprints[:last_n]

if not sprints:
    print('No sprints found.')
    sys.exit(0)

total = len(sprints)
completed = sum(1 for _, s in sprints if s['status'] == 'completed')

# Parse metrics.log for each sprint
total_duration = 0
duration_count = 0
stage_times = {}
stage_counts = {}
anchor_pass = 0
anchor_total = 0

for name, state in sprints:
    metrics_path = os.path.join(sprint_dir, name, 'metrics.log')
    if not os.path.isfile(metrics_path):
        continue

    sprint_start_ts = None
    sprint_end_ts = None

    with open(metrics_path) as f:
        for line in f:
            parts = line.strip().split('|')
            if not parts:
                continue
            event = parts[0]

            if event == 'sprint_start' and len(parts) >= 3:
                sprint_start_ts = int(parts[2])
            elif event == 'sprint_end' and len(parts) >= 3:
                sprint_end_ts = int(parts[2])
            elif event == 'stage_end' and len(parts) >= 5:
                stage = parts[1]
                dur_str = parts[4].rstrip('s')
                try:
                    dur = int(dur_str)
                except ValueError:
                    continue
                stage_times[stage] = stage_times.get(stage, 0) + dur
                stage_counts[stage] = stage_counts.get(stage, 0) + 1
            elif event == 'anchor_check' and len(parts) >= 4:
                for p in parts[2:]:
                    if p.startswith('pass='):
                        anchor_pass += int(p.split('=')[1])
                        anchor_total += int(p.split('=')[1])
                    elif p.startswith('fail='):
                        anchor_total += int(p.split('=')[1])

    if sprint_start_ts and sprint_end_ts:
        total_duration += (sprint_end_ts - sprint_start_ts)
        duration_count += 1

# Parse execute handoffs for task completion
tasks_completed = 0
tasks_total = 0
for name, state in sprints:
    exec_path = os.path.join(sprint_dir, name, 'handoffs', 'execute.md')
    if not os.path.isfile(exec_path):
        continue
    with open(exec_path) as f:
        content = f.read()
    # Match 'Tasks completed: N/M'
    m = re.search(r'Tasks completed:\s*(\d+)/(\d+)', content)
    if m:
        tasks_completed += int(m.group(1))
        tasks_total += int(m.group(2))

# Scope creep from end output in metrics (count lines with 'creep')
# Actually parse plan handoff Expected Files vs state base_commit
# Simplified: count from metrics.log is not stored. Skip for now.

# Output
filter_desc = ''
if filter_status:
    filter_desc += f', status={filter_status}'
if last_n:
    filter_desc += f', last {last_n}'

print(f'Sprint Stats ({total} sprints, {completed} completed{filter_desc})')
print('─' * 40)

# Efficiency
print()
print('Efficiency')
if total > 0:
    pct = completed * 100 // total
    print(f'  Completion rate:  {pct}% ({completed}/{total})')
if duration_count > 0:
    avg_min = total_duration // duration_count // 60
    print(f'  Avg duration:     {avg_min}m')

if stage_times:
    total_stage_time = sum(stage_times.values()) or 1
    print('  Stage distribution:')
    for stage in ['brainstorm','design','plan','execute','quality','review','insight']:
        if stage in stage_times:
            pct = stage_times[stage] * 100 // total_stage_time
            cnt = stage_counts.get(stage, 0)
            print(f'    {stage:<15} {pct:>3}%  ({cnt} sprints)')

# Quality
print()
print('Quality')
if anchor_total > 0:
    apct = anchor_pass * 100 // anchor_total
    print(f'  Anchor pass rate: {apct}% ({anchor_pass}/{anchor_total})')
else:
    print('  Anchor pass rate: N/A')

# Value
print()
print('Value')
if tasks_total > 0:
    tpct = tasks_completed * 100 // tasks_total
    print(f'  Task completion:  {tpct}% ({tasks_completed}/{tasks_total})')
else:
    print('  Task completion:  N/A')
"
  ;;

*)
  echo "Usage: sprint-ctl.sh <command> [args]"
  echo "  evaluate <clarify> <design> <risk> [keywords]  Evaluate task dimensions"
  echo "  create   <type> <desc> <stages>           Create sprint"
  echo "  activate <id>                             Activate sprint"
  echo "  stage    <id> <stage> <status>            Update stage status"
  echo "  end      <id>                             Complete sprint"
  echo "  list                                      List sprints"
  echo "  stats    [--last N] [--status STATUS]     Show aggregated statistics"
  exit 1
  ;;

esac
