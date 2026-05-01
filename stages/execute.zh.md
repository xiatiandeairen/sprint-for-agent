# execute

## Progress

- total: 4
- steps:
  1. Set up tracking
  2. Build it step by step
  3. Build in parallel
  4. Record results

按 plan handoff 执行任务。每个任务：编码 → 构建 → 锚点 → 测试 → 复审。

**默认 Model**: sonnet（跨模块 / 接口任务覆盖为 opus）

## 1. 硬规则

1. （继承 SKILL.zh.md 的文件修改规则）未列出的文件需要改动 → **停止并上报**，不要继续
2. 当前任务的锚点检查未通过，不进入下一任务。先修复
3. **Observer/Synthesizer 分离**（B 规则）：execute handoff **禁止包含** verdict / 结论性陈述 / keep-drop 表 / recommendation。**只允许**：raw observations（引用 + 数据）、量化结果、open questions。Verdict 留给 insight 合成
4. **跨 sprint 信息不走 handoff**（B6-b）：handoff 仅对当前 sprint 内 stage-to-stage 负责。跨 sprint 价值的输出必须落到项目 repo `*.md` 文档或 memory 文件（`feedback_*.md`）。`Downstream` 仅描述下一 stage，不写"下个 sprint"

## 2. 默认锚点

如果 anchors.txt 缺 `MUST_BUILD`，补上。强类型语言（Swift / Kotlin / TypeScript / Rust / Go / Java）：每任务后必须做构建验证。

## 3. 输入

- plan handoff：执行模式、任务列表、验证标准、预期文件
- anchors.txt

**Doc 模式**（跳过 plan，无锚点）：把 design handoff 或原始描述视为单个任务。无 TDD，无锚点检查。直接写入 + 格式校验。一律 step-by-step，1 个隐式任务。

---

## 4. Stage Start：任务跟踪

Model: sonnet

编码前：按 plan 中的每个任务调用 TaskCreate。开始 → `in_progress`。验证通过 → `completed`。

---

## 5. Step-by-step 模式

**Model 选择**：按 plan handoff 中每个任务的 `**Model**` 字段（fallback：sonnet 默认；跨模块 / 接口任务 opus）

对每个任务循环执行 5.1 → 5.2 → 5.3 → 5.4。

### 5.1 编码

按任务类型选流程：

- **Code** → TDD：写测试 → 运行（FAIL）→ 实现 → 运行（PASS）→ 构建验证 → 提交
- **Doc/config** → 直接写入 + 格式校验
- **Refactor** → 跑现有测试 → 重构 → 跑测试（无回归）

### 5.2 锚点检查

```bash
# [RUN]
bash "$ANCHOR_CHECK" "{sprint_id}"
```

**失败处理**：

1. 读 design handoff（`{sprint_dir}/handoffs/design.md`）的 Key Decisions section
2. 输出失败对应的设计决策作为诊断上下文
3. 修复后再继续

未列文件被改动 → 同样回溯：在上报用户前去 design handoff 检查约束。

### 5.3 AI 测试

执行任务的 AI 验证命令。同时检查：

- 代码是否符合 design handoff 的方案（不是自由发挥）？
- 接口是否与 plan 定义一致？
- 是否有超出 plan 范围的改动？

### 5.4 用户复审模板

```
### Task {N}: {title} — PASS ✓ / FAIL ✗

**自动检查**
- Build: ✓ | 验证清单: {N}/{N} ✓ | 实现一致性: 与规划一致 ✓

**文件变更**
- {path}: {what changed}

**需要你确认**
- [ ] {check 1}
- [ ] {check 2}
```

S 号任务可把连续完成的任务合并为单次确认。M / L 单独确认。

确认 → 下一任务。有问题 → 修复并重新验证。

---

## 6. Parallel 模式

**Model**: 按任务（sonnet 默认；跨模块 / 接口任务 opus）

### 6.1 Worktree 隔离

1. `EnterWorktree` —— 开始时创建 1 个共享 worktree
2. 所有任务在共享 worktree 中执行（plan 拆分保证不同文件互不冲突）
3. quality stage 也在 worktree 中跑
4. 全部通过 → rebase 到 trunk。冲突 → 停止，上报用户
5. `ExitWorktree`

Step-by-step 不使用 worktree。

### 6.2 派发

- 独立任务 → 并行 subagent
- 依赖任务 → 等依赖完成后顺序执行
- 上游失败阻塞下游任务

每个 subagent 流程：编码（同 TDD 规则）→ anchor-check → AI 测试 → 自检。

显示：`✓ complete | ● running | ○ waiting (depends on Task N)`

### 6.3 收集结果

全部完成 → 收集：变更文件、锚点结果、测试结果、错误 / 偏差。

### 6.4 统一复审模板

```
### 全部完成 — PASS ✓ / FAIL ✗

**任务状态**
| Task | 状态 |

**自动检查**
- Build: ✓ | Tests: {N} pass / {N} fail | 验证清单: {N}/{N} ✓ | 实现一致性: ✓

**需要你确认**
- [ ] {checks from tasks}
- [ ] {integration check}
```

有问题 → 派发修复 subagent，重新验证。

### 6.5 Subagent 失败恢复

1. 第 1 次失败 → 带错误上下文重试
2. 第 2 次 → 升级 model（sonnet → opus）
3. 第 3 次 → 停止，上报用户

---

## 7. 写阶段产出

Model: sonnet

写 `{sprint_dir}/handoffs/execute.md`。

**Cooldown 检查**：若 execute 产出 >10 数据点（subagent results / 样本 / readings）或耗时 >1800s，**写 handoff 前** flag 一句："数据密集 execute, 合成 verdict 推到 insight, 此处只记观察"。

### 7.1 Handoff 模板

```markdown
## Summary
- Mode / Tasks completed (数量而非质量判断)
## Tasks
### Task N: {title}
- Status (done/fail) / Files changed / 完成的动作 (非评价)
## Raw Observations
- 引用, 量化数据, subagent 原话, scan 输出 — 不做 synthesis
## Open Questions
- 观察到但未解的模式 / 矛盾 / 边界情况
## Downstream (本 sprint 内 → insight stage)
- insight 需要 attention 的具体 observation id / question
```

### 7.2 禁止 vs 允许（B+D 规则）

**禁止**：

- ❌ keep / drop / modify 表
- ❌ "V3 → V4 建议 X"
- ❌ "Per-step verdict"
- ❌ "Recommendation" section
- ❌ 评价性形容词（好 / 差 / 有效 / 冗余 / 仪式）

**允许**：

- ✅ 事实（"reader 说 V3 没想关掉, V4 有点想关"）
- ✅ 数据（"CV=0.3, 熵=1.5"）
- ✅ 问题（"V4 为什么退步？"）

---

## 8. 完成条件

- 所有任务执行完成、锚点通过、AI 测试通过、用户验证通过
- handoff 写入

## 9. 恢复

- 锚点失败 → 修复，重新检查
- 测试失败 → 调试，修复，重新测试
- Subagent 失败 → 见 §6.5
- 用户拒绝 → 修复，重新呈现
