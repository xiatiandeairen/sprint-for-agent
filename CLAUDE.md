# Project Guide

本仓库提供两个独立 skill：

- `skills/sprint-for-code`：动态问题驱动的软件工程工作流。
- `skills/sprint-for-analysis`：结构化分析工作流。

维护约束：

- 不重新引入固定 stage DSL、默认流程确认或强制 handoff。
- 用户控制目标、范围、授权、风险和重大取舍；普通执行细节由 AI 自主决定。
- 新增规则必须保护明确的目标、证据或风险，不能只增加流程形式。
- 文档、manifest、目录结构和测试必须同步更新，不保留失效示例或生成物。

验证命令：

```bash
python3 -m unittest discover -s tests -v
```
