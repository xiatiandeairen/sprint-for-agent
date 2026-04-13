# 建立质量基线

## 1. 问题

sprint 的 2 个核心脚本（`sprint-ctl.sh`、`anchor-check.sh`）没有任何自动化测试。每次改动依赖手动验证，无法保证不破坏已有功能。M2 改动 `anchor-check.sh` 时发现 `set -e` 与 grep 的兼容性 bug，直到运行时才暴露——如果有回归测试，这类问题会在提交前被拦截。

随着里程碑推进（M4 配置机制、M5 反馈闭环），脚本复杂度会持续增长，缺少测试基线的风险也在放大。

## 2. 目标用户

sprint 的维护者和贡献者。修改核心脚本后需要快速验证改动没有破坏已有行为。当前替代方案是手动执行各种场景逐一检查，耗时且容易遗漏边界情况。

## 3. 核心假设

**为核心脚本的关键路径建立自动化断言 → 后续改动可在 3 秒内确认无回归，减少手动验证时间和遗漏风险。**

验证方式：测试脚本存在且 exit 0；每种 anchor 类型和每个 sprint-ctl 子命令至少有 1 个正向 + 1 个边界用例。

## 4. 方案

- **Before**: 改完 anchor-check.sh 后手动造一个 sprint 目录、写 anchors.txt、跑一遍看输出是否正确
- **After**: 运行 `bash tests/test-anchor-check.sh`，15+ 断言自动验证所有 anchor 类型的正向和边界情况

### 测试范围

**anchor-check.sh（优先）：**
- 7 种 anchor 类型：MUST_EXIST、MUST_NOT_EXIST、MUST_BUILD、MUST_TEST、MUST_IMPORT、MUST_NOT_IMPORT、FILE_NOT_MODIFIED
- 每种类型的 PASS 和 FAIL 场景
- 动态项目检测：detect_build_cmd / detect_test_cmd / detect_import_pattern
- CLAUDE.md 优先读取逻辑
- 未知项目类型 → SKIP 行为
- 边界：空 anchors.txt、不存在的 sprint ID、注释行跳过

**sprint-ctl.sh：**
- 6 个子命令：create、activate、stage、end、evaluate、list
- create：目录结构生成、state.json 字段完整性
- activate：状态变更为 running、base_commit 记录
- stage：running/completed/skipped 状态流转、metrics.log 记录
- end：状态变更为 completed、统计输出、scope creep 检测
- evaluate：3 参数组合 → 正确的 stage 列表、关键词覆盖 risk=1
- list：有 sprint / 无 sprint 两种场景
- 边界：无效子命令、缺少参数

### 任务

| 任务 | 文档 | 进度 |
|------|------|------|
| 质量基线实现 | [tech](impl/tech.md) | 0/0 |

## 5. 验收标准

- `bash tests/test-anchor-check.sh` 运行通过（exit 0），覆盖 7 种 anchor 类型各自的 PASS + FAIL 场景
- `bash tests/test-sprint-ctl.sh` 运行通过（exit 0），覆盖 6 个子命令的正向 + 边界场景
- 测试在无外部依赖环境下可运行（纯 bash + git，不引入测试框架）
- 测试使用临时目录，运行后自动清理，不污染项目状态
- 每个测试用例有明确的断言描述（PASS/FAIL + 用例名称）

## 6. 排除项

- CI 集成（GitHub Actions 等）— 先有测试，CI 后续接入
- 覆盖率指标和报告
- stage 文件（markdown）的测试 — 不是可执行脚本
- 性能测试 / 压力测试
- 测试框架依赖（bats、shunit2 等）
