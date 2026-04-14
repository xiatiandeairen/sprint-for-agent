---
name: todo
description: Lightweight task executor. Run tasks immediately, resume deferred sprints, or manage triggers. Use when asked to "todo", "do this", "run this plan", or to resume a saved sprint.
---

# Todo

`/todo {description or sprint_id or plan_path}` → route intent → execute or schedule.

## Rules

- All Rules and Hard Rules from sprint SKILL.md apply.
- 1 file + <20 lines change → execute directly without sprint tracking.
- Script paths: From "Base directory for this skill: {path}", strip `skills/todo/` to get project root. `SPRINT_CTL="{project_root}/scripts/sprint-ctl.sh"`, `ANCHOR_CHECK="{project_root}/scripts/anchor-check.sh"`.

## Default Behaviors

| Situation | Default |
|-----------|---------|
| Input matches no routing pattern | Immediate mode. |
| Input is ambiguous between two modes | Ask user: "Do you want to run this now or save it for later?" |
| One-liner assessment borderline (1 file, ~20 lines) | Treat as one-liner. Err toward less tracking. |
| Trigger time is in the past | Report error: "Time is in the past. Enter a future time." |
| `.sprint/triggers.json` missing or malformed | Initialize as `[]` and continue. |
| Resume target sprint has no incomplete stages | Report "Sprint already completed" and stop. |

## Input Normalization

| Input pattern | Route |
|---------------|-------|
| `YYYYMMDD-HHMMSS-NNN` | Resume mode |
| Path ending `.md` that exists on disk | Plan-driven mode |
| Contains time words (明天, tonight, at 10am, ISO datetime) | Deferred mode (at) |
| Contains deferral words (记下, later, save, remind) | Deferred mode (manual) |
| `list` | Trigger management: list |
| `cancel {id}` | Trigger management: cancel |
| Everything else | Immediate mode |

## Workflow

### Intent Routing

```
/todo {input}
1. Matches YYYYMMDD-HHMMSS-NNN?       → Resume mode
2. .md file path that exists?          → Plan-driven mode
3. Time signals (明天, tonight, at 10am)? → Deferred mode
4. Deferral signals (记下, later, save)?  → Deferred mode (manual)
5. Otherwise                           → Immediate mode
```

### Resume Mode

1. Read `.sprint/{id}/state.json` → get `stages`, `current_stage`
2. Read completed handoffs in stage order + `anchors.txt` for context
3. Find first stage without `stage_end` in `metrics.log` → resume point
4. Continue pipeline from resume stage, executing each remaining stage normally
5. Remove trigger entry from `.sprint/triggers.json` if exists

### Plan-driven Mode

1. Read plan file, validate actionable content
2. Create sprint:
   ```bash
   # [RUN]
   bash "$SPRINT_CTL" create "todo" "{desc_from_plan_title}" "execute,insight"
   bash "$SPRINT_CTL" activate "{id}"
   ```
3. Treat plan document as plan handoff → enter execute stage directly
4. `bash "$SPRINT_CTL" end "{id}"`

### Immediate Mode

**One-liner** (1 file, <20 lines): skip tracking, execute, report result.

**Multi-step:**
```bash
# [RUN]
bash "$SPRINT_CTL" create "todo" "{english_desc}" "execute,insight"
bash "$SPRINT_CTL" activate "{id}"
```
Break into tasks → TaskCreate per task → execute → anchor check → `bash "$SPRINT_CTL" end "{id}"`.

### Deferred Mode

**1. Determine trigger type:**

| Signal | Type | Spec |
|--------|------|------|
| Time present | `at` | ISO 8601 datetime |
| Sprint ID referenced | `after` | sprint ID |
| Deferral only | `manual` | null |

Ambiguous → ask: A) Specific time B) After sprint {recent_id} C) Manual.

**2. Create sprint:**

- Needs planning → stages `plan,execute,insight`, run plan now, defer execute.
- Already well-defined → stages `execute,insight`, write description as `plan.md` directly.

```bash
# [RUN]
bash "$SPRINT_CTL" create "todo" "{english_desc}" "{stages}"
bash "$SPRINT_CTL" activate "{id}"
```

**3. Write trigger** to `.sprint/triggers.json`:

```json
{
  "sprint_id": "{id}",
  "type": "{at|after|manual}",
  "spec": "{ISO time or sprint id or null}",
  "resume_stage": "execute",
  "created_at": "{ISO timestamp}"
}
```

**4. Set up mechanism:**

| Type | Setup |
|------|-------|
| `at` | Create macOS launchd plist at `~/Library/LaunchAgents/com.loppy.trigger-{id}.plist` with `claude -p "/todo {id}"`, load with `launchctl load` |
| `after` | No setup — `sprint-ctl.sh end` checks triggers.json |
| `manual` | No setup — user runs `/todo {id}` |

**5. Confirm:**
```
> Sprint #{id} saved. Trigger: {type}
> {at}: scheduled for {time}. launchd plist installed.
> {after}: triggers when sprint {spec} completes.
> {manual}: run /todo {id} when ready.
```

## Trigger Management

**`/todo list`**: Read `.sprint/triggers.json`, display as table (Sprint ID | Type | Spec | Resume Stage | Created).

**`/todo cancel {id}`**: Remove from `triggers.json` + unload/delete launchd plist if exists.
