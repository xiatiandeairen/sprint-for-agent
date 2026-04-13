# 核心流水线

## 1. 问题

AI agent 执行复杂任务时容易跑偏：自由发挥导致方向偏离、过程不可见、质量不可控。当前只能靠人工盯着或事后修复，前者不可规模化，后者成本高。

需要一个结构化的任务执行引擎，让任务从创建到完成走通全流程，每个阶段有明确目标、产出和验证。

## 2. 目标用户

使用 AI agent 完成软件工程任务的开发者。


| 场景             | 痛点                        |
| -------------- | ------------------------- |
| 用 agent 实现一个功能 | agent 自由发挥容易跑偏，事后发现偏离目标   |
| 大任务需要拆分执行      | 没有拆分机制，agent 一口气做完，中间无法检查 |
| 简单 bug 修复      | 走完整流程浪费时间，但完全不走又没有质量保障    |


当前替代方案：


| 方案             | 不足             |
| -------------- | -------------- |
| 人工监督           | 不可规模化，注意力成本高   |
| 事后 code review | 偏离越远修复成本越高     |
| prompt 约束      | 没有持久化，每次会话需要重复 |


## 3. 核心假设

**在 agent 执行过程中施加分阶段约束（evaluate → stage pipeline → anchor verification） → agent 输出质量显著高于自由发挥，且总时间不比事后修复更长。**

验证方式：端到端执行不报错，输出符合预期。作者本人在实际项目中持续使用。

## 4. 方案

`/sprint {description}` 一条命令启动，AI 自动评估任务复杂度（3 个 yes/no 问题），裁剪流水线阶段，分步执行。

用户可感知的变化：

- 输入描述后，AI 自动判断需要哪些阶段（brainstorm / design / plan / execute / quality / review / insight），跳过不必要的
- 每个阶段有明确产出（handoff 文档），下一阶段读取上游产出继续
- plan 阶段自动生成 anchor（结构性断言），execute 和 quality 阶段自动校验
- 关键决策点暂停确认，用户保持方向控制
- sprint-ctl.sh 跟踪生命周期状态，metrics.log 记录时间和事件
- 支持快速任务入口（`/todo`）和长任务编排（`/long-sprint`）

## 5. 验收标准

- 用户调用 `/sprint {description}`，AI 正确评估复杂度并生成流水线
- 7 个阶段（brainstorm → design → plan → execute → quality → review → insight）均可正常执行
- 复杂度裁剪工作：简单任务自动跳过 brainstorm/design/review
- plan 生成的 anchor 在 execute 和 quality 中自动校验通过
- 每个阶段写入 handoff，下游阶段正确读取上游产出
- sprint-ctl.sh 的 create/activate/stage/end/evaluate/list 命令均工作正常
- `/todo` 支持即时执行、恢复暂停的 sprint、延迟触发
- `/long-sprint` 支持多子 sprint 编排和 Direction Lock 验证
- 端到端执行不报错，输出符合预期

## 6. 排除项

- 跨项目编排（v1 不做）
- 非 Swift 项目的构建验证（M2 解决）
- 项目级配置文件（M4 解决）
- 执行数据分析和趋势报告（v2）
- GUI / Web 界面

