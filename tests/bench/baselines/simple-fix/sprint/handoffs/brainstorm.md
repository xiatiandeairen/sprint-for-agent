## Conclusion

为 sprint 建立双层质量保障方案并落地实现：
- **基准测试**（黑盒、task 级、多维）：黄金样本对比 + LLM-as-judge 混合
- **单元测试**（核心设计）：AI 提议清单，覆盖 `sprint-ctl.sh` + `anchor-check.sh` + 其它关键脚本/规则
- **运行入口**：`make test` / `make bench`，产出 PASS/FAIL 报告

## Demand Frame
- **Goal**: 每次对 sprint 改动都有自动化质量门禁（基准 + 单测），防回归
- **Object**:
  - 基准：以一次完整 `/sprint {desc}` 为测试单元，评估 UX / 效率 / 质量 多维指标
  - 单测：`scripts/sprint-ctl.sh`（evaluate/create/stage/report 等逻辑）、`scripts/anchor-check.sh`（9 种 anchor 规则解析与校验）、以及 design 阶段提议清单
- **Constraint**: 不改 sprint 本身流程；测试资产为新增目录
- **Context**: 项目迭代久、修过多个 bug，担心改动引发回归
- **Success**: 故意注入 bug（如 evaluate 逻辑翻转）→ 单测/基准至少一个 FAIL；改动后 baseline 差异须被 review
- **Priority**: 方案设计 > 框架骨架可跑 > 完整用例覆盖

## Scope

### In
- 基准测试框架设计 + 落地脚手架（runner / baseline 存储 / 差异对比 / LLM judge 接入）
- 单元测试框架选型 + 落地（bash 脚本测试，框架由 design 阶段选）
- `make test` / `make bench` 入口
- sprint 核心设计清单（由 AI 在 design 阶段提议）

### Out
- 改 sprint 主流程（evaluate/stages/handoffs 的行为）
- 性能 benchmark（非目标，"基准"指 regression baseline）
- 测试 stage.md markdown 指令本身（无法单测 LLM 行为一致性）
- CI/CD 平台集成（先本地跑通，CI 另议）

## Value Points
- 基准库作为 sprint 行为的"可执行规格"，改动必须更新 baseline 才能合入 — 变更可追溯
- LLM-as-judge 把"UX / 质量"这类软指标量化，非全人工评估

## Downstream
design 阶段需要决定：
1. 基准测试的"task 输入"如何喂给 sprint 并捕获输出（子进程 / API / 录制回放）
2. 黄金样本的 schema（哪些字段纳入 baseline，哪些允许漂移）
3. LLM-as-judge 的评分维度与 prompt 模板
4. 单元测试框架选择（bats / 纯 shell assert / 其它）与目录结构
5. sprint 核心设计清单（AI 提议，等 design Step 1 对齐方向时给出）
