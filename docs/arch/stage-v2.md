# Sprint v2 Stage Model — Atomic Stages & Orchestration

> 本文档定义 sprint v2 的 stage 模型架构。**不包含**任何 stage 的内部实现、I/O 契约、提示词或场景→工作流映射；这些由后续实现 sprint 落地。

---

## 1. 目标与适用范围

### 目标

把 stage 重塑为**最小可组合工作单位**：单一职责、见名知意、独立可验证。通过原子 stage + 编排原语，覆盖工程与分析两大类知识工作。

### 适用范围

适用于 sprint 框架下的所有任务编排。**显式覆盖** 6 大类 18 子场景（见 §3）。**显式不覆盖**：
- 跨 sprint 事件触发 / 异步编排
- Stage 内部实现细节（提示词 / few-shot / 内部 step）
- 编排器代码实现（属后续实现 sprint）

---

## 2. 设计原则

四条核心原则，按优先级降序：

| # | 原则 | 含义 |
|---|---|---|
| P1 | 扩展非补足 | Stage 用于编排 LLM 的**强项**（推理 / 生成 / 归纳 / 验证），不替 LLM 做它已经能做好的事。Stage 不退化为通用 LLM 调用的薄包装。 |
| P2 | 单一职责 | 每个 stage 一句话能描述其动作 + 产出类型，无 "并且"。 |
| P3 | 见名知意 | Stage 名直接表达动作 + 域，编排者无需读 stage 内部即可拼工作流；同源动作跨域命名去歧义。 |
| P4 | 不过度拆 | 粒度有下限——再拆则失去独立验证价值。判据见 §5。 |

---

## 3. 工作场景列表

按"工作意图 + 产出形态"分 6 大类 18 子场景。Stage 集合必须覆盖全部子场景。

| 大类 | 子场景 |
|---|---|
| L1 工程改变 | L1a 小需求 / L1b 长需求 / L1c bug 修复 / L1d 重构 / L1e 删除迁移 / L1f 性能优化 |
| L2 文档生产 | L2a PRD / L2b 技术设计 (TD/RFC) / L2c 使用文档 / L2d 汇报总结 |
| L3 分析推理 | L3a 问题分析（根因）/ L3b 决策分析（A vs B）/ L3c 现状审计 |
| L4 调研 | L4a 市场 / 竞品调研 / L4b 技术选型调研 |
| L5 探索创造 | L5a 开放头脑风暴 / L5b 深度洞察 |
| L6 复盘学习 | L6a 单事件复盘 / L6b 周期 / 项目回溯 |

> 本文档**不**给场景→工作流的具体映射。编排者按 §4 原子集 + §6 编排原语自由组合。

---

## 4. 原子 Stage 集合

16 个原子 stage：**工程子集 8 个**（§4.2）+ **分析子集 8 个**（§4.3），命名 0 重叠。两域间的同源对应与形态差异见 §4.4。

每个 stage 给三个维度：**职责**（动作 + 产出）/ **价值定位**（解决什么问题）/ **LLM 拓展关系**（如何放大 LLM 强项 / 补 LLM 弱项；对照 §2 P1）。

### 4.1 LLM 拓展模式（3 类）

| 模式 | 含义 | 含 stage |
|---|---|---|
| **结构化输出型** | LLM 本就能做，stage 强制特定产出形态以可对齐 / 可对照 / 可援引 | clarify / frame / explore / decide / specify / split / compare / conclude（8 个） |
| **约束作用域型** | LLM 强项发挥的地方，stage 不替 LLM 干活，只限定"在哪里干" | implement / analyze（2 个） |
| **补弱项型** | LLM 单次推理不擅长，stage 引入外部工具 / 元认知 / 对抗整合 / 跨会话沉淀来补 | verify / reflect / probe / research / synthesize / learn（6 个） |

3 类合起来体现 P1：stage 编排 LLM 的强项，**不**让 stage 退化为通用 LLM 调用的薄包装。

### 4.2 工程子集（Engineering domain，8 个）

覆盖 L1 / L2 工程改变与文档生产场景。

| # | Stage | 职责 | 价值定位 | LLM 拓展关系 | 拓展模式 |
|---|---|---|---|---|---|
| E1 | `clarify` 锁定需求 | 收敛为需求帧（goal / constraint / success） | 把模糊意图压缩为可校验需求，避免下游走偏 | LLM 倾向"理解后立即给方案"；stage 强制结构化槽位 + 用户精确反驳 | 结构化输出 |
| E2 | `explore` 发散方案 | 在确定需求下发散 2-3 候选解决方案 | 扩展方案空间，避免锁死单一思路 | LLM 倾向给"最可能"答案；stage 强制并列候选 + 显式 trade-off | 结构化输出 |
| E3 | `decide` 选定方案 | 在候选中按权衡选 1 个 | 让选择有据可查 | LLM 能列优劣但不擅长权衡定夺；stage 强制"为何选 X 而非 Y"理由链 | 结构化输出 |
| E4 | `specify` 写规格 | 写技术规格（接口 / 数据结构 / 架构） | 跨文件 / 跨模块锁定契约边界 | LLM 写单文件强但跨模块易遗漏接口；stage 强制 schema / signature 输出 | 结构化输出 |
| E5 | `split` 拆任务 | 拆成可独立验证的 task 列表 | 进度 / 质量分段管理 | LLM 倾向"一次写完整"；stage 强制按 verifiable 边界切分 | 结构化输出 |
| E6 | `implement` 写代码 | 在指定文件内按规格写代码 | 落地——LLM 强项核心 | 不替代 LLM；约束作用域到上游 specify / split 的文件清单，防越界 | 约束作用域 |
| E7 | `verify` 机械验证 | 用测试 / anchors / lint 验证实现符合规格 | 用外部判定取代自我评估 | LLM 倾向相信自己写的代码；stage 强制调用编译器 / 测试 / anchor 等外部工具 | 补弱项 |
| E8 | `reflect` 工程复盘 | 复盘已完成工作的流程与质量缺陷 | 提炼可改进的流程信号 | LLM 单次会话内难做事后元认知；stage 强制 plan vs actual 对比 | 补弱项 |

### 4.3 分析子集（Analysis domain，8 个）

覆盖 L3 / L4 / L5 / L6 分析推理、调研、探索、复盘场景。

| # | Stage | 职责 | 价值定位 | LLM 拓展关系 | 拓展模式 |
|---|---|---|---|---|---|
| A1 | `frame` 锁定问题 | 收敛为问题边界 + 关键假设 | 把模糊问题压缩为可证伪命题，避免推测当结论 | LLM 看到模糊问题倾向直接猜测；stage 强制先列假设 + 边界 | 结构化输出 |
| A2 | `probe` 定向追溯 | 已知方向下追溯证据（代码 / 数据 / 文献） | 已知假设下深入溯源，不广撒网 | LLM 倾向"宽度搜索"；stage 强制按假设引导深入。与 research 互补 | 补弱项 |
| A3 | `research` 外部搜集 | 在开放空间多源采集外部信息（可并行） | 突破 LLM 内部知识时点 / 深度的限制 | LLM 知识有时点上限；stage 强制调外部检索（web / 文献 / codebase） | 补弱项 |
| A4 | `compare` 矩阵对照 | 多候选按统一维度横向比较 | 让差异显式可见，不靠主观印象 | LLM 单线推理跨候选难维度统一；stage 强制矩阵输出 | 结构化输出 |
| A5 | `analyze` 推理归因 | 对单一对象 / 单线证据做推理与归因 | 框定推理对象 | LLM 强项就是推理；不替代 LLM，仅约束范围在上游 probe / frame 给的证据内 | 约束作用域 |
| A6 | `synthesize` 对抗归纳 | 把多源证据归纳为统一解释 | 强制处理冲突源，不"挑容易的整合" | LLM 倾向回避冲突；stage 强制冲突处显式说明取舍 | 补弱项 |
| A7 | `conclude` 结论封装 | 封装带置信度的结论 | 把分析转为可援引立场，含明确适用范围 | LLM 倾向给"模糊但安全"的回答；stage 强制带置信度 + scope 限定 | 结构化输出 |
| A8 | `learn` 分析复盘 | 复盘认知更新与可迁移洞察 | 从一次分析提炼跨场景可复用知识 | LLM 难自动跨会话沉淀；stage 强制输出"什么模式下来 / 何时再用" | 补弱项 |

### 4.4 两域对应与差异

**5 对同源对应**（命名去歧义）：

| Same-source action | 工程域 | 分析域 |
|---|---|---|
| Lock intent | `clarify`（产出需求 6 槽位） | `frame`（产出问题边界 + 假设） |
| Diverge / gather | `explore`（内部方案空间） | `research`（外部信息空间） |
| Converge / decide | `decide`（在方案中选 1） | `conclude`（封装带置信度结论） |
| Divide / focus | `split`（拆 verifiable task） | `probe`（定向追溯证据） |
| Reflect | `reflect`（流程 / 质量缺陷） | `learn`（认知更新 / 可迁移洞察） |

**6 个单域专属**：

- 工程专属（3）：`specify` / `implement` / `verify`
- 分析专属（3）：`analyze` / `compare` / `synthesize`

**4 处形态差异**：

- **写规格独有于工程**：`specify` 锁契约；分析域的"假设"由 frame 直接喂给 probe / research，无规格中间层
- **推理 / 比较 / 整合独有于分析**：`analyze` / `compare` / `synthesize` 是分析域核心负载；工程域由 explore + decide 隐式承担
- **落地独有于工程**：`implement` 产出代码制品；分析产出是结论而非制品
- **验证形态非对等**：工程 `verify` 单点机械（pass / fail）vs 分析 `compare → synthesize → conclude` 三段质性

---

## 5. 粒度判据

新增 / 合并 / 拒绝拆分 stage 时，按以下判据自检。

### 5.1 下限（不过度拆）

新增 stage 必须**同时满足** 3 条：

| # | 判据 | 通过标准 |
|---|---|---|
| L1 | 单一职责 | 一句话能描述动作 + 产出类型，无 "并且" |
| L2 | 独立产出 | 产出物可被单独引用 / 验证 / 迭代，不依赖其他 stage 的中间状态 |
| L3 | 独立调用价值 | 在 ≥2 个工作场景中作为独立 stage 出现，非每次都与同一邻居共现 |

### 5.2 上限（不过度合并）

满足**任一条**必须拆分：

| # | 判据 | 触发拆分 |
|---|---|---|
| U1 | 跨域语义不同 | 同名 stage 在不同域行为流程不同（典型：verify） |
| U2 | 多重异质产出 | 单 stage 输出 ≥2 类异质产出（如代码 + 测试报告） |
| U3 | 提示词强分支 | 单 stage 提示词需 `if X do A else do B` 类强分支 |

### 5.3 判据优先级

下限与上限冲突时（如某 stage 满足 L1-L3 但触发 U1） → **上限优先**，必须拆分。

---

## 6. 编排原语

4 个原语 + 组合规则，描述 stage 间的执行关系。

### 6.1 原语定义

| 原语 | 表示 | 语义 |
|---|---|---|
| 顺序 | `A → B` | A 完成后 B 启动 |
| 并行（DAG） | `A ∥ B` | A 与 B 独立同时执行；下游等待全部完成 |
| 迭代 | `(A → B) ↺ cond` | A → B 重复执行直到 cond 为真 |
| 条件分支 | `A ⊢ {c1: B \| c2: C \| else: D}` | A 完成后按条件选下游 |

> 符号仅为本文档约定的简记。实现层（dispatch / 编排器）可采用不同表达形式，只要语义等价。

### 6.2 组合规则

| # | 规则 | 说明 |
|---|---|---|
| C1 | 任意嵌套 | 原语可任意嵌套，例：`A → (B ∥ C) → D` |
| C2 | 跨域混合 | 工程与分析子集 stage 可混合编排，例：`implement → probe → verify` |
| C3 | DAG 跨域 | 并行两支可属不同域，例：`research ∥ implement` |
| C4 | 迭代 cond 必须可机械判定 | 如 `verify pass` / `build green` / `count > N`；禁止 "觉得不够好" 类主观条件 |
| C5 | 分支 cond 必须穷尽 | `else` 兜底强制；不允许出现条件未覆盖的执行路径 |

### 6.3 编排作用域

编排关系**不耦合于 stage 文件本身**——stage 文件只声明单一职责（本文档 §4）；具体编排（哪些 stage、何顺序、何条件）由上层 dispatch / 工作流定义负责。这保证 stage 的可组合性。

---

## 7. 场景编排示例

每大类挑 1-2 典型场景，给出推荐 stage 链。**示例不是契约**——实际编排可按 §5 粒度判据 + §6 编排原语自行组合。

### 7.1 L1 工程改变

| 子场景 | 推荐编排 | 演示原语 |
|---|---|---|
| L1a 小需求（≤1 文件） | `clarify → implement → verify` | 顺序 |
| L1b 长需求（跨模块） | `clarify → explore → decide → specify → split → (implement ∥ implement) → verify → reflect` | 顺序 + 并行 |
| L1c bug 修复 | `probe → analyze → implement → verify` | 跨域（分析→工程） |
| L1d 重构 | `decide → specify → split → implement → (verify → implement) ↺ verify pass → reflect` | 迭代环 |

### 7.2 L2 文档生产

| 子场景 | 推荐编排 | 演示原语 |
|---|---|---|
| L2b 技术设计（TD/RFC） | `clarify → explore → decide → specify` | 顺序（无 implement / verify） |

### 7.3 L3 分析推理

| 子场景 | 推荐编排 | 演示原语 |
|---|---|---|
| L3a 问题分析（根因） | `frame → probe → analyze → conclude` | 分析域顺序 |

### 7.4 L4 调研

| 子场景 | 推荐编排 | 演示原语 |
|---|---|---|
| L4a 市场调研 | `frame → (research ∥ research ∥ research) → compare → synthesize → conclude → learn` | 多源并行 |
| L4b 技术选型（cross-domain） | `frame → (research ∥ research) → compare → conclude ⊢ {决策清晰: specify → implement → verify \| 证据不足: probe → conclude}` | 并行 + 分支 + 跨域 |

### 7.5 L5 探索创造

| 子场景 | 推荐编排 | 演示原语 |
|---|---|---|
| L5b 深度洞察 | `frame → probe → analyze → synthesize → learn` | 分析域顺序 |

### 7.6 L6 复盘学习

| 子场景 | 推荐编排 | 演示原语 |
|---|---|---|
| L6b 周期 / 项目回溯 | `frame → (probe ∥ probe ∥ probe) → synthesize → learn` | 多 source 并行复盘 |

**4 编排原语全部覆盖**：顺序（全部）/ 并行（L1b、L4a、L4b、L6b）/ 迭代（L1d）/ 条件分支（L4b）。

---

## 附录 A：与 v1 模型的关系

v1 的 6 stage 线性流水线（`brainstorm → design → plan → execute → review → insight`）在 v2 中被原子化重组：

| v1 stage | v2 对应 |
|---|---|
| brainstorm | `clarify`（工程）/ `frame`（分析） |
| design | `explore` + `decide` + `specify` 三段 |
| plan | `split` |
| execute | `implement` + `verify` |
| review | （工程）合入 `verify`；（分析）由 `compare` / `synthesize` / `conclude` 承载 |
| insight | `reflect`（工程）/ `learn`（分析） |

v1 → v2 不是改名，而是按单一职责重新切分。v2 落地时 v1 工作流可由 v2 stage 重组等价表达。

---

## 附录 B：演进与扩展

新增 stage 走 §5 粒度判据；新增场景走 §3 表格扩展；新增编排原语需评估是否能由现有 4 原语组合表达，不能再加。
