<!--
OPERATION: init
USED-BY: SKILL §4.2 step 1
TARGET: 全文（新建）
ACTION: 写入下方代码块，替换 {PLACEHOLDER}；section 标记保留原样
PLACEHOLDERS:
  {SID}          sprint id（§3 SPRINT_SID）
  {DESC}         用户输入 desc
  {SEQUENCE}     完整真实执行语法
  {CREATED}      ISO8601 UTC 创建时刻
  {SEQUENCE_ADJUST_REASON_LINE}  sequence 调整原因整行；有调整时写 `  sequence_adjust_reason: 加 challenge — 需要反证关键结论`；无调整时整行省略
-->

```
---
id: {SID}
type: sprint-for-analysis
desc: {DESC}
sequence: {SEQUENCE}
created: {CREATED}
---

# Analysis Sprint Handoff — {DESC}

## Stages
<!-- SECTION: stages -->
<!-- /SECTION: stages -->

## Runtime
<!-- SECTION: runtime -->
cursor:
loop:
  active:
parallel:
  completed: []
<!-- /SECTION: runtime -->

## Finalize
<!-- SECTION: finalize -->
status: running
completed_at:
insight:
<!-- /SECTION: finalize -->
```

<!--
OPERATION: append_stage
USED-BY: SKILL §4.3 stage completed
TARGET: SECTION stages
ACTION: 在 `<!-- /SECTION: stages -->` 之前插入下方代码块
PLACEHOLDERS:
  {N}             章节累积序号（§3 SPRINT_N）
  {STAGE}         当前 stage 名
  {ROUND_SUFFIX}  循环内附 " (round k)"；非循环留空
  {TASK_SUFFIX}   并行轨道内附 " (track: {track_name})"；非并行留空
  {BODY}          stage 文件定义的主体
-->

```
### {N}. {STAGE}{ROUND_SUFFIX}{TASK_SUFFIX}
<!-- ts: {"at":"{TS}"} -->

{BODY}
```

<!--
OPERATION: replace_runtime
USED-BY: SKILL §4.3 runtime updated
TARGET: SECTION runtime
ACTION: 用下方代码块整体替换 `SECTION: runtime` 与 `/SECTION: runtime` 之间的内容
PLACEHOLDERS:
  {CURSOR}       当前执行单元；普通 stage 写英文 stage 名，loop 写 `loop()`，parallel 写 `parallel()`
  {LOOP_ACTIVE}  当前 loop 内执行的 stage 名；非 loop 留空
  {COMPLETED}    parallel 已完成轨道列表；YAML 行内数组，如 `[]` 或 `[option-a, option-b]`
-->

```
cursor: {CURSOR}
loop:
  active: {LOOP_ACTIVE}
parallel:
  completed: {COMPLETED}
```

<!--
OPERATION: replace_finalize
USED-BY: SKILL §4.4 finalize
TARGET: SECTION finalize
ACTION: 用下方代码块整体替换 `SECTION: finalize` 与 `/SECTION: finalize` 之间的内容
PLACEHOLDERS:
  {STATUS}                  completed / completed_with_limits / aborted
  {COMPLETED_AT}            ISO8601 UTC 完成时刻
  {INSIGHT_BODY}            insight 其余内容；无则留空；多行时按 YAML block 缩进
  {SEQUENCE_ADJUST_REASON_LINE}  sequence 调整原因整行；有调整时写 `  sequence_adjust_reason: 加 challenge — 需要反证关键结论`；无调整时整行省略
-->

```
status: {STATUS}
completed_at: {COMPLETED_AT}
insight:
{SEQUENCE_ADJUST_REASON_LINE}
{INSIGHT_BODY}
```
