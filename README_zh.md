<p align="center">
  <h1 align="center">sprint-for-agent</h1>
  <p align="center">
    AI 编程代理的结构化任务执行引擎<br>
    阶段流水线 · Anchor 验证 · 模型路由
  </p>
</p>

<p align="center">
  <a href="README.md">English</a> | <strong>中文</strong>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
</p>

---

## 这是什么？

AI 编程代理在处理复杂任务时容易跳过验证、遗忘约束、产出质量不稳定。

**sprint-for-agent** 是一个 [Claude Code 插件](https://docs.anthropic.com/en/docs/claude-code)，为 AI 代理提供结构化的执行流水线。它在执行前评估任务复杂度，只运行必要的阶段，在每个检查点验证结构不变量（anchor），并根据推理复杂度将每个步骤路由到合适的模型层级。

## 一键安装

```bash
curl -fsSL https://raw.githubusercontent.com/xiatiandeairen/sprint-for-agent/main/install.sh | bash
```

自动克隆插件到 `~/.claude/plugins/sprint-for-agent` 并注册到 Claude Code 配置。需要 `git`。

<details>
<summary>手动安装</summary>

```bash
git clone https://github.com/xiatiandeairen/sprint-for-agent.git ~/.claude/plugins/sprint-for-agent
```

添加到 `~/.claude/settings.json`：

```json
{
  "plugins": ["~/.claude/plugins/sprint-for-agent"]
}
```

</details>

<details>
<summary>卸载</summary>

```bash
bash ~/.claude/plugins/sprint-for-agent/uninstall.sh
```

删除插件目录并清理 `settings.json` 中的引用。

</details>

## 快速上手

```
> /sprint 给设置面板添加深色模式支持

# Sprint 评估复杂度：
#   需要澄清需求？否 — 目标明确
#   需要技术设计？是 — 跨模块改动
#   高风险？否 — 局部可逆
#
# 流水线：design → plan → execute → insight
# （brainstorm 和 review 已跳过）
```

Sprint 通过 3 个是/否问题评估复杂度，裁剪不必要的阶段，各阶段之间通过 handoff 文档传递上下文。

## 特性

- **复杂度感知流水线** — 3 个问题（澄清 / 设计 / 风险）决定 7 个阶段中哪些需要运行
- **Anchor 验证** — 9 种结构断言（`MUST_EXIST`、`MUST_BUILD`、`MUST_CONTAIN` 等）贯穿执行全程
- **模型路由** — 根据推理复杂度为每个步骤选择 opus / sonnet / haiku
- **文档任务裁剪** — 文档类任务自动跳过 plan 阶段
- **动态项目检测** — 自动识别 7 种语言生态的构建/测试命令，支持 `.sprint.json` 覆盖
- **数据驱动反馈** — `sprint-ctl report` 趋势和异常检测，evaluate 展示历史建议
- **对抗性审视** — 用户在关键决策点触发第一性原理挑战

## Skills

### `/sprint` — 标准执行

评估任务复杂度，裁剪流水线，在每个关卡执行 anchor 验证。

适用于：单个功能、bug 修复、重构、模块级改动。

## 架构

```
sprint-for-agent/
├── scripts/
│   ├── sprint-ctl.sh           # 生命周期 CLI（create, activate, stage, end, report）
│   ├── anchor-check.sh         # Anchor 断言执行器（9 种类型，7 种语言）
│   └── sprint-insight-stats.sh # insight 阶段历史对比
├── skills/
│   └── sprint/SKILL.md         # 标准 Sprint 工作流
├── stages/                     # 6 个阶段定义（brainstorm → insight）
├── tests/                      # 53 个自动化测试用例
├── install.sh                  # 一键安装
└── uninstall.sh                # 一键卸载
```

### 流水线流程

```
用户描述
    │
    ▼
┌──────────────┐   3 个是/否   ┌──────────┐
│ 输入         │──────────────▶│ 评估     │
│ 标准化       │               │（裁剪）  │
└──────────────┘               └────┬─────┘
                                    │
  ┌─────────┬─────────┬─────────┬───┴────┬─────────┬─────────┐
  ▼         ▼         ▼         ▼        ▼         ▼
brain-   design     plan    execute   review   insight
storm
```

每个阶段读取上游 handoff 并写出自己的。跳过的阶段直接传递。

### 评估问题

| 问题 | 是 | 否 |
|------|-----|-----|
| 需要澄清需求？ | brainstorm | 跳过 |
| 需要技术设计？ | design | 跳过 |
| 高风险？ | review | 跳过 |

始终启用：plan、execute、insight。review 也在 tasks >1 且跨模块时触发。关键词覆盖（`delete`、`migrate`、`payment`、`production`、`permission`）强制 risk=yes。

### Anchor 类型

| Anchor | 检查内容 |
|--------|--------|
| `MUST_EXIST <path>` | 文件或目录必须存在 |
| `MUST_NOT_EXIST <path>` | 文件或目录不得存在 |
| `MUST_IMPORT <target> <module>` | 目标必须导入模块（语言感知） |
| `MUST_NOT_IMPORT <target> <module>` | 目标不得导入模块 |
| `MUST_BUILD` | 项目必须编译通过 |
| `MUST_TEST` | 测试必须通过 |
| `MUST_CONTAIN <file> <pattern>` | 文件必须包含指定模式（行级 grep） |
| `MUST_NOT_CONTAIN <file> <pattern>` | 文件不得包含指定模式 |
| `FILE_NOT_MODIFIED <path>` | 文件不得被修改（相对于基准提交） |

## 配置

在项目根目录创建 `.sprint.json` 指定构建/测试/lint 命令：

```json
{
  "build": "npm run build",
  "test": "npm test",
  "lint": "eslint ."
}
```

所有字段可选。未配置时，Sprint 自动从 `Package.swift`、`package.json`、`Cargo.toml`、`Makefile`、`pyproject.toml`、`go.mod` 或 `Gemfile` 检测。

命令优先级：`.sprint.json` → `CLAUDE.md` → 自动检测。

## 可观测性

```bash
# 聚合趋势和摘要
sprint-ctl.sh report [--last N] [--status completed]

# 单次 Sprint 详情
sprint-ctl.sh report <sprint-id>

# 输出：趋势（时长、anchor 通过率、scope creep），
#       摘要（完成率、平均时长、anchor）
```

evaluate 阶段展示基于历史数据的趋势和异常建议。insight 阶段将模式级经验自动写入 auto memory。

## 贡献

欢迎贡献！请：

1. Fork 本仓库
2. 创建功能分支（`git checkout -b feat/my-feature`）
3. 运行测试：`bash tests/test-anchor-check.sh && bash tests/test-sprint-ctl.sh`
4. 提交 Pull Request

## 许可证

[MIT](LICENSE)
