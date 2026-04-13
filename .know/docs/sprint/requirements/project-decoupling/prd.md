# 消除项目耦合

## 1. 问题

sprint 的 anchor 验证（`MUST_BUILD`、`MUST_TEST`、`MUST_IMPORT`、`MUST_NOT_IMPORT`）硬编码了 Swift 项目路径（`src/mac/Packages`）和 Swift 命令（`swift build`、`swift test`），导致非 Swift 项目无法使用构建和导入验证。

影响：sprint 声称是通用任务执行引擎，但实际只能在作者的 Swift 项目上完整运行。接入新项目时用户必须手动改 `anchor-check.sh` 源码，这违背了产品定位。

当前 workaround：不使用 `MUST_BUILD`/`MUST_TEST`/`MUST_IMPORT` anchor，只用 `MUST_EXIST`/`FILE_NOT_MODIFIED` 等通用断言。但这意味着放弃了构建验证 — sprint 最核心的质量保障能力。

## 2. 目标用户

使用 AI agent 完成软件工程任务的开发者，项目语言不限于 Swift。

| 场景 | 痛点 |
|------|------|
| 在 TypeScript 项目上使用 sprint | `MUST_BUILD` 执行 `swift build`，直接失败 |
| 在 Go 项目上使用 `MUST_IMPORT` anchor | grep 搜索 `src/mac/Packages/` 路径，找不到文件 |
| 想接入新项目 | 必须读 anchor-check.sh 源码，理解硬编码逻辑，手动修改 |

当前替代方案：

| 方案 | 不足 |
|------|------|
| 不用构建类 anchor | 丧失核心验证能力 |
| 手改 anchor-check.sh | 改了就不能回到 Swift 项目用，且升级 sprint 后改动丢失 |
| quality.md 的信号表检测 | quality 阶段已实现多语言检测，但 anchor-check.sh 没有对齐 |

## 3. 核心假设

**将 anchor-check.sh 的构建/测试/导入命令从硬编码改为动态检测 → 用户在任意语言的项目上都能使用完整的 anchor 验证，不需要改 sprint 源码。**

验证方式：在非 Swift 项目（至少 1 个）上执行包含 `MUST_BUILD`、`MUST_TEST`、`MUST_IMPORT` 的 sprint，端到端通过。

## 4. 方案

用户无需做任何额外配置。anchor-check.sh 自动检测项目类型并使用对应的命令。

用户可感知的变化：

- `MUST_BUILD`：自动检测项目类型（Package.swift → `swift build`、package.json → `npm run build`、Cargo.toml → `cargo build` 等），在项目根目录执行对应命令，不再假设固定路径
- `MUST_TEST`：同上，自动检测并执行对应测试命令
- `MUST_IMPORT {target} {module}`：根据项目语言选择导入语法（Swift `^import X`、Go `"X"`、Python `import X|from X`、JS/TS `import.*X|require.*X`），在项目根目录下搜索 target 路径（相对路径，用户在 anchor 中指定）
- `MUST_NOT_IMPORT`：同上，反向验证
- 优先级：如果 CLAUDE.md 中定义了 `build_cmd` / `test_cmd`，优先使用用户定义的命令（与 quality.md 行为一致）

## 5. 验收标准

- 在包含 package.json 的项目上，`MUST_BUILD` 执行 `npm run build` 并正确判断成功/失败
- 在包含 Cargo.toml 的项目上，`MUST_TEST` 执行 `cargo test` 并正确判断成功/失败
- `MUST_IMPORT src/auth session` 在 TypeScript 项目中搜索 `src/auth` 目录下的 `import.*session` 模式
- `MUST_NOT_IMPORT` 反向验证正确
- CLAUDE.md 中定义 build/test 命令时，anchor-check.sh 优先使用用户定义
- 现有的 `MUST_EXIST`、`MUST_NOT_EXIST`、`FILE_NOT_MODIFIED` 行为不变
- 未检测到项目类型且无用户定义命令时，`MUST_BUILD`/`MUST_TEST` 报 SKIP（不是 FAIL）
- plan.md 的 anchor 生成表格中，`MUST_IMPORT` 的 target 参数改为相对路径（不再假设 Swift 包结构）

## 6. 排除项

- 项目级配置文件机制（M4 解决，本次只用 CLAUDE.md 已有能力）
- 多语言混合项目的自动检测（检测到多个信号时取第一个匹配，用户可通过 CLAUDE.md 覆盖）
- 自定义 anchor 类型扩展机制
- anchor-check.sh 以外的脚本通用化
