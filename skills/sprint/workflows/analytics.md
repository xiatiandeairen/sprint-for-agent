# Analytics — Cross-Project Sprint Analysis

> **Developer-only**. Not auto-loaded. Read this file when the user asks about cross-project stats, global trends, or the overall sprint footprint.

## Triggers

Read this file when the user's request contains any of:
- "全局 / 跨项目 / 所有项目"
- "global / across projects / cross-project"
- "stats / 统计 / 概况 / health"
- "花了多少时间 / how much time"
- Direct command `sprint-ctl --global {cmd}`

## Storage

- Global index: `$XDG_DATA_HOME/sprint/index.jsonl` (default `~/.local/share/sprint/index.jsonl`)
- One JSONL line per completed sprint
- Written on `sprint-ctl end` — appended automatically alongside the per-project `summary.json`

### Entry schema

```json
{
  "sprint_id": "YYYYMMDD-HHMMSS-RRR",
  "project_id": "-Users-taoxia-...",
  "project_path": "/Users/taoxia/...",
  "desc": "...",
  "type": "sprint",
  "status": "completed",
  "complexity": "low | medium | high",
  "duration": 1234,            // seconds, whole sprint
  "stages": {"brainstorm": 300, "plan": 60, ...},
  "anchor": {"pass": 9, "fail": 0, "skip": 0},
  "scope_creep": 0,            // files changed outside plan
  "tasks": {"completed": 3, "total": 3},
  "completed_at": "ISO 8601 UTC"
}
```

## Commands

### `sprint-ctl --global list [options]`

Recent sprints across all projects, newest first.

| Option | Default | Meaning |
|--------|---------|---------|
| `--limit N` | 20 | Number of rows |
| `--project {id}` | — | Filter by project_id substring (e.g. `sprint`, `work-R100`) |
| `--since YYYY-MM-DD` | — | Only sprints completed on/after this date |

Output columns: date / duration / project (truncated) / description.

### `sprint-ctl --global stats`

Per-project aggregate. Columns: project / count / total-time / avg / anchor-pass%.
Sorted by sprint count descending.

### `sprint-ctl --global report`

Overall health report:
- Total sprints + projects + time
- Average duration
- Anchor pass rate
- Count of long (>1h) and trivial (<2m) sprints
- Top 5 projects
- **Signals**: flagged when >30% trivial, >20% long, or <90% pass

## Use-case patterns

| Question | Command |
|----------|---------|
| "What did I do this week?" | `--global list --since $(date -v-7d +%Y-%m-%d)` |
| "Which project eats most time?" | `--global stats` |
| "Am I drowning in trivial sprints?" | `--global report` (check trivial count) |
| "Show all sprints on work project" | `--global list --project work --limit 50` |
| "Is anchor discipline dropping?" | `--global report` (anchor pass rate) |

## Interpreting signals

- **`>30% trivial sprints`**: users invoke sprint for changes too small to benefit. Suggests missing cheap-path; not a skill health issue per se.
- **`>20% long sprints (>1h)`**: scope control is weak — brainstorm/design likely膨胀. Consider reviewing which stages dominate.
- **`<90% anchor pass rate`**: plan-stage anchors are either too strict, too misaligned with real work, or execute phase is not verifying.
- **Same project high sprint count, low avg duration**: healthy iteration pattern.
- **Project with 1 sprint, very long duration**: likely abandoned mid-way OR one-off massive refactor.

## Integration notes

- Read-only. Never write to index.jsonl from this workflow.
- If index is missing → print "Global index not found"; do not error out or recreate.
- Per-project `summary.json` and global `index.jsonl` must agree; if they drift, trust the per-project file and rebuild by concatenation.
- These commands do NOT appear in `sprint-ctl` main help; they are visible only via `--global` bare invocation.
