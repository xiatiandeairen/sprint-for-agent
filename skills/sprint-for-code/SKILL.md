---

## name: sprint-for-code

description: 编程任务的工作流。/sprint-for-code {desc} 选 flow 编排 stage 执行，归档到 XDG sprint 目录。

# Sprint for Code

## 1. Overview

做编程任务，输出代码或代码审查结果。

### 1.1 接受

以**代码改动或代码评价**为主体的任务。

举例：加功能 / 修 bug / 重构 / 迁移 / hotfix / spike / 代码审查（PR）。

### 1.2 不接受

- 非代码产出（产物不是代码）
- 度量驱动的循环型(反复 profile-改-度量直到达标)
- 调研 / 调查型（分析判断是主体，不是代码改动）

举例：写文章 / 数据分析 / UI 设计 / 性能 profile / 系统调研 / 技术选型 / 调试日志分析。

## 2. 原则

1. **范围守恒**：只做用户授权范围内的事；原任务外的发现提示用户，等授权再做。
2. **用户控方向**：关键决策（做什么 / 做多大 / 风险取舍）AI 提候选，用户拍板。
3. **不跳验证**：每步该做的检查做完才算完成，不靠"应该没问题"判定。
4. **失败明示**：做不到就明说原因；不假装成功，不糊弄"差不多"。

## 3. 内部变量声明

- **$SPRINT_ROOT** — 项目根路径。worktree 共享同一根；非 git 项目 = `$(pwd)`
- **$SPRINT_PID** — project id。$SPRINT_ROOT 中所有 `/` 替换为 `-`
- **$SPRINT_DIR** — sprint 归档目录。`${XDG_DATA_HOME:-$HOME/.local/share}/sprint/$SPRINT_PID`
- **$SPRINT_SID** — sprint id。格式 `YYYYMMDD-HHMMSS-RRR`（UTC 时间戳秒级 + 3 位随机后缀）
- **SPRINT_N** — handoff 章节累积序号。从 1 起递增；循环内每轮新增章节不覆盖

## 4. 工作流流程

### 4.1 信息确认

目标：和用户对齐 stage 执行流程 + 归档位置。

#### Stage 挂载规则

每个 stage 默认不挂：

- **clarify** — 需求是否需要澄清？一句话能说清目的就不用
- **explore** — 是否要先发散方案？实现路径唯一就不用
- **design** — 是否要设计架构，写规格约束？单模块内变更就不用
- **plan** — 是否要拆解任务？单文件改动就不用
- **implement** — 是否要写代码？评审 / 调研 / 思考类任务不用
- **verify** — 是否要外部验证？改动可逆、局部、不影响线上就不用
- **reflect** — 是否要复盘？一次性小活不用

#### 循环规则

循环 = 前序 stage 的输出靠后续 stage 反馈修正。判定：起点 stage 的输出会被下游推翻吗？会 → 包成 `loop({起点} → ... → {终点}) until {条件}, max={N}`。终点 = 最后一个挂载的实施 stage（verify 优先于 implement）。

按起点逐个问：

- **implement 起点** — implement + verify 同挂自动开（代码一次写不对靠 verify 修），max=3
- **plan 起点** — 做完一段才知下段怎么拆？是 → 推荐启用，max=5
- **design 起点** — 实现反馈会推翻接口设计？是 → 推荐启用，max=5
- **explore 起点** — 实施反馈会推翻产品方向？是 → 推荐启用，max=5

#### 步骤

1. 理解用户输入 desc。
2. 根据用户输入判定 stage 挂载：按上方"Stage 挂载规则"逐个判定。
3. 评估循环（基于 step 2 挂载结果）：按"循环规则"对每个非 implement 起点逐个问触发条件，命中即记为推荐，附理由。
4. 解析 §3 变量（不建文件）：
  ```bash
   COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null || true)
   if [ -z "$COMMON_DIR" ]; then SPRINT_ROOT="$(pwd)"
   else SPRINT_ROOT=$(dirname "$(cd "$COMMON_DIR" && pwd)"); fi
   SPRINT_PID="$(echo "$SPRINT_ROOT" | sed 's|/|-|g')"
   SPRINT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/sprint/$SPRINT_PID"
   mkdir -p "$SPRINT_DIR"
   while :; do
     SPRINT_SID="$(date -u +%Y%m%d-%H%M%S)-$(printf '%03d' $((RANDOM % 1000)))"
     [ ! -f "$SPRINT_DIR/$SPRINT_SID.md" ] && break
   done
  ```
5. 渲染任务确认模板：
  ```
   ━━ 任务确认 ━━

   任务: {一句话总结}

   计划步骤:
   {编号}. {自然语言描述} ({stage 名})
       {一句话理由}
   ...

   {若 step 3 有推荐循环则展示此段，否则省略}
   流程编排:
   - {起点}-起点循环 ({stage 序列}, max={N}) — 推荐开，理由：{step 3 评估理由}

   归档: $SPRINT_DIR/$SPRINT_SID.md

   开始？(yes / 想调整直接说)
  ```
   few shot示例见本节末尾"few shot示例"。
6. 展示模板，等用户回复（确认即同意全部安排，调整只能是 stage 或流程两类之一）：
  - yes / 确认 / ok → 进 §4.2
  - 调整 stage（如"加 verify"、"不用 plan"）→ 标记调整提示用户，回 step 5 重新确认
  - 调整流程（如"开 plan-起点循环"、"关写-验证"、"循环改为从 design 起"）→ 标记调整提示用户，回 step 5 重新确认

#### few shot示例

```
[示例 1: 极简，仅 implement]

━━ 任务确认 ━━

任务: 在 user.ts 加一行 console.log 看请求体

计划步骤:
1. 写代码 (implement)
    需要改动 user.ts

归档: ~/.local/share/sprint/.../20260501-...md

开始？(yes / 想调整直接说)
```

```
[示例 2: 常规，写-验证循环默认开]

━━ 任务确认 ━━

任务: 修登录失败 bug

计划步骤:
1. 拆解任务 (plan)
    涉及 auth.ts 和 session.ts 两个文件
2. 写代码 (implement) ⇄ 跑测试 (verify)
    反复修到测试通过，最多 3 轮

归档: ~/.local/share/sprint/.../20260501-...md

开始？(yes / 想调整直接说)
```

```
[示例 3: 复杂，AI 推荐 design-起点循环]

━━ 任务确认 ━━

任务: 把 auth 中间件从 sessionStore 切到 JWT

计划步骤:
1. 澄清需求 (clarify)
    边界条件较多
2. 发散方案 (explore)
    JWT 实现路径多种
3. 写规格 (design)
    跨 3 个服务的接口契约
4. 拆解任务 (plan)
    涉及 5 个文件
5. 写代码 (implement) ⇄ 跑测试 (verify)
    反复修到测试通过，最多 3 轮
6. 复盘 (reflect)
    迁移经验下次复用

流程编排:
- design-起点循环 (design → plan → implement → verify, max=5) — 推荐开，理由：实现反馈可能推翻接口设计

归档: ~/.local/share/sprint/.../20260501-...md

开始？(yes / 想调整直接说)
```

### 4.2 创建归档

目标：建立 sprint handoff 文件，写入元数据。

步骤：

1. 创建 `$SPRINT_DIR/$SPRINT_SID.md`，内容复制 [handoff-template.md](./handoff-template.md) 的"初始模板"代码块，按模板内"占位符替换说明"替换字段。
2. 创建成功后告知用户：
  ```
   归档已建：$SPRINT_DIR/$SPRINT_SID.md
  ```
3. 进 §4.3

### 4.3 执行 stages

目标：按 §4.1 流程编排逐个跑 stage，写 handoff。

#### Stage pointer

- **clarify** — `../../stages/brainstorm.zh.md`
- **explore** — `../../stages/explore.zh.md`（待新建：方案发散，候选 ≥2 + trade-off）
- **design** — `../../stages/design.zh.md`（待精简：只保留跨模块契约 / 数据模型）
- **plan** — `../../stages/plan.zh.md`（待新建：候选 → 选 1 + 理由 → 文件清单 → 任务拆分）
- **implement** — `../../stages/execute.zh.md`
- **verify** — `../../stages/verify.zh.md`（待从 review.zh.md 改名 + 精简，只保留机械验证）
- **reflect** — `../../stages/insight.zh.md`

#### 步骤

1. 按 §4.1 流程编排得到执行序列：已挂载 stage 按固定顺序 clarify → explore → design → plan → implement → verify → reflect 排列（未挂载略过），启用的循环段落用 loop 包裹。示例：
  - 仅 implement → `implement`
  - plan + 写-验证循环 → `plan → loop(implement → verify) until pass, max=3`
  - clarify + explore + design 起点循环 + reflect → `clarify → explore → loop(design → plan → implement → verify) until 全部子需求完成, max=5 → reflect`
2. 从左到右逐 token 执行：单 stage 名走 step 3，`loop(...)` 走 step 4。
3. **单 stage 执行**：
  1. 输出 `→ 进入 {stage 名}`（循环内附 `(循环第 k 轮，max N)`）
    例：`→ 进入 plan`；循环内 `→ 进入 plan (循环第 2 轮，max 5)`
  2. 按照当前 stage 对应文件的执行流程工作
  3. Edit handoff，精确更新以下两处：
     1. **追加正文章节**（文件末尾）：
        - 标题：`## {SPRINT_N}. {stage 名}`（循环内附 ` (循环第 k 轮)`）
        - 时间戳：`<!-- ts: {ISO8601} -->`
        - 主体：由 stage 文件定义
     2. **若本 stage 是 loop 内最后一个**，在 frontmatter 写入/更新两字段：
        - `loop_round: {当前轮次}`
        - `loop_result: {本 stage 计算的关键词，schema 由该 stage 文件定义}`

     完整示例见 [handoff-template.md](./handoff-template.md)
  4. 输出 `✓ {stage 名} 完成`
     例：`✓ plan 完成`
4. **loop 执行**：
  1. **进入新一轮**：Edit handoff frontmatter 写入/更新 `loop_round`（首轮 = 1，之后每轮 +1）
  2. **跑 loop 内 stage 序列**：按 step 3 逐个跑；最后一个 stage 在 step 3.3.2 内会写入 frontmatter `loop_result`
  3. **判定**：
     - `loop_result == until 关键词` → 输出 `循环结束（{loop_result}）`，跳出
       例：`循环结束（pass）`
     - `loop_round >= max` → 输出 `循环达上限 ({max})，强制结束（未收敛）`，跳出
       例：`循环达上限 (3)，强制结束（未收敛）`
     - 否则回 step 4.1
5. 全部 token 跑完 → 进 §4.4。

不支持嵌套 loop / 并行 / goto。

### 4.4 收尾

目标：标记 sprint 结束，输出汇总。

步骤：

1. 读 handoff，解析 frontmatter `created` + 各章节 `<!-- ts: {...} -->`
2. 算 per-section 耗时：
  - 第 1 章节：dur = section[1].ts − frontmatter.created
  - 第 i 章节 (i>1)：dur = section[i].ts − section[i-1].ts
3. Edit handoff frontmatter：
  - `status: running` → `status: completed`
  - 加 `completed_at: {now ISO8601}`
4. 按以下模板输出给用户：
  ```
   ━━ Sprint 完成 ━━
   ID:   {SPRINT_SID}
   归档: $SPRINT_DIR/$SPRINT_SID.md

   stage 耗时：
   {N}. {stage 名}    {耗时}
   ...
   total              {总耗时}
  ```

