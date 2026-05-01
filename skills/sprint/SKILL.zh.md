---
name: sprint
description: 任务执行工作流，支持托管模式（--auto）。评估、裁剪阶段、按步执行、锚点验证、原则自检。
---

# Sprint

`/sprint {描述}` → 评估 → 裁剪阶段 → 执行流水线。

## 1. 流水线

```
/sprint {描述}
    → 评估（§1.1）→ Q1-Q5 → 用户确认
    → 命令调用（§1.3）→ sprint-ctl evaluate / create / activate
    → 阶段循环（§1.4）→ 每阶段：running → 执行 → 写 handoff → completed
    → sprint 结束（§1.5）→ sprint-ctl end → insight 关闭
```

### 1.1 评估

通过问题判读哪些环节需要。每个可选 stage 一个问题。

**Stage 选择问题（Q1-Q4）**：

| 问题 | yes | no | 提示 |
|------|-----|-----|------|
| Q1 需求是否需要澄清？ | brainstorm | skip | 一句话能说清 → 不需要 |
| Q2 是否需要技术设计？ | design | skip | 实现方式唯一且明确 → 不需要 |
| Q3 是否纯文档任务（无代码改动）？ | doc=yes（跳 plan + 无锚点） | 默认 | prd / tech 文档 / roadmap → yes |
| Q4 是否涉及高风险？ | review | skip | 局部可逆、不影响线上 → 跳过 |

- 关键词覆盖 `delete/migrate/payment/production/permission` → Q4=yes 自动触发（安全网，避免漏勾）
- 始终启用：execute、insight
- plan：Q3=no 时启用；Q3=yes（Doc 模式）跳过
- review：Q4=yes 或（tasks>1 且跨模块）

**Q5（模式选择，仅当未传 `--auto`）**：

| 问题 | yes | no | 提示 |
|------|-----|-----|------|
| Q5 是否启用托管模式？ | auto=1 | auto=0（默认） | 启用后核心决策点由原则自检推进，你只在开始与最终汇总时介入 |

详见 §4。

**评估输出模板**：

```
### 评估: {描述}
- **类型**: {普通任务 | 文档任务}
- **流水线**: {stages}
- **跳过**: {stages} — {理由}
```

**HINTS**：从 `summary.json` 检测到趋势 / 异常时附 `HINTS` section。**有则呈现，无则不提**。

```
HINTS (44 sprints)
  [趋势] duration 连续上升: 26m → 41m → 88m
  [异常] 上次 scope creep 2 files，历史平均 0 files
```

### 1.2 阶段路由

| 阶段 | 文件 | 触发条件 |
|------|------|---------|
| brainstorm | `stages/brainstorm.zh.md` | clarify=yes |
| design | `stages/design.zh.md` | design=yes |
| plan | `stages/plan.zh.md` | 默认开；Doc 模式跳 |
| execute | `stages/execute.zh.md` | always |
| review | `stages/review.zh.md` | risk=yes 或（tasks>1 且跨模块） |
| insight | `stages/insight.zh.md` | always |

**术语**：
- **Stage** 阶段，**Step** 阶段内的编号步骤（取自 stage 文件 `## Progress`），**Task** 可独立验证的工作单元（plan 切分、execute 执行）
- **Handoff** 阶段产出文档，结构由各 stage 文件模板定义
- **Gate** 步骤入口条件（`user` yes/no / `auto` 系统判断 / `always`）
- **Anchor** `anchors.txt` 里的结构断言。9 种规则类型与翻译见 `stages/plan.zh.md` Step 3
- **自检** 托管模式下决策点的强制结构化 block，定义见 `skills/sprint/auto-principles.zh.md`

### 1.3 命令调用

参数仅接 `0` / `1`（yes→1, no→0）。`create` 第 5 参数 `1` 启用托管。AUTO 必须在调 `evaluate` 前确定（用户输入 `--auto` 或 Q5 答 yes）。

> **Doc 模式（Q3=yes）**：构造 `create` 第 3 参数 STAGES 串时排除 plan（如 `design,execute,insight` 或 `execute,insight`）；`evaluate` 仍按 clarify/design/risk 三参数调用，不传 doc=1（脚本不识别）。

```bash
if [ "$AUTO" = "1" ]; then
  bash "$SPRINT_CTL" evaluate {0|1} {0|1} {0|1} auto=1
  bash "$SPRINT_CTL" create "sprint" "{desc}" "{stages}" "low" "1"
else
  bash "$SPRINT_CTL" evaluate {0|1} {0|1} {0|1}
  bash "$SPRINT_CTL" create "sprint" "{desc}" "{stages}"
fi
bash "$SPRINT_CTL" activate "{id}"
```

> **Auto 传递契约**：`evaluate` 输出含 `auto=1` → `create` 必须把 `"1"` 作为第 5 参数。否则 `state.json.auto` 保持 false，自检不会触发。上面 if/else 强制——不要写带未解析占位符的单一调用。

### 1.4 阶段间切换

每个启用的阶段循环：

1. `bash "$SPRINT_CTL" stage {id} {stage} running`
2. 读 stage 文件，按步执行（遵守 gate）
3. 写 handoff（insight 例外）—— 路径 `{sprint_dir}/handoffs/{stage}.md`
4. `bash "$SPRINT_CTL" stage {id} {stage} completed`
5. 公告下一阶段、确认（auto 模式不停顿，见 §4.5）

> `{sprint_dir}` = `$SPRINT_HOME/projects/{project-id}/{sprint-id}/`，**不在项目工作树**。详见 §5.3。

切换规则：

- **链式传递**：每阶段读上游 handoff。被跳过的阶段 → 下游用描述
- **任务跟踪**：每阶段不调 TaskCreate（sprint-ctl 跟踪）。子任务 ≥3 才用 TaskCreate——execute 例外（每个 plan 任务一条）
- **跳过意图**：go / continue / 下一步 → 接受当前、继续。核心决策不可跳过
- **多选（≥3 维度）**：推荐表 → 用户标记 → 仅展开标记项。二选一保持内联

### 1.5 sprint 结束

```bash
bash "$SPRINT_CTL" end "{id}"
```

## 2. 全局规则

### 2.1 硬规则

继承 `~/.claude/rules/skill.md` §1 基础硬规则模板（不改任务清单外文件 / 不跳验证 / 不混 add+refactor / 不强行输出 / change-request 中性）。sprint 特有强化项：

1. 不跳过锚点检查，即使测试通过（结构断言与测试互补，验证不同维度）
2. **handoff 仅对当前 sprint 内 stage-to-stage 负责**。跨 sprint 价值的信息必须落到项目 repo `.md` 文档（后续 sprint 主动读）或 memory 文件（系统自动注入下个 session）。`Downstream` section 只描述下一阶段，不写"下个 sprint 建议"

### 2.2 行为规则

stage 文件可加强、不可与本节冲突。

1. **会话阶段不读代码** — brainstorm 与 design Step 1：方向未确认前不读代码 / 文件
2. **只在已确认信息上推进** — 不基于未确认假设做后续追问或设计
3. **问题需有理由；信息齐全则收敛** — 每个问题说明动机。槽位填齐 + 再问已不改输出 → 停止
4. **每个阶段提供增量价值** — 直接继承上游。质量不重测任务。review 不重查锚点
5. **有界探索** — 开放循环声明最大轮数。到上限强制收敛
6. **subagent 升级** — 1 失败：同模型重试。2 失败：升级（sonnet→opus）。3 失败：停下报告
7. **handoff 是终态** — 工作 + 用户确认完成后写出
8. **持久化前先确认** — handoff、Lock、报告：写之前先用户确认。anchors.txt 在 plan 自动提取，呈现后允许补充
9. **精确恢复** — 返回到 stage + step 编号。不允许"从头来"
10. **最多 3 个选项** — 候选 >3 时先过滤，呈现 Top 3
11. **Gate merge** — Gate 跳过早期 step 时，把剩余 step 合并成一次性输出 + 一次确认。不要不带上下文（如任务切分）孤立呈现中间产物（如 anchors）

### 2.3 默认值

| 情境 | 处理 |
|------|------|
| 描述为空 | 要求补充 |
| <5 词且模糊 | 问 1 个澄清问题 |
| 评估答案不明 | 默认 no（跳过） |
| Gate 不明 | 跳过 |
| 确认环节单字回复 | 视为 yes |
| 选择环节单字回复 | 重新提问并列出选项 |
| 上游 handoff 缺失 | 用原始描述 |
| sprint-ctl 失败 | 原文报错，问用户重试或跳过 |

## 3. 输出约定

### 3.1 进度指示器

每条响应起首：

```
━━ {stage1} ✓ → [{当前}] → {stage3} ━━
{stage} ({step}/{total}) — {step_name}
```

- `✓` = 已完成，`[x]` = 当前，普通 = 待执行
- 被跳过的阶段省略

### 3.2 错误报告格式

错误必含三要素：失败什么 / 什么命令 / 修复建议。

**fewshot**：

- Good：`anchor-check FAIL: MUST_CONTAIN config.json port (位于 src/setup.ts 第 42 行未写入)。修复：在 setup.ts 加 setPort(config.port)`
- Bad：`anchor-check 出错了`（缺命令、缺位置、缺修复建议）

其他输出规则：

- 数字具体："3 个文件"而非"几个"
- 输出为空 → "无"。不可静默省略
- stage 文件模板是强制结构

### 3.3 假设清单（Assumptions）协议

思考阶段（brainstorm Step 1、design Step 2、plan Step 3-5 合并）—— 第一份实质性输出**必须**以 `## 假设清单` block 收尾，列 ≥3 条承重假设，每条绑定一个证据来源。用户用条目编号反驳（`A2 错，应该…`），不重述需求。

**模板**：

```
## 假设清单（哪条错了告诉我）
- [A1] {假设} — 来源：{description phrase / prior handoff line / inferred from X}
- [A2] ...
- [A3] ...
```

仅当本阶段输出已枚举显式决策（如 Decision Register 含 `○ direction` / `✗ open` 状态）时跳过——那些条目承担同样作用。

### 3.4 用户可见交互

按 `~/.claude/rules/skill.md` §6 维护（不泄露内部术语 / 语言对齐 / 禁用兜底词 / 展示粒度）。本节仅给 sprint 特有补充：

- **sprint 特有术语替换表**：见 `skills/sprint/interaction-terms.md`
- **anchor 翻译落地**：`stages/plan.zh.md` Step 3 把 rule 原文翻成中文呈现给用户（如 `stages/brainstorm.zh.md 必须含文本 "total: 2"`）—— rule 原文是内部结构，不直接展示

## 4. 托管模式（--auto）

托管模式：核心决策点由主 agent 按原则约束做结构化自检，主流程自动推进，用户旁观，sprint 结束时看汇总。

### 4.1 触发方式（二选一）

1. **参数**：`/sprint --auto {desc}`
2. **评估问询**：未传 `--auto` 时 evaluate 阶段问 Q4，用户答 y 即启用

命中任一 → `state.json.auto = true`。

> **为何不用关键词匹配**：自然语言关键词（如"委托"）会误伤（"我委托你改个文件" ≠ 要托管）。`--auto` + Q4 已经够用。

### 4.2 自动决策点（6 个）

由 `skills/sprint/auto-principles.zh.md` §决策点映射定义：

1. `D1-demand-lock` — brainstorm Step 1 末（需求锁定）
2. `D2-solution-approach` — design Step 1 末（方案选择）
3. `D3-design-decisions` — design Step 2 末（设计决策）
4. `D4-system-design` — design Step 4 末（若该子层触发）
5. `D5-task-split` — plan Step 4 末（任务切分）
6. `D6-review-verdict` — review Step 6（Verdict）

每个触发点，主 agent **必须**产出自检 block（结构见 `auto-principles.zh.md` §自检 block 模板，含 G1/G2/G3 强制字段），写入该阶段 handoff `## 自动审视` section。

### 4.3 用户介入点

仅以下两个：

1. sprint 开始（参数触发免交互；Q4 触发需用户答 y/n）
2. insight 阶段"自动审视汇总"呈现后，用户回 `approve` / `重跑 N[,M]` / `审视 N`

**不等待用户确认**：核心决策产出 + 自检完成即进入下一步。handoff 写入、阶段切换均自动。

### 4.4 与"如需对抗性审视"的关系

- **非 auto 模式**：保持原样（用户 on-demand 单点挑战）
- **auto 模式**：每决策点自检 block 内置 G3（清单外盲点）提供发散挑战，**替代**原 on-demand 机制；最终汇总阶段用户用 `审视 N` 对某点深挑战

### 4.5 硬规则

1. 自检 block 的 G1/G2/G3 三字段任一缺失视为 handoff 不完整，流程阻断并报错
2. 决策点所在步骤被 gate 跳过 → 不产出对应自检 block（不视为缺失）
3. 非 auto 模式下任何 stage 文件保持原行为，自检相关代码路径静默
4. **阶段间不得软停顿**：`state.json.auto == true` 时主 agent **不得在阶段边界结束响应**——同一轮必须：写 handoff → `sprint-ctl stage {id} {stage} completed` + 下一 `running` → 开始执行下一阶段

**唯一允许停顿**：

1. sprint 开始（Q4）
2. insight 最终汇总（`approve` / `重跑 {ID}` / `审视 {ID}`）
3. 硬失败

**违规检测**：最后 ≤2 行包含 `?` / `？` / "确认" / "继续?" / "ready" 且 `state.json.auto == true` 且无硬失败 → 不合规。被禁结尾如"进入 plan?"、"ready to continue?"、"所有决策 ✓。进入 X" + 停。

## 5. 参考

### 5.1 脚本路径

从 "Base directory for this skill: {path}" 去掉 `skills/sprint/` 得到项目根。

```
SPRINT_CTL="{project_root}/scripts/sprint-ctl.sh"
ANCHOR_CHECK="{project_root}/scripts/anchor-check.sh"
```

### 5.2 模型选择

按 step 声明，默认 sonnet。

| 场景 | Model |
|------|-------|
| 推理 / 比较 / 设计 | opus |
| 规格明确 / 编码 / 验证 | sonnet |
| 机械操作（移动 / 重命名 / 格式化） | haiku |

execute 覆盖：跨模块 → opus；单文件 → sonnet；无逻辑 → haiku。

### 5.3 数据 schema

#### 目录

sprint 记录全局保存在 `$XDG_DATA_HOME/sprint/`（默认 `~/.local/share/sprint/`），按项目组织。**不在项目工作树**。

```
$SPRINT_HOME/
├── projects/
│   └── {project-id}/
│       └── {sprint-id}/
│           ├── state.json      # created → running → completed
│           ├── handoffs/       # 阶段产出文档
│           ├── anchors.txt     # plan 阶段产生，execute 阶段验证
│           └── metrics.log     # 仅追加事件
```

`project-id` = 项目绝对路径中的 `/` 替换为 `-`。聚合文件：`$SPRINT_HOME/projects/{project-id}/summary.json`（单项目，sprint 结束时更新）。

#### state.json

```json
{
  "id": "YYYYMMDD-HHMMSS-RRR",
  "type": "sprint",
  "desc": "...",
  "stages": ["brainstorm", "design", ...],
  "status": "created | running | completed",
  "current_stage": "{stage name or ''}",
  "complexity": "low | medium | high",
  "auto": true | false,
  "base_commit": "{short sha or 'none'}",
  "created_at": "ISO 8601 UTC"
}
```

#### metrics.log（仅追加，管道分隔）

- `sprint_start|{id}|{ts}`
- `stage_start|{stage}|{ts}`
- `stage_end|{stage}|{status}|{ts}|{dur}s`
- `anchor_check|{ts}|pass={n}|fail={n}|skip={n}`
- `sprint_end|{id}|{ts}`

#### summary.json

已完成 sprint 数组：

```json
[
  {
    "id": "...",
    "desc": "...",
    "status": "completed",
    "type": "sprint",
    "complexity": "low",
    "duration": 1234,
    "stages": {"brainstorm": 300, "design": 200, ...},
    "anchor": {"pass": 9, "fail": 0, "skip": 0},
    "scope_creep": 0,
    "tasks": {"planned": 3, "completed": 3, "skipped": 0},
    "completed_at": "ISO 8601 UTC"
  }
]
```

#### anchors.txt

每行一条规则。`grep -qF` 语义（固定字符串匹配）。9 种规则类型与翻译见 `stages/plan.zh.md` Step 3。

> **数据 Schema 单一来源**：`sprint-ctl.sh` 写入这些；stage 读取。这里改了**必须**同步到 `sprint-ctl.sh`。
