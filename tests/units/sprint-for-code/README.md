# sprint-for-code 行为测试

测试 `SKILL.md` 的流程编排行为：

- 普通用例：只测 §4.1 信息确认阶段，给定 `desc` 和用户回复序列，校验最终 `stages` + `sequence`。
- Full-run 用例：在 §4.1 基础上模拟 §4.2-§4.4，校验规范化后的 handoff 结构是否正确。

不依赖 Anthropic SDK；评估通过 Claude Code subagent（Agent 工具）执行。

## 目录

```
tests/units/sprint-for-code/
  runner.py           # emit 提示词 / 比对结果
  <case-name>/
    input.json        # {desc, replies}
    expected.json     # {stages, sequence, handoff?}
```

## 运行流程

两步走，复刻历史 `tests/bench/judge.py` 模式（emit → subagent → check）。

```bash
# 1. 生成批量提示词
python3 tests/units/sprint-for-code/runner.py emit > /tmp/sprint-test-prompt.txt

# 2. 在 Claude Code 内调用 Agent 工具（subagent_type=general-purpose）：
#    "Read /tmp/sprint-test-prompt.txt, follow it, save JSON to /tmp/sprint-test-out.json"

# 3. 比对
python3 tests/units/sprint-for-code/runner.py check /tmp/sprint-test-out.json
```

单 case：

```bash
python3 tests/units/sprint-for-code/runner.py emit minimal
python3 tests/units/sprint-for-code/runner.py check /tmp/sprint-test-out.json minimal
```

## 生成 handoff 样例

Full-run 用例可以从 `expected.json` 渲染出真实 markdown handoff，便于人工验收：

```bash
python3 tests/units/sprint-for-code/runner.py render-handoff
python3 tests/units/sprint-for-code/runner.py render-handoff full-run-loop
```

输出目录：

```text
tests/units/sprint-for-code/.generated-handoffs/
```

正式自动化测试如果实际创建归档文件，应在断言后删除测试痕迹；当前 `render-handoff` 生成物是人工验收样例，先保留。

## 案例覆盖

| case | 行为路径 |
|---|---|
| minimal | 极简 desc + 用户首轮 yes |
| normal | 中等 desc + 用户首轮 yes |
| complex | 复杂 desc + 用户首轮 yes |
| adjust-stage | 中等 desc + 用户加 stage + yes |
| adjust-flow | 中等 desc + 用户关循环 + yes |
| full-run-sequential | 普通单 stage 执行 + handoff frontmatter/runtime/finalize |
| full-run-loop | `plan → loop(implement → verify)` 两轮退出 + round stage entries |
| full-run-parallel | `plan → parallel(implement) → verify` 多任务完成 + parallel runtime 清空 |
| full-run-adjustment | 用户调整后执行 + finalize 保留 `sequence_adjust_reason` |

## 加 case

新建 `<case-name>/` 目录，写 `input.json` 和 `expected.json`，无需改 runner。

Full-run 用例在 `input.json` 增加 `execution` 字段，使用固定 `sid/created/completed_at` 避免时间和文件系统不确定性。runner 期望 subagent 返回的 `handoff` 是规范化对象，不是 markdown 原文：

- `frontmatter`：`id/type/desc/sequence/created`
- `stage_entries`：按追加顺序记录 `number/stage/round/task/body`
- `runtime`：最终 `cursor/loop_active/parallel_completed`
- `finalize`：`status/completed_at/insight`
