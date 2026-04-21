# Auto 模式：原则约束自检

sprint 托管模式（`--auto`）的核心资产。定义**原则标签**、**决策点 → 原则映射**、**自检 block 模板**。由 `SKILL.md` 的 Hosted Mode section 引用；由各 stage 文件的决策点直接消费。

非 auto 模式下本文件不生效。

## 原则标签

10 条原则，每条是**单一维度**的决策基准。stage 文件通过标签名引用，不内联定义。

| 标签 | 含义 | 适用场景 |
|------|------|---------|
| `first-principles` | 从根本事实推理，不依赖类比/惯例 | 方案选型、tradeoff、需求合理性 |
| `simplicity` | 最简可行，砍非必要 | 架构复杂度、抽象层数、特性范围 |
| `reversibility` | 决策可回退，避免不可逆操作 | 重构、删除、数据迁移、发布 |
| `blast-radius` | 影响范围最小 | 修改涉及面、依赖扩散、运行时副作用 |
| `consistency` | 与现有代码/约定一致 | 命名、错误处理、接口风格 |
| `minimal-abstraction` | 抽象少而精准，避免过度泛化 | 新建抽象/接口、参数化、包装层 |
| `value-proof` | 真实用户价值可验证 | 需求、特性、价值点 |
| `independence` | 模块/任务独立可验证 | 任务切分、模块边界、依赖方向 |
| `cost-first` | 显式成本/收益权衡 | 多方案选择、扩展范围判断 |
| `concrete-evidence` | 不做无证据推测 | 需求锁定、风险评估、根因判断 |

扩展原则：新增标签必须加到本表 + 至少一个决策点映射。标签要求**彼此正交**（单一维度），不是标签的集合。

## 决策点映射

sprint 6 阶段中，auto 模式下**强制自检**的决策点共 6 个。每点绑定一组原则，触发时产出自检 block。

| ID | 决策点 | 位置 | 绑定原则 |
|----|--------|------|---------|
| `D1-demand-lock` | 需求锁定（Demand Lock） | brainstorm Step 1 末（6-slot 锁定后） | `first-principles` + `value-proof` + `concrete-evidence` |
| `D2-solution-approach` | 方案选择（Solution Approach） | design Step 1 末（选方案后） | `simplicity` + `cost-first` + `reversibility` |
| `D3-design-decisions` | 设计决策（Design Decisions） | design Step 2 末（Decision Register 构建后） | `first-principles` + `simplicity` + `consistency` + `cost-first` |
| `D4-system-design` | 系统设计（System Design） | design Step 4 末（有子层触发时） | `minimal-abstraction` + `consistency` + `blast-radius` |
| `D5-task-split` | 任务切分（Task Split） | plan Step 4 末（切分后） | `independence` + `reversibility` |
| `D6-review-verdict` | Review Verdict | review Step 6（verdict 后） | `reversibility` + `blast-radius` + `concrete-evidence` |

**ID 稳定性**：`Dn-kebab-name` 是跨文件引用的稳定标识。重命名/重排表格时必须**保留原 ID**；决策点删除 → 物理删除 ID（不复用）；新增决策点 → 下一个可用序号（D7、D8…）。stage 文件和 insight 汇总必须按 ID 引用，不按行号。

**触发规则**：
- 仅当 `state.json.auto == true` 时产出自检 block
- 决策点所在步骤未进入（被 gate 跳过）→ 不产出对应块
- 自检 block 写入该阶段 handoff 的 `## 自动审视` section（若不存在则创建）

## 自检 block 模板

主 agent 在触发点**必须**产出以下结构化块。缺失任一子项 → handoff 视为不完整，流程阻断。

```markdown
### 自动审视 — `{decision-id}`：{决策名}

- **决策**: {1 行：chose what + why}
- **绑定原则**: `principle-A` + `principle-B` + ...
- **原则对照**:
  - `principle-A`: ✓ / partial / weak — {1 行具体证据}
  - `principle-B`: ✓ / partial / weak — {1 行具体证据}
  - ...
- **G1 失败归因**: 若本决策事后失败，最可能违反的原则是 `{principle}`，因为 {具体失败场景}
- **G2 被拒备选**:
  - `{alternative 1}` — 违反 `{principle}` — {为什么拒}
  - （至少 1 条；极简决策可写 "保持现状 — 违反 `value-proof` — 不做就没改进"）
- **G3 清单外风险**: 除绑定原则外，本决策最可能被忽视的风险是 {free-form，**必须是 6 个绑定原则之外的维度**}，因为 {reason}；若已穷尽写 "已穷尽"
```

### 字段规则

- `原则对照` 的 `✓ / partial / weak`：
  - `✓` = 原则完全满足，证据具体
  - `partial` = 部分满足，说明哪部分
  - `weak` = 勉强满足或有边界风险；不允许 `✗`（若违反应重做决策，不是记录）
- `G1` 只能从**绑定原则**中选一条
- `G2` 至少 1 条被拒备选，每条必须标出违反的原则
- `G3` 必须是**绑定原则未覆盖**的维度；复用已绑定原则视为无效
- 字段必须按顺序出现；不可遗漏

### 证据要求

- 不写"符合最佳实践"、"简洁有效"这类无证据断言
- 每条 `原则对照` 的证据必须引用：**决策本身的某个具体选择** 或 **上游 handoff 里的某条事实**
- `G1/G2/G3` 的 {reason} 同样要求具体，禁止"可能有性能问题"类模糊表述

### 示例

Good：
```markdown
### 自动审视 — `D2-solution-approach`：方案选择（extend SKILL.md 第 6 节）

- **决策**: 选 B —— 扩展现有 skill.md 加第 6 节；未选新建独立文件
- **绑定原则**: `simplicity` + `cost-first` + `reversibility`
- **原则对照**:
  - `simplicity`: ✓ — 不新增文件，读者定位范围一致
  - `cost-first`: ✓ — 所有 skill 文件 frontmatter 已 glob 到 skill.md，零引用成本
  - `reversibility`: partial — 新增章节易回退（git revert），但 skill.md 已 200 行再加会推近臃肿阈值
- **G1 失败归因**: 若本决策事后失败，最可能违反 `simplicity`，因为 skill.md 内容继续膨胀会让该文件难以导航
- **G2 被拒备选**:
  - `新建独立文件 rules/skill-interaction.md` — 违反 `simplicity` — 多一个文件，需其他 skill 主动引用
  - `本地 skills/sprint/rules/interaction.md` — 违反 `value-proof`（brainstorm 明确要全局复用）
- **G3 清单外风险**: 除绑定原则外，本决策最可能被忽视的风险是**规则混杂**（交互规则和编写规则写在一个文件），因为合并后 section 边界依赖命名区分，未来可能被误读；非 `simplicity`/`cost-first`/`reversibility` 能覆盖的维度
```

Bad：
```markdown
### 自动审视 — 方案选择

- **决策**: 选 B
- **绑定原则**: 都符合
- **原则对照**: ✓
- **G1**: 可能会出问题
- **G2**: 无
- **G3**: 已穷尽
```

（违反：决策无理由、对照无证据、G1 无具体失败场景、G2 空、G3 未思考直接"已穷尽"）
