## Summary
- Mode: Step-by-step（用户选 C，本轮只落 Task 1+2 完成版 + Task 3 骨架）
- Tasks completed: 3/7（Task 1 + Task 2 + Task 3 骨架；Task 4/5/6/7 推到后续 sprint）
- 决策变更：judge 方案由"Anthropic SDK"改为"Claude Code subagent"，移除 `MUST_CONTAIN pyproject.toml anthropic` anchor。

## Tasks

### Task 1: 单测骨架 + sprint-ctl 单测 — done
- Files: `tests/unit/helpers.bash`, `tests/unit/test_sprint_ctl.bats`, `Makefile`
- 动作：新建 helpers（XDG_DATA_HOME 隔离 + macOS realpath 对齐 + core.hooksPath=/dev/null 隔离用户全局 git hook）；新建 26 条 bats 断言覆盖 evaluate/create/activate/stage/end/list/report；新增 Makefile `test` target。

### Task 2: anchor-check 单测 — done
- Files: `tests/unit/test_anchor_check.bats`（+ helpers.bash 追加 make_sprint/write_anchors/set_base_commit 工具）
- 动作：33 条 bats 断言，覆盖全部 9 种 anchor 规则 × 2-3 用例（PASS/FAIL/边界），外加通用行为（空文件、注释跳过、metrics.log 写入、未知规则 UNKNOWN 输出）。

### Task 3: 基准 runner 骨架 + 1 fixture — done (骨架)
- Files: `tests/bench/pyproject.toml`, `tests/bench/runner.py`, `tests/bench/compare.py`（stub）, `tests/bench/judge.py`（prompt emitter）, `tests/bench/fixtures/simple-fix/input.yaml`
- 动作：runner 提供 list/show/prepare/capture/compare/judge 6 个子命令；judge 不调用 Anthropic API，改为生成结构化 prompt 交由 Claude Code subagent（Agent 工具，`general-purpose`）评分；compare 当前为最小 stub，drift 全量表留给 Task 4。

## Raw Observations

- `sprint-ctl evaluate` 参数为 `0/1` 位串（不是 `yes/no`）。SKILL.md 的 evaluate `[RUN]` section 内示例使用 `{clarify} {design} {risk}` 占位，初次调用误传 `yes yes no` 触发 `unbound variable` 报错（line 360）。SKILL.md 示例未显示 0/1 格式约束。
- macOS `mktemp -d` 返回 `/var/folders/...`，而 `git rev-parse --show-toplevel` 返回 `/private/var/folders/...`。sprint-ctl 用 git toplevel 构造 project_id，但测试 helper 若用 `mktemp` 直接路径，project_id 会不匹配，state.json 被写到另一处。需要 `pwd -P` 对齐。
- 用户的全局 git `core.hooksPath` 指向一个校验 commit 消息格式的 hook。临时测试仓沿用该 hook，`git commit --allow-empty -q -m "init"` 被 reject（"invalid commit message format"）。隔离方式：测试仓内 `git config core.hooksPath /dev/null`（不改全局）。
- `bats-core` 此前未装，brew 新装 1.13.0。
- `FILE_NOT_MODIFIED scripts/sprint-ctl.sh` 等 4 条 anchor 在 final check 时 FAIL，因为这些文件在 sprint base_commit（8c135c6）之前已处于 modified-but-uncommitted 状态，非本 sprint 工作范围产生。
- Task 3 `capture` 在无真实 sprint 运行的情况下 exit=3 "no sprint found"，符合骨架预期。
- Task 5 方案变更（用户指示）：不引入 `anthropic` SDK；judge 通过 Claude Code Agent 工具启动 subagent 完成；runner.judge 仅 emit prompt + artifact 路径。
- 本次改动全为新增文件（`tests/`、`Makefile`），未触碰 `scripts/*.sh` / `skills/sprint/*.md` / `stages/*.md` / `SKILL.md`。

## Open Questions

- 本 sprint anchors.txt 列了 12 条 `MUST_EXIST` 中 3 条（`tests/bench/fixtures/{design-heavy,doc-mode}/input.yaml`、`tests/README.md`）属 Task 6/7，当前 FAIL。后续 sprint 是否继承同一 anchors.txt，还是为后续 sprint 重新生成一份 anchors？
- fixture.replies 基于 stdout 子串匹配驱动 sprint，但 sprint 的用户提示文案在 stages 文件迭代时会漂移。驱动稳定性需要 Task 4 之后实测才能评估。
- 当前 replies 列表假设 `确认或调整` / `确认进入` / `anchor` 三个锚点能覆盖 simple-fix 流水线（plan+execute+insight），未实测是否够用。
- compare.py 是最小 stub（只检查 state 核心字段、handoff 文件名集合、metrics 事件计数）。Task 4 要补的完整 drift 表尚未实现，目前"PASS"信号强度低。
- judge prompt 目前写死 5 维；Task 5 推迟到后续 sprint 后，是否补 rubric 细节（每维 0-5 的锚点示例）以提高 subagent 评分一致性。

## Downstream (本 sprint 内 → insight stage)

- 对 Task 1 helpers 里的 macOS pwd -P / core.hooksPath=/dev/null 两个细节生成可跨 sprint 复用的经验（memory candidate）。
- judge 方案从 API → subagent 的转向，属于架构级决策变更，insight 需 sync 到项目 `.know/docs/` 或 memory。
- 剩余 4 个 task（Task 4 完整 compare / Task 5 judge 实测 / Task 6 fixture×2 + baselines / Task 7 入口收尾 + README + .gitignore）应作为 roadmap 项登记，由后续 sprint 消费。
- 本 sprint anchors.txt 中 3 条 Task 6/7 相关 `MUST_EXIST` + 1 条 `.gitignore MUST_CONTAIN` 是已知 FAIL，不是 regression。
