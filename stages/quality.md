# quality

## Progress

- total: 3
- steps:
  1. Does it build and pass tests?
  2. Any custom checks needed?
  3. Did it break anything else?

Cross-task regression verification after execute. Single-task verification was done in execute.

## Hard Rules

No stage-specific rules. SKILL.md Hard Rules apply.

## Input

- execute handoff: files changed, test scope
- anchors.txt
- state.json: base_commit

---

## Step 1: Build & Test

Model: sonnet

Gate (always): 始终运行，不可跳过。

Detect build/test commands by priority:

1. **`.sprint.json`** — project-level config (highest priority)
2. **CLAUDE.md** — `build_cmd` / `test_cmd` (backward compatible)
3. **Auto-detect** — scan project root:

| Signal | Build | Test |
|--------|-------|------|
| Package.swift | `swift build` | `swift test` |
| package.json | `npm run build` | `npm test` |
| Cargo.toml | `cargo build` | `cargo test` |
| Makefile | `make` | `make test` |
| pyproject.toml | `pip install -e .` | `pytest` |
| go.mod | `go build ./...` | `go test ./...` |
| Gemfile | `bundle exec rake build` | `bundle exec rake test` |

Multiple detected → run all. Both must pass. Fail → return to execute.

## Step 1.5: Lint

Model: sonnet

Gate (auto): `.sprint.json` 中有 `lint` 字段 → 执行。否则跳过。

Run lint command from `.sprint.json`. Fail → return to execute.

## Step 2: Custom Scripts

Model: sonnet

Gate (auto): anchors.txt 存在或 `scripts/quality/*.sh` 非空 → 执行。否则跳过。

```bash
# [RUN] anchor check
[ -s ".sprint/{id}/anchors.txt" ] && bash "$ANCHOR_CHECK" "{sprint_id}" || echo "no anchors"
```

```bash
# [RUN] quality scripts
if [ -d scripts/quality ] && ls scripts/quality/*.sh 2>/dev/null | grep -q .; then
  for f in $(ls scripts/quality/*.sh | sort); do bash "$f" || exit 1; done
else
  echo "no quality scripts"
fi
```

All pass → Step 3. Any fail → return to execute.

## Step 3: Impact Verification

Model: opus

Gate (auto): plan handoff 任务数 >1 且任务间有共享文件或模块依赖 → 执行。否则跳过。

Do NOT repeat single-task checks from execute.

### 3a: Automated Analysis

1. **Public interface changes** — identify consuming modules for each changed API/protocol/type
2. **New dependencies** — verify acyclic dependency graph, lower modules don't depend on higher
3. **Deletions / renames** — scan for stale references

### 3b: Cross-Task Checklist

```
### Quality — PASS ✓ / FAIL ✗

**自动检查**
- Build: ✓ | Tests: {N} pass / 0 fail | Anchor: {N}/{N} ✓ | Custom scripts: {results}

**变更影响分析**
- 接口变更: {affected consumers or "无"}
- 依赖方向: ✓ / 发现违规
- 残留引用: 无 / {list}

**需要你确认**
- [ ] {task A × task B}: {interaction}
- [ ] {module boundary}: {interface}
- [ ] {end-to-end flow}: {what + how to check}
```

Confirmed → next stage.

---

## Completion

- Build + tests pass
- Custom scripts pass (or skipped)
- User confirmed cross-task impact

## Recovery

- Build/test fail → return to execute, fix, re-run from Step 1
- Anchor/script fail → return to execute, fix, re-run from Step 2
- Cross-task issue → return to execute, fix, re-run from Step 3
