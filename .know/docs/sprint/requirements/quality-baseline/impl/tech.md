# 建立质量基线 技术方案

<!-- 核心问题: 怎么实现、做到哪了？
     定位: 技术方案 + 实现进度跟踪（多次 sprint 迭代完善）
     不属于本文档: 产品需求（→ PRD）、系统架构（→ arch）、接口契约（→ schema） -->

## 1. 背景

- M3 里程碑要求：核心脚本有自动化回归测试，关键路径有断言保护
- 技术约束：纯 bash 实现，零外部依赖（不引入 bats/shunit2 等框架）；暂不需要 CI
- 前置依赖：无。被测脚本 sprint-ctl.sh 和 anchor-check.sh 已稳定（M2 完成）

## 2. 方案

### 文件结构

```
tests/
├── test-helpers.sh         # 共享 assert 函数 + fixture 管理
├── test-anchor-check.sh    # anchor-check.sh 回归测试（18+ 用例）
└── test-sprint-ctl.sh      # sprint-ctl.sh 回归测试（14+ 用例）
```

### 核心流程

```
test-*.sh
    │
    source test-helpers.sh
    │
    setup_fixture          ← 创建临时 git repo + 初始 commit
    │                         export ROOT / SPRINT_DIR
    │                         trap teardown_fixture EXIT
    │
    ├── run_test "用例名" '
    │     # 准备 → 执行 → 断言
    │   '
    ├── run_test ...
    │
    report                 ← N pass / M fail → exit code
```

### 接口定义

```bash
# Fixture lifecycle
setup_fixture()            # tmpdir + git init + commit → export ROOT
teardown_fixture()         # rm -rf tmpdir

# Test runner
run_test <name> <body>     # 子 shell 执行，捕获结果，累计计数

# Assertions
assert_exit_code <expected> <command...>
assert_contains <needle> <haystack_var>
assert_not_contains <needle> <haystack_var>
assert_file_exists <path>
assert_file_not_exists <path>

# Summary
report                     # 输出统计，fail > 0 → exit 1
```

### 用例隔离策略

- 每个测试文件共享一个临时 git repo（setup_fixture 只调用一次）
- 每个用例在 run_test 子 shell 中执行，使用唯一 sprint ID（test-001, test-002...）
- MUST_BUILD/TEST 用例创建临时 package.json + npm script 模拟
- trap EXIT 确保异常退出也清理

### 测试用例覆盖

**anchor-check.sh（18+ 用例）：**

| 类型 | 正向 | 反向/边界 |
|------|------|----------|
| MUST_EXIST | 文件存在 → PASS | 不存在 → FAIL |
| MUST_NOT_EXIST | 不存在 → PASS | 存在 → FAIL |
| MUST_BUILD | package.json + build 成功 → PASS | build 失败 → FAIL, 无项目类型 → SKIP |
| MUST_TEST | package.json + test 成功 → PASS | 无项目类型 → SKIP |
| MUST_IMPORT | 文件含 import → PASS, 目录搜索 → PASS | 不含 → FAIL, target 不存在 → FAIL |
| MUST_NOT_IMPORT | 不含 → PASS, target 不存在 → PASS | 含 → FAIL |
| FILE_NOT_MODIFIED | 未修改 → PASS | 已修改 → FAIL |
| 边界 | 空 anchors.txt → exit 0 | 注释行跳过, CLAUDE.md build_cmd 优先 |

**sprint-ctl.sh（14+ 用例）：**

| 子命令 | 正向 | 边界 |
|--------|------|------|
| create | 目录结构 + state.json 字段完整 + stages JSON 正确 | — |
| activate | status=running + base_commit 非空 | — |
| stage | running → metrics 记录, completed → duration | 无效状态 → exit 1 |
| evaluate | 0 0 0 → 基础 stages, 1 1 1 → 全部 stages | 关键词 delete → risk=1 |
| end | status=completed + 统计输出 | — |
| list | 有 sprint → 输出, 无 → "No sprints found." | — |

## 3. 关键决策

| 决策 | 选择 | 为什么 |
|------|------|--------|
| Runner 机制 | 自写 assert 函数 | PRD 排除测试框架；bash 原生足够覆盖需求 |
| Fixture 管理 | 临时 git repo + trap EXIT | 被测脚本依赖 git 上下文；trap 保证清理 |
| 断言粒度 | exit code + 输出内容 | 输出格式也是接口契约，需要验证 |
| 用例隔离 | 共享 repo + 唯一 ID + 子 shell | 平衡隔离性和执行速度 |
| MUST_BUILD 模拟 | package.json + npm script | 最轻量的可执行构建环境 |

## 4. 迭代记录

### 2026-04-13

设计阶段完成。确定了测试架构（3 文件）、assert 接口（6 函数）、fixture 策略（共享 git repo + trap）、用例清单（anchor 18+ / ctl 14+）。
