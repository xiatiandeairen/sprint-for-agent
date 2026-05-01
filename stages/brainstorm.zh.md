# brainstorm

## Progress

- total: 2
- steps:
  1. What exactly do you want?
  2. Lock the conclusion

通过需求建模和受控的价值发现来对齐用户意图。**纯对话**：不读代码、文件或文档，所有证据来自用户。

## 1. 硬规则

1. 每个问题必须针对某个具体的槽位或假设。不做开放式探索

---

## 2. Step 1：需求建模

Model: opus

### 2.1 Pre-check：Sanity Gate

过滤层（不是完整分析）。深入的市场 / 可行性 / 根因工作放到 design 按需做。**目的**：在需求建模启动前破除 AI 的迎合倾向。

在内部对原始描述跑这 5 题。**除非触发 pushback，否则不展示给用户**。

| # | 挑战 | Pushback 触发条件 |
|---|------|------------------|
| 1 | 这个请求背后的真实痛点能识别吗？ | `no` 或 `unclear` |
| 2 | 完全删除这个需求会造成实质危害吗？ | `no` |
| 3 | 已有工具 / 功能 / 工作流是否已经解决了这个问题？ | `yes` |
| 4 | 这里的最小路径相对其价值是否成本足够低？ | `no` |
| 5 | 描述里的假设是否都能从用户证据中验证？ | `no` |

**算法**:

1. 对 Q1–Q5 逐项给出 y/n + 1 行证据（内部使用，不展示）
2. 统计触发数
3. Q3 触发 → pushback 含 3 个市场探查子问题
4. Q4 触发 → pushback 含 3 个可行性探查子问题
5. **0 触发** → 静默进 6 槽位建模，不提 gate
6. **≥1 触发** → 渲染 pushback 模板，停下等用户

**Q3 市场探查（命中 Q3 时）**:

- Q3a: 已有方案是什么，为什么不用？
- Q3b: 与那个方案的核心差异点是什么？
- Q3c: 这是否其实是一个隐含的 build-vs-buy 决策？

**Q3 同品类约束（强制）**：枚举已有方案时，每个候选必须标注 `same-category y/n`——与目标具备相同的**形态**且相同的**使用场景**。跨品类工具仅作 "adjacent references"，**不参与**差异化分析或"空白市场"主张。

强制竞品表：

| 方案 | 形态 | 同品类 y/n | 核心能力 | 缺口 |
|------|------|-----------|---------|------|

表后必须输出自审一行（原文渲染）：

> 同品类=y 的有 {X} 个。X<2 → 品类本身是新的（差异化命题成立）；X≥2 → 必须对其中至少 1 个给出具体"哪里不够"的证据，不能靠跨品类交集制造伪空白。

约束防的失败模式：列出多品类工具（如 Docker + sandbox-exec + TCC），宣称"它们之间的间隙"是空白市场——这种间隙是伪的。

**Q4 可行性探查（命中 Q4 时）**:

- Q4a: 最大的技术风险或未知是什么？
- Q4b: 最小可行版本是什么？
- Q4c: 能否分阶段做，而不是一次到位？

**Pushback 模板**（用用户语言渲染——不出现 "Sanity Gate" / "Q{n}" 编码）:

```
有 {N} 点需要先澄清：

- {1-line 关注点描述 — 不写 "Q3" 等代号}
  {if 市场: 内联 3 个市场子问题}
  {if 可行性: 内联 3 个可行性子问题}

请选择：A) 补充信息 / 解释  B) 坚持原意（说明理由）  C) 调整需求
```

用户响应后：

- 澄清解决触发项 → 进 6 槽位建模
- 用户带理由坚持 → 把已知风险记入 Context 后继续
- 需求被修订 → 对修订描述重跑内部检查

**Sanity Gate fewshot**:

Good（0 触发，静默）:
```
User: "Add a sort-by-order-date descending filter to the order list"
Q1 痛点: yes (默认排序不便) | Q2 删除危害: yes | Q3 已有: no | Q4 成本: yes | Q5 假设: yes
→ 0 触发 → 进 6 槽位建模，不交互
```

Bad（多触发，完整 pushback）:
```
User: "Build an AI assistant for the system"
Q1 痛点: unclear | Q2 删除危害: no | Q3 已有: yes | Q4 成本: no | Q5 假设: no
→ 4 触发（Q1/Q2/Q3/Q4）→ pushback 含 Q3 + Q4 探查子问题
```

### 2.2 6 槽位框架

把模糊的输入转成 6 槽位需求框架：

| Slot | Captures |
|------|----------|
| Goal | 要达成什么 |
| Object | 目标对象（功能、模块、系统、文档） |
| Constraint | 限制（时间、兼容性、技术） |
| Context | 情境（为什么是现在、什么触发了它） |
| Success | 如何验证完成正确 |
| Priority | 最重要的是什么 |

### 2.3 Execution

**Ambiguity Triage**（先跑这一步，再做槽位提取）:

按 3 个信号评估原始描述：

| 信号 | 触发条件 |
|------|---------|
| 动词模糊 | 含"完善 / 优化 / 改进 / handle / support"（无具体动词 add/remove/replace/rename） |
| 范围模糊 | ≥2 种合理范围（1 文件 vs 模块 vs 跨模块） |
| 结果模糊 | ≥2 种合理终态（修 bug vs 加功能 vs 重写） |

**0 信号** → 描述足够具体，进槽位提取。

**≥1 信号** → 给 3 个候选框定（不用内部标签 "Strawman Framings"）：

```
基于描述，可能是以下三种之一。离哪个最近 + 差在哪？

| # | 问题框定 | 范围 | 形式 | 明确不做 |
|---|---------|------|------|---------|
| A | {最窄} | {1 file / 1 module} | {Patch/Refactor/Feature/Automation} | {显式排除} |
| B | {居中 — 推荐} | ... | ... | ... |
| C | {最宽} | ... | ... | ... |
```

规则：

1. 每行点出具体文件 / 模块 / 动作——不写 "various" 或 "related components"
2. "明确不做"必须具体（用户合理上可能想要、但当前框定排除掉的）
3. 始终基于推断的工作量 / 风险匹配度推荐一个（用 ← 推荐 标注）
4. 最多 3 行。无 3 个有区分度的框定 → 描述本来不模糊，这步本应跳过

**Strawman Framings fewshot**（示例）:

```
User: "改进登录流程"
| # | 问题框定 | 范围 | 形式 | 明确不做 |
| A | 修登录失败时的错误提示文案 | src/auth/messages.ts | Patch | 不动登录逻辑 |
| B | 重写登录页 + 加忘记密码（推荐 ←）| src/auth/* | Feature | 不改后端 API |
| C | 重设计认证体系（OAuth/MFA） | src/auth + src/middleware | Refactor | 不动用户表 schema |
```

用户选定 → 框定锁定 → **在所选框定的范围内**填 6 个槽位。Clarify 步骤里不再回头改框定。

**Extract** 从描述（若 Strawman Framings 已跑则一并参考所选框定）中提取可见槽位。按下游影响给缺口排序。

**Clarify** —— 一轮内给出推断的槽位 + 澄清问题（槽位相互依赖，批量提问比串行高效）：

```
已推断 — 确认 / 修正 / 补空：

- **Goal**: {推断或 "未提及 — A) ... B) ... C) ..."}
- **Object**: ...
- **Constraint**: ...
- **Context**: ...
- **Success**: ...
- **Priority**: ...

## 假设（哪条错了告诉我）
- [A1] {推断的承重前提} — 来源：{描述短语 / inferred from X}
- [A2] ...
- [A3] ...
```

Assumptions 块规则：

1. ≥3 条，每条带显式证据来源（引用原文短语 / "inferred from X"）
2. 条目必须**可被反驳**——用户能说 "A2 错" 并明确指代某个具体点
3. 覆盖最高风险的推断（用户最可能因为它错而吃惊的那种）

用户确认 → 需求对齐锁定。修正 → 更新（最多 1 轮跟进）。

**Lock** —— 给出最终需求框架（不输出 "Demand Lock" 标签）：

```
已对齐需求 ✓

需求已清晰 — 直接进入结论。如果想挖额外价值点，说"深挖"触发价值挖掘（见本文末 §4）。
```

### 2.4 Auto 模式：强制自检（`D1-demand-lock`）

如果 `state.json.auto == true`：

1. 按 `skills/sprint/auto-principles.zh.md` §自检 block 模板产出已对齐需求的自检 block
2. 绑定原则：`first-principles` + `value-proof` + `concrete-evidence`
3. 把 block 追加到本阶段 handoff 的 `## 自动审视` section
4. **不得停顿**等待用户确认；直接进入 Step 2 Converge
5. Step 2 Converge：跳过"如需对抗性审视"提示（G3 已替代）；写 handoff + 自动推进到 design

### 2.5 槽位提取 fewshot

- Good: `Goal: 给设置页加 dark mode | Object: SettingsViewController + theme system | Success: Toggle 切换所有颜色，重启后保持`
- Bad: `Goal: 改进 App | Object: 代码库 | Success: 跑得更好`

### 2.6 Step 1 完成检查清单

- [ ] Sanity Gate 5 题已内部跑过
- [ ] 触发的 pushback 项已被用户回应（或 0 触发）
- [ ] 6 槽位全部填齐（无 "未提及"）
- [ ] Assumptions ≥3 条，已被用户回应
- [ ] 已展示 "已对齐需求 ✓"

---

## 3. Step 2：收敛

Model: sonnet

### 3.1 结论模板

给出结论（用用户语言渲染）：

```
### 结论

**{1 句 — 要做什么}**

**举例**
- Before: {当前}
- After: {之后}
- 验证: {如何检查}

**价值点**（如有）
- {确认点 1}
- {确认点 2}
```

末尾追加：`如需对抗性审视，回复"审视"`（auto 模式跳过此提示）

用户响应：

- 确认 → 写 handoff
- "审视" → 切换为挑战者角色：用第一性原理质疑结论 / 是否最简 / 哪些假设未验证。挑战后重出结论（更新或不变）

### 3.2 Handoff 模板（写入 `{sprint_dir}/handoffs/brainstorm.md`）

```markdown
## Conclusion
## Demand Frame
- Goal / Object / Constraint / Context / Success / Priority
## Scope
### In / ### Out
## Value Points
## Downstream
```

### 3.3 Step 2 完成检查清单

- [ ] 结论 1 句话清晰
- [ ] Before / After / 验证三栏齐全
- [ ] 价值点已展示（或显式 "无"）
- [ ] handoff 已写入
- [ ] auto 模式：自检 block 已写入 handoff `## 自动审视`

---

## 4. Optional Extension：价值挖掘

**触发**：仅由用户显式请求触发（"深挖" / "拓展" / "还有什么价值点"）。**不由 Step 1 gate 自动触发**（历次 sprint 触发 0 次，移除自动推荐逻辑）。

Model: opus

将需求框架对照 6 个诊断问题扫描——每个 `yes` 映射一条假设方向：

| 诊断 | `yes` 时的方向 |
|------|----------------|
| 任务是否被反复执行？ | 自动化 / 模板化 |
| 是否存在可消除的人工步骤？ | 移除 / 一键化 |
| 是否可能静默失败？ | 增加校验 |
| 输出是否可在他处复用？ | 抽出为共享资产 |
| 是否存在应该显式化的隐含决策？ | 暴露为参数 |
| 是否是一种反复出现的模式？ | 沉淀为可复用方案 |

给出最多 2-3 条有依据的假设（每条都有来自需求框架的证据）。用户挑选 / 拒绝 / 补充。被确认的点合并进 Step 2 Converge 的结论，标 "价值点确认 ✓"。**最多 1 轮**；不展开 facet，不递归深挖。

---

## 5. 完成条件

- 6 槽位框架已填好，用户已确认
- 结论 + 举例已确认
- Handoff 已写入
- 已探索价值点（若触发了价值挖掘）

## 6. 恢复

- 单字答复 → 切 A/B/C 选项
- 范围扩张 → "拆成独立 sprint。先做哪个？"
- 无法定义 success → 给具体选项
- 所有假设都被拒绝 → 不带价值点继续推进
