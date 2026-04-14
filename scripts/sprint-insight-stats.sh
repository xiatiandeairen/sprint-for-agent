#!/usr/bin/env bash
# sprint-insight-stats.sh — Historical comparison for insight stage
# Usage: sprint-insight-stats.sh <current_sprint_id>
# Outputs a comparison table: this sprint vs historical average

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SPRINT_DIR="$ROOT/.sprint"
CURRENT_ID="${1:-}"

if [[ -z "$CURRENT_ID" ]]; then
  echo "Usage: sprint-insight-stats.sh <current_sprint_id>" >&2
  exit 1
fi

python3 -c "
import json, os, re, sys

sprint_dir = '$SPRINT_DIR'
current_id = '$CURRENT_ID'

def parse_sprint(name):
    base = os.path.join(sprint_dir, name)
    state_path = os.path.join(base, 'state.json')
    metrics_path = os.path.join(base, 'metrics.log')
    exec_path = os.path.join(base, 'handoffs', 'execute.md')

    if not os.path.isfile(state_path):
        return None

    try:
        state = json.load(open(state_path))
    except (json.JSONDecodeError, IOError):
        return None

    if state.get('status') != 'completed':
        return None

    data = {'id': name, 'duration': None, 'anchor_pass': 0, 'anchor_total': 0, 'tasks_done': 0, 'tasks_total': 0}

    # Parse metrics.log
    if os.path.isfile(metrics_path):
        start_ts = end_ts = None
        with open(metrics_path) as f:
            for line in f:
                parts = line.strip().split('|')
                if not parts:
                    continue
                if parts[0] == 'sprint_start' and len(parts) >= 3:
                    start_ts = int(parts[2])
                elif parts[0] == 'sprint_end' and len(parts) >= 3:
                    end_ts = int(parts[2])
                elif parts[0] == 'anchor_check' and len(parts) >= 4:
                    for p in parts[2:]:
                        if p.startswith('pass='):
                            data['anchor_pass'] += int(p.split('=')[1])
                            data['anchor_total'] += int(p.split('=')[1])
                        elif p.startswith('fail='):
                            data['anchor_total'] += int(p.split('=')[1])
        if start_ts and end_ts:
            data['duration'] = end_ts - start_ts

    # Parse execute handoff
    if os.path.isfile(exec_path):
        with open(exec_path) as f:
            content = f.read()
        m = re.search(r'Tasks completed:\s*(\d+)/(\d+)', content)
        if m:
            data['tasks_done'] = int(m.group(1))
            data['tasks_total'] = int(m.group(2))

    return data

# Collect all completed sprints
current = None
historical = []

for name in sorted(os.listdir(sprint_dir)):
    if not os.path.isdir(os.path.join(sprint_dir, name)):
        continue
    d = parse_sprint(name)
    if d is None:
        continue
    if name.startswith(current_id):
        current = d
    else:
        historical.append(d)

if current is None:
    print('(no data for current sprint)')
    sys.exit(0)

if len(historical) < 2:
    print('(historical data insufficient, need >= 2 completed sprints)')
    sys.exit(0)

# Calculate historical averages
hist_durations = [h['duration'] for h in historical if h['duration'] is not None]
hist_avg_dur = sum(hist_durations) // len(hist_durations) if hist_durations else None

hist_anchor_pass = sum(h['anchor_pass'] for h in historical)
hist_anchor_total = sum(h['anchor_total'] for h in historical)

hist_tasks_done = sum(h['tasks_done'] for h in historical)
hist_tasks_total = sum(h['tasks_total'] for h in historical)

def trend(current_val, hist_val, higher_is_better=True):
    if current_val is None or hist_val is None or hist_val == 0:
        return '—'
    diff_pct = abs(current_val - hist_val) * 100 / hist_val
    if diff_pct < 5:
        return '='
    if higher_is_better:
        return '↑' if current_val > hist_val else '↓'
    else:
        return '↑' if current_val < hist_val else '↓'

def fmt_min(seconds):
    if seconds is None:
        return 'N/A'
    return f'{seconds // 60}m'

def fmt_pct(num, den):
    if den == 0:
        return 'N/A'
    return f'{num * 100 // den}%'

# Output
print(f'### Historical Comparison ({len(historical)} sprints)')
print()
print('| 指标 | 本次 | 历史平均 | 趋势 |')
print('|------|------|---------|------|')

# Duration (lower is better)
cur_dur = current['duration']
print(f'| 总耗时 | {fmt_min(cur_dur)} | {fmt_min(hist_avg_dur)} | {trend(cur_dur, hist_avg_dur, higher_is_better=False)} |')

# Anchor pass rate (higher is better)
cur_anchor_pct = (current['anchor_pass'] * 100 // current['anchor_total']) if current['anchor_total'] > 0 else None
hist_anchor_pct = (hist_anchor_pass * 100 // hist_anchor_total) if hist_anchor_total > 0 else None
cur_anchor_str = fmt_pct(current['anchor_pass'], current['anchor_total'])
hist_anchor_str = fmt_pct(hist_anchor_pass, hist_anchor_total)
print(f'| Anchor 通过率 | {cur_anchor_str} | {hist_anchor_str} | {trend(cur_anchor_pct, hist_anchor_pct)} |')

# Task completion rate (higher is better)
cur_task_pct = (current['tasks_done'] * 100 // current['tasks_total']) if current['tasks_total'] > 0 else None
hist_task_pct = (hist_tasks_done * 100 // hist_tasks_total) if hist_tasks_total > 0 else None
cur_task_str = fmt_pct(current['tasks_done'], current['tasks_total'])
hist_task_str = fmt_pct(hist_tasks_done, hist_tasks_total)
print(f'| Task 完成率 | {cur_task_str} | {hist_task_str} | {trend(cur_task_pct, hist_task_pct)} |')
"
