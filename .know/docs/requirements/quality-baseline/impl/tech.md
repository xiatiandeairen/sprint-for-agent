# 建立质量基线 技术方案

<!-- 核心问题: 怎么实现、做到哪了？
     定位: 技术方案 + 实现进度跟踪（多次 sprint 迭代完善）
     不属于本文档: 产品需求（→ PRD）、系统架构（→ arch）、接口契约（→ schema） -->

## 1. 背景

<!-- 技术约束和前置依赖。回答"为什么要做这个方案"
  - 技术约束列表（影响方案选择的硬限制）、前置依赖（必须先完成的任务/模块）
  - EXCLUDE: 产品愿景、用户画像（→ PRD） -->

- M3 里程碑要求：核心脚本有自动化回归测试，关键路径有断言保护
- 技术约束：纯 bash 实现，零外部依赖（不引入 bats/shunit2 等框架）
- 前置依赖：M2 已完成（被测脚本 anchor-check.sh 已稳定）

## 2. 方案

<!-- 高层技术设计，随 sprint 迭代更新。回答"怎么实现"
  - 文件/模块结构: 树形或表格，每项标注职责（1 句话）
  - 核心流程: 关键路径的步骤序列（A → B → C），不展开每步实现
  - 数据结构: 只列公开接口级的结构定义（字段名+类型+用途）
  - EXCLUDE: 函数签名、算法伪代码、完整接口定义（→ schema） -->

### 文件结构

```
tests/
├── test-helpers.sh         # 共享 assert 函数 + fixture 管理
├── test-anchor-check.sh    # anchor-check.sh 回归测试
└── test-sprint-ctl.sh      # sprint-ctl.sh 回归测试
```

### 核心流程

```
test-*.sh → source helpers → setup_fixture（临时 git repo）→ run_test × N → report → teardown
```

Fixture 策略：每个测试文件共享一个临时 git repo，每个用例在 run_test 子 shell 中执行，使用唯一 sprint ID 隔离。trap EXIT 确保异常退出也清理。

### 覆盖范围

- anchor-check.sh：7 种 anchor 类型各自 PASS + FAIL + 边界（28 用例）
- sprint-ctl.sh：6 个子命令正向 + 边界（14 用例）

## 3. 关键决策

<!-- 技术选型及理由，每次 sprint 后积累。回答"为什么这样做"
  - 每行 1 个技术选型点，"为什么"包含被拒方案及拒绝原因（1 句话）
  - EXCLUDE: 产品方向决策 -->

| 决策 | 选择 | 为什么 |
|------|------|--------|
| Runner 机制 | 自写 assert 函数 | PRD 排除测试框架；拒绝 bats（外部依赖） |
| Fixture | 临时 git repo + trap EXIT | 被测脚本依赖 git 上下文；拒绝 mock（不够真实） |
| 断言粒度 | exit code + 输出内容 | 输出格式也是接口契约；拒绝只检查 exit code（漏检输出回归） |
| 用例隔离 | 共享 repo + 唯一 ID + 子 shell | 平衡隔离性和速度；拒绝每用例独立 repo（太慢） |

## 4. 迭代记录

<!-- 每次 sprint 实现了什么，新增在前。 -->

### 2026-04-13

M3 完成。实现了 test-helpers.sh（6 个 assert 函数）+ test-anchor-check.sh（21 用例）+ test-sprint-ctl.sh（14 用例）。M4 后扩展到 28 + 14 = 42 用例。
