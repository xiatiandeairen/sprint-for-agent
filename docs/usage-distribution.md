# Sprint 真实使用场景分布

数据日期：2026-04-29 | 数据源：`$XDG_DATA_HOME/sprint/projects/*/summary.json` | 样本量：131 个已完成 sprint，跨 8 个项目。

---

## 1. 数据来源与口径

### 1.1 数据源

每个项目的 `summary.json` 是 sprint 结束时追加的 JSON 数组。每条记录含 `id / desc / type / complexity / duration / stages / anchor / scope_creep / tasks / completed_at`。

注：早期（`20260409` ~ `20260410` 的 5 条）`desc` 与 `type` 字段顺序错位（`desc` 写成 stage 列表、`type` 写成实际描述）。本报告自动检测并交换：

```jq
if (.desc | test("^[a-z,]+$")) then {desc: .type, type: .desc} else . end
```

### 1.2 6 个空流水线记录

6 条 `stages = {}` 的记录（占 4.6%），属于异常或中断的 sprint，保留计入总样本但流水线签名维度记为 `(empty)`：

```
self-nerve         | 20260422-132811-466 | 市场调研/产品方向调研产品 - 马斯克 review
self-skills-know   | 20260422-232145-491 | Sprint A: 补既有 triggers keywords + v2 benchmark 正式化…
self-skills-know   | 20260427-133643-569 | 深度review paths脚本，目录规范统一收口到脚本
self-skills-know   | 20260427-141802-429 | 路径脚本架构重设计：know-paths.sh 没有起到价值
self-skills-sprint | 20260414-075452-529 | v2 M2 内部流程优化 PRD
self-skills-sprint | 20260423-205612-788 | 按 stage-refactor-playbook 改造 SKILL.md Evaluate 步骤
```

### 1.3 分类口径（first-match priority）

`desc` 字段按以下顺序匹配，命中即归类。完整 regex 见末尾「复算命令」。

| 优先级 | 类型 | 触发关键 |
|--------|------|----------|
| 1 | `fix` | 修复 / fix / bug / hotfix / 解决…(问题/bug/finding/阻塞) |
| 2 | `delete` | 删 / 删除 / 移除 / drop / 去除 / 砍 |
| 3 | `review` | 审视 / 审计 / review / audit |
| 4 | `migrate` | 迁移 / migrate / XDG |
| 5 | `doc` | prd / tech / PRD / roadmap / 文档 / article |
| 6 | `test` | 单元测试 / 单测 / bench / test / 测试方案 |
| 7 | `refactor` | 重构 / 重设计 / 精简 / 对齐 / 改造 / 清理 / 整理 / 优化 / 改写 / 减法 / 升级 / 抽 stage / 职责收敛 / 耦合 / round-2/3 / 改进 / 重写 / 改为 |
| 8 | `analysis` | 分析 / 统计 / 分布 / 深挖 / 真实差距 / 对比 |
| 9 | `design-explore` | 设计 / 思考 / 规划 / 探索 / 调研 / brainstorm / 定义产品/形态/V1/价值/方向 / 战略 / 架构 |
| 10 | `release-promo` | 发布 / 推广 / 营销 / 开源 |
| 11 | `add-build` | 实现 / 新增 / 加 / 建立 / 接 / build / create / 做 / MVP / 路线图 / v[0-9] / 引入 / 沉淀 / 搭建 / 闭环 / 注入 / 命令 / 子命令 / 功能 |
| 12 | `tweak` | 修改 / 更新 / update / 完善 / 扩展 / enhance |
| - | `other` | fallthrough |

项目分组：

| Bucket | 匹配规则 | 项目数 |
|--------|----------|--------|
| `self-skill` | `self-skills-*` | 2（sprint, know） |
| `self-tool` | `self-CreatorAI / IMAI / nerve / TokenLost` | 4 |
| `blog` | `xiatiandeairen.github.io` | 1 |
| `business` | `work-R100*` | 2（R100, R100_meeting） |

---

## 2. 采样偏差声明（**先看这个**）

| 项目分组 | sprint 数 | 占比 |
|---------|-----------|------|
| **self-skill** | 81 | **62%** |
| self-tool | 33 | 25% |
| blog | 14 | 11% |
| business | 3 | 2% |

> **8 项目 131 sprint 中，62% 来自 sprint 框架自身和 know skill 的元开发。"真实使用"被强偏到 self-skill 元工作；business 仅 3 条几乎不能代表线上业务场景。本报告所有结论须按此偏差解读。**

---

## 3. 维度 1：语义类型 × 项目分组

| 类型 | self-skill | self-tool | blog | business | 合计 | 占比 |
|------|-----------:|----------:|-----:|---------:|-----:|-----:|
| refactor | 23 | 2 | 2 | 1 | **28** | 21% |
| add-build | 10 | 15 | 2 | 1 | **28** | 21% |
| doc | 12 | 7 | 3 | 0 | **22** | 17% |
| test | 10 | 0 | 3 | 0 | **13** | 10% |
| review | 10 | 2 | 1 | 0 | **13** | 10% |
| design-explore | 6 | 6 | 0 | 0 | **12** | 9% |
| analysis | 1 | 0 | 3 | 0 | 4 | 3% |
| fix | 2 | 0 | 0 | 1 | 3 | 2% |
| delete | 3 | 0 | 0 | 0 | 3 | 2% |
| release-promo | 2 | 0 | 0 | 0 | 2 | 2% |
| migrate | 2 | 0 | 0 | 0 | 2 | 2% |
| tweak | 0 | 1 | 0 | 0 | 1 | 1% |
| **合计** | **81** | **33** | **14** | **3** | **131** | 100% |

**关键观察**：

- `refactor` 几乎全在 self-skill（23/28 = 82%），是元开发的主旋律
- self-tool 项目以 `add-build`（15/33 = 45%）为主，符合产品孵化阶段特征
- `fix` 仅 3 条（2%），`delete` 仅 3 条（2%）—— 真实代码维护类极少，与"sprint 不处理简单任务"的设计意图一致
- `test` 13 条中 self-skill 独占 10 条，blog 3 条，self-tool / business 共 0 —— 测试驱动在元开发与博客质量基线集中
- `analysis`（含本报告）4 条中 3 条来自 blog —— blog 项目反思导向更强

---

## 4. 维度 2：流水线签名分布

签名 = `sort(stages).join("+")`，空集记为 `(empty)`。

| Top 10 流水线 | 计数 | 占比 |
|--------------|-----:|-----:|
| brainstorm+design+execute+plan | 22 | 17% |
| brainstorm+design+execute | 17 | 13% |
| execute+plan | 9 | 7% |
| design+execute+plan | 8 | 6% |
| brainstorm+design+execute+plan+review | 8 | 6% |
| execute（仅） | 7 | 5% |
| brainstorm+design+execute+insight | 7 | 5% |
| (empty) | 6 | 5% |
| brainstorm+design+execute+insight+plan | 5 | 4% |
| execute+insight+plan+quality | 4 | 3% |

总共出现 **30 种不同签名**。

按 stage 单独参与率：

| Stage | 出现次数 | 参与率 |
|-------|---------:|------:|
| execute | 122 | 93% |
| design | 92 | 70% |
| plan | 81 | 62% |
| brainstorm | 77 | 59% |
| insight | 38 | 29% |
| review | 19 | 15% |
| quality | 18 | 14% |

**关键观察**：

- `execute` 接近全量（93%），符合"always-on"设计
- `insight` 实际参与率仅 29%，远低于"always-on"的口径 —— 历史数据中大量 sprint 在 insight 之前结束（事件链 / `sprint-ctl end` 不闭 insight 的已知缺口；详见 memory `feedback_sprint_ctl_insight_gap.md`）
- `review` 15% / `quality` 14% —— `quality` 是历史阶段已被合并/移除，仍留下 18 条样本；当前 `review` 触发率不到 1/6，符合"风险 gate 默认关"
- 流水线签名 30 种但 top 5 占 56%，长尾稀疏 —— 说明实际使用集中在少数几种形态

按 stage 数：

| stage 数 | 计数 | 占比 |
|---------:|-----:|-----:|
| 4 | 40 | 31% |
| 3 | 31 | 24% |
| 5 | 24 | 18% |
| 2 | 18 | 14% |
| 1 | 7 | 5% |
| 0 | 6 | 5% |
| 6 | 4 | 3% |
| 7 | 1 | 1% |

中位 stage 数 = 4，平均 = 3.4。极简（≤2 stage）= 31 个（24%），全量（≥6）= 5 个（4%）。

---

## 5. 维度 3：复杂度分布

| 复杂度 | 计数 | 占比 |
|-------|-----:|-----:|
| low | 111 | **85%** |
| medium | 19 | 14% |
| high | 1 | 1% |

按类型 × 复杂度（仅展示有 medium/high 的类型）：

| 类型 | low | medium | high |
|------|----:|-------:|-----:|
| add-build | 20 | 8 | 0 |
| refactor | 25 | 3 | 0 |
| review | 10 | 3 | 0 |
| test | 11 | 2 | 0 |
| design-explore | 10 | 2 | 0 |
| doc | 20 | 1 | 1 |

**关键观察**：

- 85% 标 `low` 但流水线频繁完整跑（4 stage 中位）—— 复杂度判定可能偏松，或"low"被作为默认未审视填充
- 唯一 1 个 `high` 是 doc 类型，反常；说明 complexity 字段未被严格校准
- `add-build` 是 medium 占比最高的（8/28 = 29%），符合"新建功能更不确定"

---

## 6. 维度 4：项目分组分布

| 项目 | sprint | 占比 |
|-----|------:|-----:|
| self-skills-sprint | 51 | 39% |
| self-skills-know | 30 | 23% |
| self-CreatorAI | 18 | 14% |
| self-xiatiandeairen.github.io | 14 | 11% |
| self-TokenLost | 9 | 7% |
| self-nerve | 6 | 5% |
| self-Workspace-work-R100 | 2 | 2% |
| self-Workspace-work-R100_meeting | 1 | 1% |

**关键观察**：

- `skills-sprint` 自身占 39% —— sprint 框架最大的"用户"是它本身（dogfood，但也是采样最不代表外部的部分）
- 5 个项目（含 IMAI / nerve-direction-finder / R100_dev_*）有目录但无完成 sprint；说明 sprint 的"激活但未完成"或"创建项目目录但未跑 sprint"的开销大约占 5/18 ≈ 28% 项目

---

## 7. 综合关键观察

1. **元开发主导**。62% 来自 self-skill 元工作，21% 是 refactor 类，27% 是 doc/review/analysis 类（思考型）。**真正的代码新建只占 21% (`add-build`)**。
2. **insight 漏触发**。`insight` 实际参与率 29% 与"always-on"设计相差 70 个百分点。是历史数据问题（sprint-ctl end 不闭 insight）也是流水线设计的现实信号。
3. **risk gate 默认关**。`review` 仅 15%，与 evaluate Q3 默认 no 的设计一致。
4. **复杂度字段噪声**。85% low 但中位 4 stage，complexity 未与 stage 数对齐 —— 字段几乎不携带过滤信号。
5. **极简和全量都罕见**。流水线 stage 数集中在 3-5（73%）。"裸 execute"7 条 / 全量 ≥6 stage 仅 5 条，主流是中段。
6. **delete + fix 共 6 条（4%）**。代码维护型几乎不进 sprint，与"sprint 不处理简单任务"原则吻合。
7. **business 严重不足**。仅 3 条来自工作仓，sprint 在线上业务场景的真实表现近乎未被验证。

---

## 8. 复算命令

```bash
SPRINT_HOME=~/.local/share/sprint/projects

# 1) 提取并修正 desc/type swap
TMP=$(mktemp)
for f in "$SPRINT_HOME"/*/summary.json; do
  proj=$(basename $(dirname "$f"))
  jq -c --arg p "$proj" '
    .[] |
    (if (.desc | test("^[a-z,]+$")) then {desc: .type, type: .desc} else {desc: .desc, type: .type} end) as $fix |
    {
      id: .id, project: $p, desc: $fix.desc,
      complexity: (.complexity // "unknown"),
      duration: (.duration // 0),
      stages: (.stages | keys | sort | join("+")),
      stages_count: (.stages | keys | length)
    }' "$f"
done > "$TMP"

# 2) 流水线签名 top
jq -r '.stages' "$TMP" | sort | uniq -c | sort -rn | head -10

# 3) Stage 参与率
for st in brainstorm design plan execute insight review quality; do
  c=$(jq -r '.stages' "$TMP" | tr '+' '\n' | grep -c "^$st$")
  echo "$st: $c"
done

# 4) 语义分类（完整 regex 见 1.3）
jq -r '
  .desc as $d |
  (
    if ($d|test("修复|^fix |\\bbug\\b|hotfix|解决.*(问题|bug|finding|阻塞)")) then "fix"
    elif ($d|test("^删|删除|^移除|drop |去除|^砍")) then "delete"
    elif ($d|test("审视|审计|review|audit")) then "review"
    elif ($d|test("迁移|migrate|XDG")) then "migrate"
    elif ($d|test("prd|tech|PRD|roadmap|文档|article")) then "doc"
    elif ($d|test("单元测试|单测|bench|^test|^测试|质量基准测试|校准测试|测试方案|测试体系|测试集")) then "test"
    elif ($d|test("重构|重设计|精简|对齐|改造|cleanup|清理|整理|去重|simplify|优化|改写|减法|升级|enhance|抽\\s|抽stage|职责收敛|耦合|路径走脚本|round-?2|round-?3|细扣|改进|重写|改为")) then "refactor"
    elif ($d|test("分析|统计|分布|深挖|真实差距|对比")) then "analysis"
    elif ($d|test("设计|思考|规划|探索|调研|brainstorm|定义.*(产品|形态|V1|价值|体系|方向)|策略|架构|战略|价值方向|挖掘.*(stage|价值|能力)")) then "design-explore"
    elif ($d|test("发布|推广|营销|开源")) then "release-promo"
    elif ($d|test("实现|新增|^加|^建立|^接\\s|build|create|^做\\s|MVP|路线图|v[0-9]|引入|沉淀|搭建|完成|新|功能|命令|面板|子命令|可验证化|闭环|注入|empty state|illustration|search|tabs|Suggested Task Boundaries")) then "add-build"
    elif ($d|test("修改|更新|update|完善|扩展|enhance")) then "tweak"
    else "other" end
  )
' "$TMP" | sort | uniq -c | sort -rn
```
