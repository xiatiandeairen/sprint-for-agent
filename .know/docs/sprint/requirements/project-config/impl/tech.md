# 项目级配置 技术方案

<!-- 核心问题: 怎么实现、做到哪了？
     定位: 技术方案 + 实现进度跟踪（多次 sprint 迭代完善）
     不属于本文档: 产品需求（→ PRD）、系统架构（→ arch）、接口契约（→ schema） -->

## 1. 背景

<!-- 技术约束和前置依赖。回答"为什么要做这个方案"
  - 技术约束列表（影响方案选择的硬限制）、前置依赖（必须先完成的任务/模块）
  - EXCLUDE: 产品愿景、用户画像（→ PRD） -->

- M4 里程碑要求：声明式定义构建/测试/lint 命令，接入新项目只需写配置文件
- 技术约束：配置文件为独立 JSON 文件；与现有 CLAUDE.md 和自动检测向后兼容
- 前置依赖：M2 已实现动态项目检测 + CLAUDE.md 优先读取

## 2. 方案

<!-- 高层技术设计，随 sprint 迭代更新。回答"怎么实现"
  - 文件/模块结构: 树形或表格，每项标注职责（1 句话）
  - 核心流程: 关键路径的步骤序列（A → B → C），不展开每步实现
  - 数据结构: 只列公开接口级的结构定义（字段名+类型+用途）
  - EXCLUDE: 函数签名、算法伪代码、完整接口定义（→ schema） -->

### 文件结构

```
项目根目录/.sprint.json     # 项目级配置（build/test/lint，所有字段可选）
scripts/anchor-check.sh     # 新增 read_sprint_config() + detect_lint_cmd()
stages/quality.md            # 优先级描述更新 + lint 执行 gate
stages/plan.md               # anchor 生成说明更新优先级
```

### 核心流程

命令检测优先级链：`.sprint.json` → CLAUDE.md → 自动检测。lint 仅从 `.sprint.json` 读取，无 fallback。

### 数据结构

.sprint.json：`{"build": "string", "test": "string", "lint": "string"}`，所有字段可选，值为 shell 命令字符串。

## 3. 关键决策

<!-- 技术选型及理由，每次 sprint 后积累。回答"为什么这样做"
  - 每行 1 个技术选型点，"为什么"包含被拒方案及拒绝原因（1 句话）
  - EXCLUDE: 产品方向决策 -->

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 配置读取 | python3 JSON 解析 | 与 state.json 读取一致；拒绝 jq（额外依赖） |
| 优先级链 | .sprint.json > CLAUDE.md > 自动检测 | 专用配置最高，向后兼容；拒绝替换（破坏现有用户） |
| lint fallback | 无 | lint 工具因项目而异无法自动检测；拒绝猜测（误报风险） |
| JSON 错误处理 | 报错 exit 1 | 静默忽略会导致用户不知道配置没生效 |

## 4. 迭代记录

<!-- 每次 sprint 实现了什么，新增在前。 -->

### 2026-04-14

M4 完成。实现了 read_sprint_config() 公共函数、detect_lint_cmd()、3 级优先级链改造、quality.md lint gate、7 个新测试用例（28+14=42 总计）。
