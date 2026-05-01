# design

## Progress

- total: 5
- steps:
  1. How should this be solved?
  2. Does this solution fit your needs?
  3. What to build first?
  4. How does it all fit together?
  5. Lock the design

从已确认的需求到具体的方案设计。**目标**：plan 阶段能直接基于 design 产出拆分任务。

## 1. 硬规则

1. 呈现方案选择时最多 3 个候选
2. 进入下一步骤前，决策清单中不允许存在 `open` 条目

## 2. 输入

- brainstorm 阶段产出（如存在）：需求框架、范围、价值点
- 用户描述 + evaluate 结果（如跳过 brainstorm）

---

## 3. Step 1：方案选择

Model: opus

**Step entry (ask user)**：解决方式是否需要确定？

> 💡 已明确 → 跳过。多种可行方向 / 形式不清 → 进入。Default: skip。

在设计细节之前，先确定问题的解决方式。

### 3.1 执行流程

1. **Infer** —— 基于需求框架（Goal / Object）推断最可能的方案：形态（产出类型）+ 路径（实现方式）
2. **Ambiguity check** —— 是否只有一个合理方向？
   - 是 → 呈现该方案、一句话理由，用户确认
   - 否 → 呈现 2-3 个候选（见 3.2 模板），推荐其中一个，用户做选择
3. **Industry reference**（可选）—— 当用户问"业界怎么做？"，或任务涉及技术选型 / 架构模式 → 快速 WebSearch，结论内联呈现。**不主动提供**
4. **Lock** —— 已确认的方案进入 Step 2

### 3.2 候选呈现模板

```
| # | Approach | Form | Trade-off |
|---|----------|------|-----------|
| 1 | {approach} | {Feature/Workflow/Automation/...} | {1 句} |
| 2 | {approach} | {form} | {1 句} |
```

### 3.3 fewshot

- Good: `Approach: CLI 子命令 | Form: Automation | Trade-off: 实现快，发现性弱于 UI`
- Bad: `Approach: 改进系统 | Form: Feature | Trade-off: 更好`

### 3.4 托管模式自检（`D2-solution-approach`）

如果 `state.json.auto == true` 且 Step 1 已进入：

1. 按 `skills/sprint/auto-principles.zh.md` §自检 block 模板产出方案选择自检 block
2. 绑定原则：`simplicity` + `cost-first` + `reversibility`
3. 追加到 handoff 的 `## 自动审视` section
4. **不要暂停**；继续进入 Step 2

### 3.5 完成检查清单

- [ ] 方案 form + path 已锁定
- [ ] 呈现 ≤3 个候选（如有歧义）
- [ ] 用户已选定
- [ ] auto 模式：自检 block 已写

---

## 4. Step 2：方案对齐

Model: opus

按交付形态产出对应的具体设计产物。

### 4.1 形态 → 产物

- **Feature** → 接口草图 + 交互流
- **Workflow** → 流程图（步骤、决策、输出）
- **Decision Policy** → 决策流 + 评分标准
- **Automation** → 触发-动作流 + 改造前后对比
- **Data Structure** → Schema + 字段定义 + 关系
- **Asset/Template** → 模板结构 + 使用示例 + 可变点
- **Collaboration** → 协议图 + 角色 + 状态迁移

代码级设计还需产出：

1. 文件结构表（create / modify / do-not-touch）
2. 接口定义（公共 API，改造前后对比）
3. 依赖方向（允许 + 禁止）
4. 架构图 / 时序图 / 数据流图（视复杂度而定）

呈现给用户。修正 → 更新后重新呈现。

### 4.2 建议任务边界

文件结构确认后，产出初版任务拆分建议供 plan 阶段消费。**仅三列** —— 不含依赖图、并行策略、模型提示（这些归 plan 管）。

```
| # | Task Name | Files | Independence Rationale |
|---|-----------|-------|------------------------|
| 1 | {verb + noun} | {paths from File Structure} | {why independently verifiable — cite build/test/anchor handle} |
```

规则：

1. 文件路径只能取自 File Structure；不引入新路径
2. 单次原子编辑（1 文件 <50 行）→ 写一行 `N/A — single atomic change`
3. 独立性理由必须指明具体可验证手段（build / 单测 / anchor / 文件存在性）

**fewshot**:

Good:
```
| 1 | Add auth middleware | src/auth/middleware.ts, src/auth/types.ts | 独立编译；无需 caller 改动即可单测 |
| 2 | Wire middleware into router | src/router.ts | 依赖 Task 1 merged；HTTP 401 烟囱测 |
```

Bad:
```
| 1 | Do auth stuff | various | it works |
```

### 4.3 决策清单（内部标签——对用户呈现为"决策清单"）

用户确认后，汇总 Steps 1-2 所有决策：

- Step 1 方案选择（如已进入）→ `core`
- Step 2 设计决策 → `core`
- 实现细节 → `detail`

呈现给用户时（不输出 "Decision Register"）：`core / detail` 与 `✓/○/✗` 标记是内部用 —— 转自然语言（"已确认" / "方向已定，细节待补" / "未讨论"），或保留表格但翻译列名。追加：`如需对抗性审视，回复"审视"`。

用户回"审视" → 切换为挑战者角色：对每条 `core` 决策用第一性原理质疑（问题是否真实 / 是否最简 / 是否应推翻）。挑战后重呈（更新或不变）。

### 4.4 推断 spec 偏好（供 plan）

决策清单确认后，为下游 plan 推断 4 个 spec 字段。每个字段是带 `undecided` 兜底的枚举 —— 缺乏证据时**不要猜**。

| Field | Values | 推断来源 |
|-------|--------|---------|
| scope | `precise` / `extended` / `undecided` | 方案选择中"只改必要"→precise；"顺手清理"→extended |
| depth | `patch` / `root-cause` / `undecided` | 决策清单讨论根因→root-cause；明确"先堵住"→patch |
| transition | `direct` / `incremental` / `undecided` | 文件结构全量替换→direct；"v1/v2 并存"→incremental |
| compatibility | `strict` / `internal-break` / `undecided` | "不动调用方"→strict；"破坏性变更 ok"→internal-break |

规则：无明确证据 → 填 `undecided`，由 plan 阶段补问。**禁止猜测填默认值**。

写入 handoff 的 `## Spec Preferences` section。**此处的字段 schema 是唯一信息源——Step 5 handoff 模板必须与这 4 个字段完全一致**。新增 / 修改字段时同步更新两处。

### 4.5 fewshot

- Good: `Form: Automation | Trigger: /deploy → 自动检 env、构建、推 staging | Before: 5 步手动 | After: 1 命令 | Files: create scripts/deploy.sh, modify package.json`
- Bad: `Form: Feature | Description: 改进部署，使其更自动化 | Files: various`

### 4.6 托管模式自检（`D3-design-decisions`）

如果 `state.json.auto == true`：

1. 决策清单汇总完毕后，按 `skills/sprint/auto-principles.zh.md` §自检 block 模板产出设计决策自检 block
2. 绑定原则：`first-principles` + `simplicity` + `consistency` + `cost-first`
3. 追加到 handoff `## 自动审视` section
4. 跳过 `如需对抗性审视` 提示（G3 已替代）
5. 继续进入 Step 3

### 4.7 完成检查清单

- [ ] 形态对应产物已产出
- [ ] 文件结构表已确认
- [ ] 任务边界 ≥1 行
- [ ] 决策清单 core 全部 ✓
- [ ] Spec Preferences 4 字段已填（含 `undecided`）
- [ ] auto 模式：自检 block 已写

---

## 5. Step 3：实现优先级评审

Model: sonnet

**Step entry (auto)**：决策清单中是否有 `detail` 类 `○ direction` 条目？（内部检查，不展示）

- 有 → 进入
- 无 → 跳过

提取未确认的 `detail` 条目，按依赖排序。每条建立内部跟踪任务。逐条走查：**推荐做法 + 备选项**。用户确认 → 标记任务完成 + 该决策从 `○ direction` 改为 `✓ confirmed`。

用户回"skip" → 剩余 `detail` 条目保留为 `direction`，由 plan / execute 解决。

---

## 6. Step 4：系统设计

Model: opus

**Step entry (ask user)**：是否需要定义架构分层、核心流程、接口协议或算法？

> 💡 不增加新层 / 不改数据流 / 不设计新接口 / 不涉及非平凡算法 → 跳过。Default: skip。

### 6.1 4 子层评估

| Sub-layer | Trigger | Output |
|-----------|---------|--------|
| 架构 | 需要划分职责边界或分层？ | 分层、模块、依赖方向、技术选型 |
| 核心流程 | 关键路径需要明确顺序？ | 主路径、分支、状态迁移、数据流 |
| 接口与协议 | 组件间有数据交换？ | 签名、schema、格式、调用约定 |
| 算法 | 涉及非平凡算法逻辑？ | 伪代码、复杂度、性能 / 可扩展性 / 可维护性 / 边界情况 |

全部"不适用" → 整步骤跳过。适用产出一并呈现给用户确认。决策以 `core` 加入清单。

### 6.2 fewshot（接口子层）

Good:
```
接口：parseAnchor(line: string) → {rule: string, target: string, pattern?: string}
- 输入: anchors.txt 单行
- 输出: 结构化对象，rule ∈ 9 类
- 错误：unknown rule → throw ParseError
```

Bad:
```
接口：parseAnchor — 解析锚点
```

### 6.3 托管模式自检（`D4-system-design`）

如果 `state.json.auto == true` 且至少产出一个子层：

1. 按 `skills/sprint/auto-principles.zh.md` §自检 block 模板产出系统设计自检 block
2. 绑定原则：`minimal-abstraction` + `consistency` + `blast-radius`
3. 追加到 handoff `## 自动审视` section
4. 跳过用户确认；继续进入 Step 5

如果 Step 4 因 gate 跳过（所有子层"不适用"）→ **不**产出 block，不算缺失。

---

## 7. Step 5：写阶段产出

Model: sonnet

写入 `{sprint_dir}/handoffs/design.md`：

```markdown
## Conclusion
## Solution Approach
{form + path, from Step 1 if entered; otherwise inferred in Step 2}
## Design Content
{diagrams, tables, interface defs, flows}
## Key Decisions
## File Structure
| Action | File | Responsibility |
## Suggested Task Boundaries
| # | Task Name | Files | Independence Rationale |
<!-- If Step 2 Suggested Task Boundaries was skipped, write: — not generated (Step 2 skipped) -->
## Constraints
## Decision Register
| # | Decision Point | Category | Status | Conclusion |
## Spec Preferences
<!-- Fields + enum values MUST mirror Step 2 §4.4 推断表. Keep in sync. -->
- scope: {precise | extended | undecided}
- depth: {patch | root-cause | undecided}
- transition: {direct | incremental | undecided}
- compatibility: {strict | internal-break | undecided}
## Downstream
```

---

## 8. 完成条件

### 8.1 决策清单状态语义

- Status：`✓ confirmed`（可直接执行）/ `○ direction`（细节待补）/ `✗ open`（未讨论）
- Category：`core`（架构 / 流程 / 系统级，进 plan 前必须确认）/ `detail`（实现细节，可保持 direction）

### 8.2 Exit Rules

1. 不允许存在 `open` 状态
2. 所有 `core` 条目必须为 `confirmed`
3. `detail` 条目可保持 `direction`
4. 用户已确认决策清单
5. 阶段产出已写入

## 9. 恢复

- plan 发现 design 缺口 → 回到 design，补齐缺口，重新确认
- 用户改变方向 → 从 Step 1 重跑
- 缺少技术设计 → 回到 Step 4，补对应子层
