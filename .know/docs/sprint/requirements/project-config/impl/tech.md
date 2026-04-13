# 项目级配置 技术方案

<!-- 核心问题: 怎么实现、做到哪了？
     定位: 技术方案 + 实现进度跟踪（多次 sprint 迭代完善）
     不属于本文档: 产品需求（→ PRD）、系统架构（→ arch）、接口契约（→ schema） -->

## 1. 背景

- M4 里程碑要求：声明式定义构建/测试/lint 命令，接入新项目只需写配置文件
- 技术约束：配置文件为独立 JSON 文件（`.sprint.json`）；与现有 CLAUDE.md 和自动检测向后兼容
- 前置依赖：M2 已实现动态项目检测 + CLAUDE.md 优先读取；M3 已有回归测试保护

## 2. 方案

### 配置文件

```
项目根目录/.sprint.json
```

```json
{
  "build": "npm run build",
  "test": "npm test",
  "lint": "eslint ."
}
```

所有字段可选。字段值为 shell 命令字符串，在项目根目录执行。

### 文件结构

```
scripts/anchor-check.sh     # 新增 read_sprint_config() + detect_lint_cmd()
                             # 改造 detect_build_cmd() / detect_test_cmd() 优先级链
stages/quality.md            # Step 1 优先级描述更新 + 新增 lint 执行
stages/plan.md               # anchor 生成说明补充配置优先级
tests/test-anchor-check.sh   # 新增 .sprint.json 相关测试用例
```

### 核心流程

```
detect_{build|test|lint}_cmd()
    │
    ├─ 1. read_sprint_config "{field}"
    │     └─ .sprint.json 存在？
    │         ├─ 是 → JSON 合法？
    │         │     ├─ 是 → 字段有值？ → 返回值
    │         │     └─ 否 → 报错 "Error: .sprint.json is not valid JSON" exit 1
    │         └─ 否 → 继续下一优先级
    │
    ├─ 2. grep CLAUDE.md {field}_cmd      (仅 build/test)
    │     └─ 有值 → 返回值
    │
    └─ 3. 项目文件自动检测               (仅 build/test)
          └─ 匹配 → 返回值 / 无 → 返回空
```

lint 只有 .sprint.json 一个来源，无 CLAUDE.md 和自动检测 fallback。

### 接口定义

```bash
# 新增公共函数
read_sprint_config <field>
# → 读取 .sprint.json 中指定字段
# → 文件不存在：返回空
# → JSON 非法：报错 exit 1
# → 字段缺失/空：返回空

# 新增
detect_lint_cmd()
# → read_sprint_config "lint"（仅此一个来源）

# 改造（新增最高优先级）
detect_build_cmd()
# → 1. read_sprint_config "build"
# → 2. CLAUDE.md build_cmd
# → 3. 自动检测

detect_test_cmd()
# → 1. read_sprint_config "test"
# → 2. CLAUDE.md test_cmd
# → 3. 自动检测
```

### quality.md 改造

Step 1 优先级描述：
```
.sprint.json > CLAUDE.md > 自动检测
```

新增 lint 执行（位于 Step 1 之后、Step 2 之前）：
- Gate: `.sprint.json` 中有 `lint` 字段 → 执行。否则跳过
- 执行 lint 命令，失败 → return to execute

### 测试用例扩展

| 用例 | 验证 |
|------|------|
| .sprint.json build 字段 → MUST_BUILD 使用配置命令 | PASS |
| .sprint.json test 字段 → MUST_TEST 使用配置命令 | PASS |
| .sprint.json 优先于 CLAUDE.md | PASS（两者都存在时用 .sprint.json） |
| .sprint.json 缺少字段 → 回退 CLAUDE.md | PASS |
| .sprint.json 缺少字段 → 回退自动检测 | PASS |
| 无 .sprint.json → 行为不变 | PASS（现有用例不受影响） |
| .sprint.json 非法 JSON → 报错 | exit 1 + 错误信息 |

## 3. 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| 配置读取方式 | python3 解析 JSON | 与 state.json 读取一致，项目已依赖 python3 |
| 优先级链 | .sprint.json > CLAUDE.md > 自动检测 | 专用配置最高，向后兼容保留旧方式 |
| lint fallback | 无 | lint 无法自动检测（工具和规则因项目而异），只支持显式配置 |
| JSON 错误处理 | 报错 exit 1 | 静默忽略会导致用户不知道配置没生效 |
| 函数抽取 | read_sprint_config 公共函数 | build/test/lint 共用，避免重复读取逻辑 |

## 4. 迭代记录

### 2026-04-13

设计阶段完成。确定了配置读取链路（3 级优先级）、anchor-check.sh 改造点（read_sprint_config + detect_lint_cmd）、quality.md lint 执行机制、测试扩展用例（7 个新增）。
