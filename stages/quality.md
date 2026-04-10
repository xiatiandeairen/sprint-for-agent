# quality

## Progress

- total: 3
- steps:
  1. 构建和测试验证
  2. 自定义检查
  3. 跨任务影响检查

Integration verification after execute completes. Focuses on **cross-task regression** — single-task verification was already done in execute.

## Input

- execute handoff: files changed, test scope
- anchors.txt
- state.json: base_commit

---

## Step 1: Detect Build & Test

**First**: check if CLAUDE.md defines build/test commands. If yes, use those directly — skip scanning.

Only if CLAUDE.md has no build/test commands defined, scan project root for toolchain signals:

| Signal | Build command | Test command |
|--------|-------------|-------------|
| Package.swift | `swift build` | `swift test` |
| package.json | `npm run build` / `bun run build` | `npm test` / `bun test` |
| Cargo.toml | `cargo build` | `cargo test` |
| Makefile | `make` | `make test` |
| pyproject.toml / setup.py | `pip install -e .` | `pytest` |
| go.mod | `go build ./...` | `go test ./...` |
| Gemfile | `bundle exec rake build` | `bundle exec rake test` |

If multiple detected (e.g. monorepo), run all relevant ones.

Run detected build command, then test command. Both must pass before Step 2.

Fail → return to execute to fix.

## Step 2: Custom Scripts

Gate: 自动检测 — anchors.txt 存在或 scripts/quality/*.sh 目录非空时执行，否则跳过。

Run project-specific quality scripts from convention directory:

```bash
# [RUN] anchor check (if anchors exist)
[ -s ".sprint/{id}/anchors.txt" ] && bash "$ANCHOR_CHECK" "{sprint_id}" || echo "no anchors"
```

```bash
# [RUN] scripts/quality/*.sh — execute all .sh files in alphabetical order
if [ -d scripts/quality ] && ls scripts/quality/*.sh 2>/dev/null | grep -q .; then
  for f in $(ls scripts/quality/*.sh | sort); do bash "$f" || exit 1; done
else
  echo "no quality scripts"
fi
```

All pass → Step 3. Any fail → return to execute to fix.

## Step 3: Impact Verification

Gate: sprint 是否包含多个任务且任务间有文件交叉？

💡 如果只有单个任务，跳过跨任务影响检查。如果多个任务修改了相关联的文件或模块，需要验证交叉影响。

Focuses on **cross-task integration** only. Do NOT repeat single-task checks from execute.

### 3a: Automated Change Impact Analysis

Based on files changed in execute handoff, analyze:

1. **Public interface changes** — identify consuming modules for each changed public API/protocol/type
2. **New dependencies** — verify they don't violate module dependency direction (dependency graph must remain acyclic, lower-level modules must not depend on higher-level)
3. **Deletions / renames** — scan for stale references across the codebase

Present findings before the manual checklist.

### 3b: Manual Cross-Task Checklist

Generate checklist covering:
- **Task interactions**: do changes in task A break assumptions in task B?
- **Module boundary integrity**: do cross-module interfaces still work end-to-end?
- **End-to-end flow**: does the full user-facing flow still work?

```
### Quality — PASS ✓

**自动检查**
- Build: ✓
- Tests: {N} pass / 0 fail
- Anchor: {N}/{N} ✓ (or: skipped)
- Custom scripts: {results}

**变更影响分析**
- 接口变更: {list affected consumers, or "无"}
- 依赖方向: ✓ (or: 发现违规)
- 残留引用: 无 (or: {list})

**需要你确认**
- [ ] {task A × task B}: {interaction to verify}
- [ ] {module boundary}: {interface to verify}
- [ ] {end-to-end flow}: {what to check, how to check}

---
```

Wait for user to confirm all checks pass. Confirmed → next stage.

---

## Completion

- Build passes (CLAUDE.md commands or auto-detected toolchain)
- Tests pass
- Custom scripts pass (or skipped if `scripts/quality/` is absent or empty)
- User confirmed cross-task impact verification

## Recovery

- Build/test fail → execute fixes
- User finds issue in impact check → execute fixes, re-run quality
