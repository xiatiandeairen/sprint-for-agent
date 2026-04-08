---
name: todo
description: Lightweight task executor. Run tasks immediately, resume deferred sprints, or manage triggers. Use when asked to "todo", "do this", "run this plan", or to resume a saved sprint.
---

# Todo

`/todo {description or sprint_id or plan_path}` → route intent → execute or schedule.

## Rules

- Bash commands marked `# [RUN]` must be executed with Bash tool.
- `[TASK] xxx` triggers TaskCreate. Mark TaskUpdate completed when done.
- Wait for user at `[STOP:confirm]` and `[STOP:choose]` per sprint conventions.
- Match user's language. Chinese → Chinese. English → English.
- Script paths: Set `SPRINT_BASE` from "Base directory for this skill: {path}" — navigate up two levels from `skills/todo/` to reach plugin root. `SPRINT_CTL="$SPRINT_BASE/scripts/sprint-ctl.sh"`, `ANCHOR_CHECK="$SPRINT_BASE/scripts/anchor-check.sh"`.

---

## Intent Routing

Parse user input and route to the correct mode:

```
/todo {input}

1. Is input a sprint ID (matches pattern YYYYMMDD-HHMMSS-NNN)?
   → Resume mode

2. Is input a file path ending in .md that exists?
   → Plan-driven mode

3. Does input contain time signals?
   ("明天", "下周", "tonight", "at 10am", ISO datetime, etc.)
   → Deferred mode

4. Does input contain deferral signals?
   ("记下", "待办", "之后做", "save", "later", "remind me")
   → Deferred mode (manual trigger)

5. Otherwise
   → Immediate mode
```

---

## Resume Mode

Resume a deferred or interrupted sprint.

### Step 1: Load context

```bash
# [RUN]
cat .sprint/{id}/state.json
```

Read `state.json` to get:
- `stages`: the full stage list
- `current_stage`: where it stopped

### Step 2: Build upstream context

Read all completed handoffs in stage order:
```
.sprint/{id}/handoffs/brainstorm.md  (if exists)
.sprint/{id}/handoffs/design.md      (if exists)
.sprint/{id}/handoffs/plan.md        (if exists)
```

Also read:
```
.sprint/{id}/anchors.txt
```

These handoffs ARE the context. No transformation needed.

### Step 3: Determine resume point

Find the first stage in `stages` that has no `stage_end` entry in `metrics.log`. That is the resume stage.

### Step 4: Execute

Continue the sprint pipeline from the resume stage. For each remaining stage:
1. Read the stage file from `$SPRINT_BASE/stages/{stage}.md`
2. Execute per stage instructions
3. Write handoff, update metrics

### Step 5: Clean trigger

After execution completes, remove the trigger entry from `.sprint/triggers.json` (if one exists for this sprint).

---

## Plan-driven Mode

Execute from an existing plan document.

### Step 1: Read plan

Read the plan file at the given path. Validate it has actionable content (steps, tasks, or checklist).

### Step 2: Create sprint

```bash
# [RUN]
bash "$SPRINT_CTL" create "todo" "{desc_from_plan_title}" "execute,insight"
bash "$SPRINT_CTL" activate "{id}"
```

### Step 3: Execute

Treat the plan document as the plan handoff. Enter execute stage directly:
- Read `$SPRINT_BASE/stages/execute.md`
- Use step-by-step mode
- Each section/step in the plan becomes a task

### Step 4: Complete

```bash
# [RUN]
bash "$SPRINT_CTL" end "{id}"
```

---

## Immediate Mode

Lightweight single-task execution.

### Step 1: Assess

Quick assessment — is this a one-liner or multi-step?
- One-liner: skip sprint tracking, just do it, report result.
- Multi-step: create sprint and track.

### Step 2: Execute (multi-step)

```bash
# [RUN]
bash "$SPRINT_CTL" create "todo" "{english_desc}" "execute,insight"
bash "$SPRINT_CTL" activate "{id}"
```

Execute directly:
- Break into tasks
- TaskCreate per task
- Execute each, TaskUpdate completed
- Anchor check if applicable

### Step 3: Complete

```bash
# [RUN]
bash "$SPRINT_CTL" end "{id}"
```

---

## Deferred Mode

Save plan and set up a trigger for later execution.

### Step 1: Determine trigger type

From user input:
- Time signal present → `at` trigger. Parse the time to ISO 8601.
- Sprint ID referenced → `after` trigger.
- Deferral signal only → `manual` trigger.

If ambiguous, ask:

```
When should this run?

A) At a specific time — tell me when
B) After sprint {recent_id} completes
C) Manual — run /todo {id} when ready
```

[STOP:choose]

### Step 2: Create sprint with plan stages

If the task needs planning:
```bash
# [RUN]
bash "$SPRINT_CTL" create "todo" "{english_desc}" "plan,execute,insight"
bash "$SPRINT_CTL" activate "{id}"
```

Run plan stage now (so context is captured while the conversation is active), then defer execute.

If the task is already well-defined (user described concrete steps):
```bash
# [RUN]
bash "$SPRINT_CTL" create "todo" "{english_desc}" "execute,insight"
bash "$SPRINT_CTL" activate "{id}"
```

Write the user's description as `.sprint/{id}/handoffs/plan.md` directly.

### Step 3: Write trigger

Read or initialize `.sprint/triggers.json`:

```bash
# [RUN] initialize if not exists
[[ -f .sprint/triggers.json ]] || echo '[]' > .sprint/triggers.json
```

Append trigger entry:

```python
# [RUN]
python3 -c "
import json
with open('.sprint/triggers.json') as f:
    triggers = json.load(f)
triggers.append({
    'sprint_id': '{id}',
    'type': '{at|after|manual}',
    'spec': '{ISO time or sprint id or null}',
    'resume_stage': 'execute',
    'created_at': '{ISO timestamp}'
})
with open('.sprint/triggers.json', 'w') as f:
    json.dump(triggers, f, indent=2)
"
```

### Step 4: Set up trigger mechanism

**For `at` triggers:**

Create macOS launchd plist:

```bash
# [RUN]
cat > ~/Library/LaunchAgents/com.loppy.trigger-{id}.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.loppy.trigger-{id}</string>
    <key>ProgramArguments</key>
    <array>
        <string>claude</string>
        <string>-p</string>
        <string>/todo {id}</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Year</key><integer>{year}</integer>
        <key>Month</key><integer>{month}</integer>
        <key>Day</key><integer>{day}</integer>
        <key>Hour</key><integer>{hour}</integer>
        <key>Minute</key><integer>{minute}</integer>
    </dict>
    <key>WorkingDirectory</key>
    <string>{project_root}</string>
</dict>
</plist>
PLIST
launchctl load ~/Library/LaunchAgents/com.loppy.trigger-{id}.plist
```

If in an active session, also mention user can use `/loop` to poll.

**For `after` triggers:**
No extra setup. `sprint-ctl.sh end` automatically checks triggers.json.

**For `manual` triggers:**
No extra setup.

### Step 5: Confirm

```
> Sprint #{id} saved. Trigger: {type}
> {type=at}: scheduled for {time}. launchd plist installed.
> {type=after}: will trigger when sprint {spec} completes.
> {type=manual}: run /todo {id} when ready.
```

---

## Trigger Management

### /todo list

Show all pending triggers:

```bash
# [RUN]
cat .sprint/triggers.json 2>/dev/null || echo "No triggers."
```

Format as table:
```
| Sprint ID | Type | Spec | Resume Stage | Created |
|-----------|------|------|-------------|---------|
```

### /todo cancel {id}

Remove a trigger and its launchd plist (if any):

```bash
# [RUN]
python3 -c "
import json
with open('.sprint/triggers.json') as f:
    triggers = json.load(f)
triggers = [t for t in triggers if t['sprint_id'] != '{id}']
with open('.sprint/triggers.json', 'w') as f:
    json.dump(triggers, f, indent=2)
"
# Remove launchd plist if exists
launchctl unload ~/Library/LaunchAgents/com.loppy.trigger-{id}.plist 2>/dev/null || true
rm -f ~/Library/LaunchAgents/com.loppy.trigger-{id}.plist
```
