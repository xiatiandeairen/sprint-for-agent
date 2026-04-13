# 项目级配置

## 1. 问题

sprint 当前通过两种方式确定构建/测试命令：CLAUDE.md 中的 `build_cmd`/`test_cmd`（M2 引入的临时方案）和基于项目文件的自动检测（7 种语言）。这存在两个问题：

1. **配置混在 AI 指令中** — CLAUDE.md 是给 AI agent 的行为指令，把构建命令混在里面语义不清晰，用户不知道该在哪里配置项目信息
2. **缺少 lint 支持** — 当前只支持 build 和 test，无法配置 lint 命令。quality 阶段无法运行项目的 lint 检查

随着 sprint 在更多项目上使用（M2 已消除语言耦合），需要一个专用的配置入口。

## 2. 目标用户

使用 sprint 驱动任务执行的开发者，需要为项目指定构建/测试/lint 命令。当前替代方案是在 CLAUDE.md 中写 `build_cmd: xxx`，但这不是一个正式的配置机制，没有文档说明，用户只能靠阅读 sprint 源码才知道。

## 3. 核心假设

**提供独立的项目级配置文件 → 用户接入新项目只需写 1 个配置文件，不需要了解 sprint 内部逻辑或修改 CLAUDE.md。**

验证方式：在新项目中创建配置文件，sprint 的 anchor-check 和 quality 阶段正确使用配置的命令。

## 4. 方案

- **Before**: 在 CLAUDE.md 写 `build_cmd: npm run build`（不直观，缺少文档，不支持 lint）
- **After**: 创建 `.sprint.json`，写 `{"build": "npm run build", "test": "npm test", "lint": "eslint ."}` → sprint 所有环节自动读取

### 命令优先级

```
.sprint.json（项目级配置） > CLAUDE.md（向后兼容） > 自动检测（fallback）
```

### 配置文件格式

```json
{
  "build": "npm run build",
  "test": "npm test",
  "lint": "eslint ."
}
```

- 文件名：`.sprint.json`，放在项目根目录
- 所有字段可选 — 缺少的字段回退到 CLAUDE.md 或自动检测
- 字段值是 shell 命令字符串，在项目根目录执行

### 影响范围

| 组件 | 变更 |
|------|------|
| `scripts/anchor-check.sh` | `detect_build_cmd`/`detect_test_cmd` 最高优先级读取 `.sprint.json` |
| `stages/quality.md` | Step 1 构建/测试检测增加 `.sprint.json` 优先级 |
| `stages/quality.md` | 新增 lint 执行（如配置中有 `lint` 字段） |
| `stages/plan.md` | anchor 生成说明中补充配置文件优先级 |

### 任务

| 任务 | 文档 | 进度 |
|------|------|------|
| 项目级配置实现 | [tech](impl/tech.md) | 0/0 |

## 5. 验收标准

- 项目根目录有 `.sprint.json` 且包含 `build` 字段时，`MUST_BUILD` 使用配置的命令（不是自动检测的）
- 项目根目录有 `.sprint.json` 且包含 `test` 字段时，`MUST_TEST` 使用配置的命令
- `.sprint.json` 中有 `lint` 字段时，quality 阶段执行 lint 命令
- `.sprint.json` 缺少某个字段时，该字段回退到 CLAUDE.md，再回退到自动检测
- 无 `.sprint.json` 时，行为与 M2 完全一致（向后兼容）
- `.sprint.json` 格式错误时，报明确错误信息（不是静默忽略）
- 回归测试通过：现有 test-anchor-check.sh 和 test-sprint-ctl.sh 不受影响

## 6. 排除项

- 配置文件生成/脚手架工具（用户手动创建）
- build/test/lint 以外的配置项（如 deploy、format 等）
- 多配置文件合并（如 monorepo 子目录配置）
- 配置校验 schema（JSON 格式正确即可，不做字段值校验）
