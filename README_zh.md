# Sprint for Agent

面向软件工程和决策分析的动态问题驱动 skills。

Sprint 不强制模型走固定阶段。它只选择会实质影响结果的问题；能从上下文、代码或证据中获得答案时自主解决，只有范围、授权、风险或价值取舍才交给用户决定。

[English](README.md)

## Skills

### `sprint-for-code`

仅当主要产出是软件仓库变更、实现 / PR / diff 代码审查结论，或基于可重复测量的性能 / 可靠性优化结果时使用。包括代码、配置、测试、构建文件和与实现绑定的仓库工程文档。

修复软件问题时使用本 skill；只调查原因时使用 `sprint-for-analysis`。普通代码解释、技术问答、摘要、翻译、改写、头脑风暴和简单命令不会自动使用本 skill。

它识别三种任务形态：

```text
change：   目标 → 方案 → Eval → 实现 ⇄ Eval → 证据门禁
review：   目标 → Review 标准 → 检查 ⇄ 反证 → 证据门禁
optimize：指标 → 基线 → 假设 → 修改 ⇄ 重测 → 证据门禁
```

问题来自小型核心问题组、按需激活的领域问题，以及执行中发现的新不确定性。它不再使用固定 stage DSL、强制流程确认或默认 handoff 归档。

### `sprint-for-analysis`

仅当主要产出是基于材料和证据的解释、比较、推荐或 verdict 时使用。包括调查、决策备忘录、方案比较、根因分析、需求分析、文档 / 日志 / 数据 / 主张审阅、风险评估和策略诊断。

只调查软件问题时使用本 skill；需要修改仓库或审查实现代码时使用 `sprint-for-code`。简单事实问答、摘要、翻译、改写、头脑风暴、纯内容创作和无需判断的直接执行不会自动使用本 skill。

它识别三种分析形态：

```text
investigate：问题 → 证据 → 假设 ⇄ 反证 → 解释
decide：     目标 → 选项 → 证据与 trade-off ⇄ 反证 → 推荐
review：     主张 → 标准 → 检查证据 ⇄ 反证 → verdict
```

结论可信度来自证据覆盖和限制，而不是强制的模型自评分数。

## 设计原则

- 用户控制目标、范围、授权、风险和重大取舍。
- AI 自主解决普通实现和调查细节。
- 每个重要完成主张都有对应证据。
- 未运行检查、人工验收和证据边界必须明示。
- 仅长任务或需要恢复时持久化状态。

## 安装

在 Claude Code 中把仓库加入 marketplace，然后安装插件：

```text
/plugin marketplace add xiatiandeairen/sprint-for-agent
/plugin install sprint@sprint
```

本地开发时，可以把当前仓库目录作为 marketplace source。

Codex 可以直接加载 skill 目录，或在 `~/.codex/skills/` 下建立软链接。

## 项目结构

```text
skills/
├── sprint-for-code/
│   ├── SKILL.md
│   └── agents/openai.yaml
└── sprint-for-analysis/
    ├── SKILL.md
    └── agents/openai.yaml
tests/
└── test_repository.py
```

运行验证：

```bash
python3 -m unittest discover -s tests -v
```

## 许可证

[MIT](LICENSE)
