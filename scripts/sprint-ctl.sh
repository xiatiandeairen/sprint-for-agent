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
  # Usage: sprint-ctl.sh evaluate <goal_clarity> <scope_size> <risk_level> <validation_difficulty> [keywords...]
  # Input: 4 dimensions (0-2 each)
  # Output: 4 decisions + stage list
  GC="${1:-0}"; SS="${2:-0}"; RL="${3:-0}"; VD="${4:-0}"
  shift 4 2>/dev/null || true
  KEYWORDS="$*"

  # ── Rule-based scoring ──

  # clarify (→ brainstorm)
  if [[ $GC -eq 2 ]]; then CLARIFY=2
  elif [[ $GC -eq 1 ]] || [[ $VD -eq 2 ]]; then CLARIFY=1
  else CLARIFY=0; fi

  # design (→ design)
  if [[ $SS -eq 2 ]] || [[ $RL -eq 2 ]]; then DESIGN=2
  elif [[ $SS -eq 1 ]] || [[ $GC -eq 1 ]]; then DESIGN=1
  else DESIGN=0; fi

  # plan (→ plan)
  if [[ $SS -eq 2 ]]; then PLAN=2
  elif [[ $SS -eq 1 ]] || [[ $RL -eq 1 ]]; then PLAN=1
  else PLAN=0; fi

  # guardrail (→ quality + review)
  if [[ $RL -eq 2 ]]; then GUARDRAIL=2
  elif [[ $RL -eq 1 ]] || [[ $VD -eq 2 ]]; then GUARDRAIL=1
  else GUARDRAIL=0; fi

  # ── Keyword overrides (兜底规则) ──
  for kw in $KEYWORDS; do
    case "$kw" in
      delete|migrate|migration|payment|production|permission|数据|删除|迁移|权限|支付|生产)
        RL=2; GUARDRAIL=2 ;;
      optimize|explore|research|优化|看看|研究|感觉)
        [[ $CLARIFY -lt 1 ]] && CLARIFY=1 ;;
      system|architecture|权限体系|系统|架构)
        [[ $DESIGN -lt 1 ]] && DESIGN=1
        [[ $PLAN -lt 1 ]] && PLAN=1 ;;
    esac
  done

  # ── Build stage list ──
  STAGES=""
  [[ $CLARIFY -ge 1 ]] && STAGES="brainstorm"
  [[ $DESIGN -ge 1 ]] && STAGES="${STAGES:+$STAGES,}design"
  STAGES="${STAGES:+$STAGES,}plan,execute"
  [[ $GUARDRAIL -ge 1 ]] && STAGES="${STAGES},quality"
  [[ $GUARDRAIL -ge 2 ]] && STAGES="${STAGES},review"
  STAGES="${STAGES},insight"

  # ── Output ──
  echo "INPUT"
  echo "  goal_clarity=$GC  scope_size=$SS  risk_level=$RL  validation_difficulty=$VD"
  [[ -n "$KEYWORDS" ]] && echo "  keywords: $KEYWORDS"
  echo ""
  echo "DECISION"
  echo "  clarify=$CLARIFY  design=$DESIGN  plan=$PLAN  guardrail=$GUARDRAIL"
  echo ""
  echo "STAGES"
  echo "  $STAGES"
  echo ""

  # Stage details with reasoning
  echo "DETAIL"

  # brainstorm
  if [[ $CLARIFY -eq 0 ]]; then
    echo "  brainstorm  SKIP       goal_clarity=${GC}(clear), validation_difficulty=${VD}(easy)"
  elif [[ $CLARIFY -eq 1 ]]; then
    if [[ $GC -eq 1 ]]; then
      echo "  brainstorm  level=1  light-align    goal_clarity=1(directional but not specific)"
    else
      echo "  brainstorm  level=1  light-align    validation_difficulty=2(hard to verify, clarify goal first)"
    fi
  else
    echo "  brainstorm  level=2  deep-explore   goal_clarity=2(vague, needs exploration)"
  fi

  # design
  if [[ $DESIGN -eq 0 ]]; then
    echo "  design      SKIP       scope_size=${SS}(small), risk_level=${RL}(low), goal_clarity=${GC}(clear)"
  elif [[ $DESIGN -eq 2 ]]; then
    if [[ $SS -eq 2 ]]; then
      echo "  design      level=2  research+model scope_size=2(system-wide, needs full design)"
    else
      echo "  design      level=2  research+model risk_level=2(high-risk, needs thorough research)"
    fi
  else
    if [[ $SS -eq 1 ]]; then
      echo "  design      level=1  quick-design   scope_size=1(module-level change)"
    else
      echo "  design      level=1  quick-design   goal_clarity=1(directional, needs concrete plan)"
    fi
  fi

  # plan
  if [[ $PLAN -eq 0 ]]; then
    echo "  plan        level=0  minimal        scope_size=0(point change), risk_level=0(low)"
  elif [[ $PLAN -eq 2 ]]; then
    echo "  plan        level=2  tasks+deps+anchor  scope_size=2(system-wide, needs dependency orchestration)"
  else
    if [[ $SS -eq 1 ]]; then
      echo "  plan        level=1  split-tasks    scope_size=1(module-level, needs step breakdown)"
    else
      echo "  plan        level=1  split-tasks    risk_level=1(medium risk, needs controlled steps)"
    fi
  fi

  # execute
  echo "  execute     ALWAYS"

  # quality
  if [[ $GUARDRAIL -eq 0 ]]; then
    echo "  quality     SKIP       risk_level=${RL}(low), validation_difficulty=${VD}(easy)"
  elif [[ $GUARDRAIL -eq 2 ]]; then
    echo "  quality     level=2  full-verify    risk_level=2(high-risk, needs comprehensive check)"
  else
    if [[ $RL -eq 1 ]]; then
      echo "  quality     level=1  basic-verify   risk_level=1(medium risk)"
    else
      echo "  quality     level=1  basic-verify   validation_difficulty=2(hard to verify, needs tooling)"
    fi
  fi

  # review
  if [[ $GUARDRAIL -ge 2 ]]; then
    echo "  review      level=2  required       guardrail=2(high-risk decisions need human review)"
  else
    echo "  review      SKIP       guardrail=${GUARDRAIL}(risk manageable, no review needed)"
  fi

  # insight
  echo "  insight     ALWAYS"
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
  echo "Usage: sprint-ctl.sh <command> [args]"
  echo "  evaluate <gc> <ss> <rl> <vd> [keywords]  Evaluate task dimensions"
  echo "  create   <type> <desc> <stages>           Create sprint"
  echo "  activate <id>                             Activate sprint"
  echo "  stage    <id> <stage> <status>            Update stage status"
  echo "  end      <id>                             Complete sprint"
  echo "  list                                      List sprints"
  exit 1
  ;;

esac
