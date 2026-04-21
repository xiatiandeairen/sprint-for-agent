# Sprint 术语替换表

按 `~/.claude/rules/skill.md` §6.1 要求维护。用户可见输出出现**内部词**即违规。新增内部术语时同步登记。

## 术语 → 用户可见替换

| 内部词 | 用户可见替换 | 处理 |
|--------|-------------|------|
| Demand Lock | 已对齐需求 ✓ | 替换标签 |
| Value Lock | 价值点确认 ✓ | 替换标签 |
| Sanity Gate | — | 纯内部；触发反馈时直接描述问题（"有 N 点需先澄清"） |
| Strawman Framings | "基于描述，可能是以下三种之一" | 删标题 |
| Gate（步骤入口条件） | "是否需要 X？" 直接问 | 改措辞，不出现 "Gate" |
| Ambiguity Triage | — | 纯内部 |
| 6-slot frame | 省略标题，直接呈现内容 | 删标题 |
| Decision Register | 决策清单 | 翻译 |
| Spec Preferences | — | 内部推断；需补问时直接问"这次改动范围多大？"等 |
| Value Mining | 价值点挖掘（或省略标题） | 翻译或删 |
| anchor / anchors.txt | 结构检查清单 / 验证清单 | 翻译 |
| handoff | 阶段交接文档 / 阶段产出 | 翻译 |
| stage / step / task | 阶段 / 步骤 / 任务 | 中文对话中禁止保留英文 |
| TaskCreate / TaskUpdate | — | 工具调用，不展示 |
| sprint-ctl / anchor-check | — | 脚本名，不展示；失败时显示原始错误 |

## 保留原文

PR / diff / commit / lint / API / CLI / skill / sprint（产品名）

## 落地示例：anchor 翻译

`stages/plan.md` Step 3 把 `MUST_CONTAIN / MUST_EXIST / FILE_NOT_MODIFIED` 等 rule 原文翻成一句中文（如 `stages/brainstorm.md 必须含文本 "total: 2"`），并给出"可能还需要补"推荐菜单。属 §6.3 "展示粒度" 规则的具体落地——rule 原文是内部结构，必须不直接展示给用户。
