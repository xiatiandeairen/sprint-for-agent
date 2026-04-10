# sprint-for-agent Roadmap

## 产品定位

AI agent 的结构化任务执行引擎。解决三个核心痛点：
1. **质量不可控** — agent 自由发挥容易跑偏，sprint 用 7 阶段 pipeline + anchor 验证强制质量门禁
2. **过程不可见** — agent 执行过程是黑盒，sprint 提供 stage bar、step counter、metrics log 让每一步可追踪
3. **复杂度判断缺失** — agent 对简单和复杂任务一视同仁，sprint 用 4 维评估自动裁剪流水线和路由模型

## 核心能力

| 能力 | 状态 | 说明 |
|------|------|------|
| 7 阶段 Pipeline | ✅ | brainstorm → design → plan → execute → quality → review → insight |
| 复杂度评估 | ✅ | 4 维打分（目标清晰度、范围、风险、验证难度）→ 自动裁剪阶段 |
| Anchor 验证 | ✅ | 7 种断言类型，plan 阶段定义、execute/quality 阶段校验 |
| Model Routing | ✅ | 按阶段和任务自动路由 opus/sonnet/haiku |
| Long-Sprint | ✅ | 多 sprint 编排，方向锚点验证，journal 决策追踪 |
| Todo/Quick | ✅ | 快速任务、sprint 恢复、计划执行、延迟触发 |
| 项目适配 | 💡 | anchor-check 硬编码 Swift 路径，无项目级配置机制 |
| 执行洞察 | 💡 | metrics.log 在记录但无消费端 |

## 投入与成本

| Phase | 成本 | 说明 |
|-------|------|------|
| Phase 1: 可信赖 | 3–4 个 sprint / 300K–500K tokens | 测试覆盖 + anchor 通用化，改动集中在 scripts/ |
| Phase 2: 可适配 | 4–6 个 sprint / 500K–800K tokens | 配置系统 + hooks，需要充分 design 对齐 |
| Phase 3: 可度量 | 3–4 个 sprint / 300K–500K tokens | 存储迁移 + 分析功能，数据层改动 |
| Phase 4: 可规模化 | 5–7 个 sprint / 600K–1M tokens | 探索性强，remote triggers + 多 repo |
| **总计** | **15–21 个 sprint / 1.7M–2.8M tokens** | 纯时间投入，无资金成本（含在 Claude Code 订阅内） |

## Now

- **Post-Refactor 收尾** — 提交 plan.md 残留修改，v2 重构正式 close
- **anchor-check 通用化** — 消除 Swift 硬编码路径，让任意项目可用
- **脚本级测试** — sprint-ctl.sh 和 anchor-check.sh 的自动化回归测试
- **生命周期集成测试** — 模拟完整 create → stage → end 流程验证

## Next

- **项目级配置规范** — 声明式定义构建、测试、lint 命令，接入新项目不改源码
- **Hooks 系统** — pre/post stage 扩展点（CI 已预留引用但未实现）
- **Metrics 消费端** — 从 append-only text 迁移到可查询格式，提供执行统计

## Later

- **Scope Creep 过程预警** — 从 sprint end 事后检测提前到 execute 阶段实时监控
- **Sprint 趋势分析** — 跨 sprint 的阶段耗时、anchor 失败模式、效率趋势
- **Remote Triggers 生产化** — launchd 之外的跨平台调度支持
- **版本发布自动化** — plugin.json / marketplace.json 版本号同步
- **多 Repo Long-Sprint** — 跨仓库的 sprint 编排与上下文传递

## 已知问题

- anchor-check.sh 硬编码 Swift 构建路径（`xcodebuild`），非 Swift 项目无法使用 MUST_BUILD
