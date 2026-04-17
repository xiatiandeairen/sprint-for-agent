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

  # ── Write to summary.json ──
  SUMMARY_FILE="$SPRINT_DIR/summary.json"

  # Collect stage durations
  STAGE_DURATIONS="{}"
  while IFS='|' read -r _event stage _status _end_ts dur; do
    dur_sec="${dur%s}"
    STAGE_DURATIONS=$(python3 -c "
import json, sys
d = json.loads('$STAGE_DURATIONS')
d['$stage'] = int('$dur_sec')
print(json.dumps(d))
")
  done < <(grep "^stage_end" "$DIR/metrics.log")

  # Collect anchor results
  ANCHOR_PASS=$(grep "^anchor_check" "$DIR/metrics.log" 2>/dev/null | grep -o "pass=[0-9]*" | tail -1 | cut -d= -f2 || echo "0")
  ANCHOR_FAIL=$(grep "^anchor_check" "$DIR/metrics.log" 2>/dev/null | grep -o "fail=[0-9]*" | tail -1 | cut -d= -f2 || echo "0")
  ANCHOR_SKIP_VAL=$(grep "^anchor_check" "$DIR/metrics.log" 2>/dev/null | grep -o "skip=[0-9]*" | tail -1 | cut -d= -f2 || echo "0")

  # Collect task completion from execute handoff
  TASKS_DONE=0; TASKS_ALL=0
  if [[ -f "$DIR/handoffs/execute.md" ]]; then
    TASK_MATCH=$(grep -oE "Tasks completed:\s*[0-9]+/[0-9]+" "$DIR/handoffs/execute.md" 2>/dev/null || true)
    if [[ -n "$TASK_MATCH" ]]; then
      TASKS_DONE=$(echo "$TASK_MATCH" | grep -oE "[0-9]+/[0-9]+" | cut -d/ -f1)
      TASKS_ALL=$(echo "$TASK_MATCH" | grep -oE "[0-9]+/[0-9]+" | cut -d/ -f2)
    fi
  fi

  # Scope creep count (reuse CREEP if computed above, else 0)
  CREEP_COUNT="${CREEP:-0}"

  python3 -c "
import json, os

summary_path = '$SUMMARY_FILE'
entry = {
    'id': '$ID',
    'desc': $(python3 -c "import json; s=json.load(open('$DIR/state.json')); print(json.dumps(s['desc']))"),
    'status': 'completed',
    'type': $(python3 -c "import json; s=json.load(open('$DIR/state.json')); print(json.dumps(s['type']))"),
    'complexity': $(python3 -c "import json; s=json.load(open('$DIR/state.json')); print(json.dumps(s.get('complexity','low')))"),
    'duration': $TOTAL_DURATION,
    'stages': $STAGE_DURATIONS,
    'anchor': {'pass': $ANCHOR_PASS, 'fail': $ANCHOR_FAIL, 'skip': $ANCHOR_SKIP_VAL},
    'scope_creep': $CREEP_COUNT,
    'tasks': {'completed': $TASKS_DONE, 'total': $TASKS_ALL},
    'completed_at': '$(now_iso)'
}

data = []
if os.path.isfile(summary_path):
    try:
        data = json.load(open(summary_path))
    except (json.JSONDecodeError, IOError):
        data = []

# Avoid duplicate entries
data = [d for d in data if d.get('id') != '$ID']
data.append(entry)

with open(summary_path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
"

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
  STAGES="${STAGES:+$STAGES,}plan,execute"
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

  # ── HINTS from historical data ──
  SUMMARY_FILE="$SPRINT_DIR/summary.json"
  if [[ -f "$SUMMARY_FILE" ]]; then
    HINTS_OUTPUT=$(python3 -c "
import json, sys

try:
    data = json.load(open('$SUMMARY_FILE'))
except (json.JSONDecodeError, IOError):
    sys.exit(0)

if len(data) < 3:
    sys.exit(0)

# Sort oldest first
data.sort(key=lambda x: x.get('completed_at', ''))
total = len(data)

hints = []

# Helper: trend detection (last 3 monotonic)
def trend(values, name, unit='', fmt=lambda x: str(x)):
    if len(values) < 3:
        return
    last3 = values[-3:]
    if last3[0] < last3[1] < last3[2]:
        hints.append(f'[趋势] {name}连续上升: {fmt(last3[0])}{unit} → {fmt(last3[1])}{unit} → {fmt(last3[2])}{unit}')
    elif last3[0] > last3[1] > last3[2]:
        hints.append(f'[趋势] {name}连续下降: {fmt(last3[0])}{unit} → {fmt(last3[1])}{unit} → {fmt(last3[2])}{unit}')

# Helper: anomaly detection (last > 2x avg of prior, need ≥5)
def anomaly(values, name, unit='', fmt=lambda x: str(x)):
    if len(values) < 5:
        return
    prior = values[:-1]
    avg = sum(prior) / len(prior)
    if avg > 0 and values[-1] > 2 * avg:
        hints.append(f'[异常] 上次 {name} {fmt(values[-1])}{unit}，历史平均 {fmt(int(avg))}{unit}')

# Duration
durations = [d['duration'] // 60 for d in data if d.get('duration')]
trend(durations, 'duration', 'm')
anomaly(durations, 'duration', 'm')

# Scope creep
creep = [d.get('scope_creep', 0) for d in data]
trend(creep, 'scope creep', ' files')
anomaly(creep, 'scope creep', ' files')

# Anchor pass rate
anchor_rates = []
for d in data:
    a = d.get('anchor', {})
    t = a.get('pass', 0) + a.get('fail', 0)
    if t > 0:
        anchor_rates.append(a['pass'] * 100 // t)
trend(anchor_rates, 'anchor 通过率', '%')

# Brainstorm share
bs_shares = []
for d in data:
    dur = d.get('duration', 0)
    bs = d.get('stages', {}).get('brainstorm', 0)
    if dur > 0 and bs > 0:
        bs_shares.append(bs * 100 // dur)
trend(bs_shares, 'brainstorm 占比', '%')

if hints:
    print(f'HINTS ({total} sprints)')
    for h in hints:
        print(f'  {h}')
" 2>/dev/null || true)
    if [[ -n "$HINTS_OUTPUT" ]]; then
      echo ""
      echo "$HINTS_OUTPUT"
    fi
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

report)
  # Usage: sprint-ctl.sh report [id] [--last N] [--status STATUS]
  # No args = aggregate report. With id = single sprint summary.
  SUMMARY_FILE="$SPRINT_DIR/summary.json"

  if [[ ! -f "$SUMMARY_FILE" ]]; then
    echo "No sprint data found. Complete a sprint first."
    exit 0
  fi

  # Check if first arg is an ID (not a flag)
  REPORT_ID=""
  LAST=""
  FILTER_STATUS=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --last) LAST="$2"; shift 2 ;;
      --status) FILTER_STATUS="$2"; shift 2 ;;
      -*) shift ;;
      *) REPORT_ID="$1"; shift ;;
    esac
  done

  python3 -c "
import json, sys

summary_path = '$SUMMARY_FILE'
report_id = '$REPORT_ID'
last_n = int('$LAST') if '$LAST' else None
filter_status = '$FILTER_STATUS' or None

try:
    data = json.load(open(summary_path))
except (json.JSONDecodeError, IOError):
    print('No sprint data found.')
    sys.exit(0)

if not data:
    print('No sprint data found.')
    sys.exit(0)

# ── Single sprint report ──
if report_id:
    matches = [d for d in data if d['id'].startswith(report_id)]
    if not matches:
        print(f'Sprint {report_id} not found in summary.')
        sys.exit(1)
    s = matches[0]
    dur_m = s['duration'] // 60
    stages_str = ' → '.join(f\"{k}({v // 60}m{v % 60:02d}s)\" for k, v in s.get('stages', {}).items())
    a = s.get('anchor', {})
    a_total = a.get('pass', 0) + a.get('fail', 0)
    a_str = f\"{a.get('pass', 0)}/{a_total} pass\" if a_total > 0 else 'N/A'
    t = s.get('tasks', {})
    t_str = f\"{t.get('completed', 0)}/{t.get('total', 0)}\" if t.get('total', 0) > 0 else 'N/A'
    date_str = s.get('completed_at', '')[:10]

    print(f\"Sprint: {s['id']} | {s['desc']}\")
    print(f\"Status: {s['status']} | Duration: {dur_m}m | {date_str}\")
    print(f\"Stages: {stages_str}\")
    print(f\"Anchor: {a_str} | Scope creep: {s.get('scope_creep', 0)} files | Tasks: {t_str}\")
    sys.exit(0)

# ── Aggregate report ──
if filter_status:
    data = [d for d in data if d.get('status') == filter_status]

# Sort by completed_at descending
data.sort(key=lambda x: x.get('completed_at', ''), reverse=True)
if last_n:
    data = data[:last_n]

if not data:
    print('No sprint data found.')
    sys.exit(0)

total = len(data)
completed = sum(1 for d in data if d['status'] == 'completed')

# ── Trends (main section) ──
print(f'Sprint Report ({total} sprints)')
print('═' * 40)

def detect_trend(values):
    \"\"\"Check if last 3 values are monotonic. Returns arrow or None.\"\"\"
    if len(values) < 3:
        return None
    last3 = values[-3:]
    if last3[0] < last3[1] < last3[2]:
        return '↑'
    if last3[0] > last3[1] > last3[2]:
        return '↓'
    return None

def detect_anomaly(values):
    \"\"\"Check if last value > 2x average of prior values.\"\"\"
    if len(values) < 5:
        return None
    prior = values[:-1]
    avg = sum(prior) / len(prior)
    if avg > 0 and values[-1] > 2 * avg:
        return values[-1], avg
    return None

# Prepare time-ordered data (oldest first for trend detection)
ordered = sorted(data, key=lambda x: x.get('completed_at', ''))

durations = [d['duration'] // 60 for d in ordered if d.get('duration')]
anchor_rates = []
for d in ordered:
    a = d.get('anchor', {})
    t = a.get('pass', 0) + a.get('fail', 0)
    if t > 0:
        anchor_rates.append(a['pass'] * 100 // t)
creep_vals = [d.get('scope_creep', 0) for d in ordered]

# Stage share for brainstorm
bs_shares = []
for d in ordered:
    dur = d.get('duration', 0)
    bs = d.get('stages', {}).get('brainstorm', 0)
    if dur > 0 and bs > 0:
        bs_shares.append(bs * 100 // dur)

has_trends = False
print()
print('Trends')

# Duration trend
t = detect_trend(durations)
if t and len(durations) >= 3:
    last3 = durations[-3:]
    print(f'  Duration:    {last3[0]}m → {last3[1]}m → {last3[2]}m ({len(durations)} sprints) {t}')
    has_trends = True

anom = detect_anomaly(durations)
if anom:
    print(f'  [异常] 上次 duration {anom[0]}m，历史平均 {anom[1]:.0f}m')
    has_trends = True

# Anchor rate trend
t = detect_trend(anchor_rates)
if t and len(anchor_rates) >= 3:
    last3 = anchor_rates[-3:]
    print(f'  Anchor rate: {last3[0]}% → {last3[1]}% → {last3[2]}% ({len(anchor_rates)} sprints) {t}')
    has_trends = True

# Scope creep trend
t = detect_trend(creep_vals)
if t and len(creep_vals) >= 3:
    last3 = creep_vals[-3:]
    print(f'  Scope creep: {last3[0]} → {last3[1]} → {last3[2]} ({len(creep_vals)} sprints) {t}')
    has_trends = True

anom = detect_anomaly(creep_vals)
if anom:
    print(f'  [异常] 上次 scope creep {anom[0]} files，历史平均 {anom[1]:.1f}')
    has_trends = True

# Brainstorm share trend
t = detect_trend(bs_shares)
if t and len(bs_shares) >= 3:
    last3 = bs_shares[-3:]
    print(f'  brainstorm:  {last3[0]}% → {last3[1]}% → {last3[2]}% ({len(bs_shares)} sprints) {t}')
    has_trends = True

if not has_trends:
    print('  No trends detected (need ≥3 sprints)')

# ── Summary ──
print()
print('Summary')
comp_pct = completed * 100 // total if total > 0 else 0
avg_dur = sum(durations) // len(durations) if durations else 0
avg_anchor = sum(anchor_rates) // len(anchor_rates) if anchor_rates else 0
print(f'  Completion: {comp_pct}% ({completed}/{total}) | Avg: {avg_dur}m | Anchors: {avg_anchor}%')
"
  ;;

stats)
  # Alias for report — re-invoke as report
  SCRIPT_PATH="${BASH_SOURCE[0]}"
  exec bash "$SCRIPT_PATH" report "$@"
  ;;

*)
  echo "Usage: sprint-ctl.sh <command> [args]"
  echo "  evaluate <clarify> <design> <risk> [complexity] [keywords]  Evaluate task dimensions"
  echo "  create   <type> <desc> <stages>           Create sprint"
  echo "  activate <id>                             Activate sprint"
  echo "  stage    <id> <stage> <status>            Update stage status"
  echo "  end      <id>                             Complete sprint"
  echo "  list                                      List sprints"
  echo "  report   [id] [--last N] [--status STATUS]  Sprint report (aggregate or single)"
  echo "  stats    [--last N] [--status STATUS]     Alias for report"
  exit 1
  ;;

esac
