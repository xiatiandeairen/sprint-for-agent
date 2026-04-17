# review 深度优化

<!-- 核心问题: 需求到哪了、验收标准是什么？
     定位: 需求级进度跟踪
     不属于本文档: 产品全局规划（→ roadmap）、技术方案（→ tech）、系统架构（→ arch） -->

## 1. 问题

review 阶段当前是全或无——触发就走完整 5 层分析（L1 残留风险 → L5 演进判断）。但不同风险场景需要的深度不同：删除文件主要看 L1+L4，架构重构才需要 L3+L5。当 risk=yes 被设置在小改动上（比如删除一个废弃函数），用户被迫走完整 5 层分析，时间浪费。同时 L4 的 12 个 bad signal + 9 个 good signal 每次全扫，很多 signal 与本次改动无关（例如改动不涉及新 public API 时仍扫"one-off-as-interface"）。所有 risk=yes 或 cross-module 的 sprint 用户都受影响。

## 2. 目标用户

触发 review 的开发者（risk=yes 或 tasks >1 且 cross-module）。希望 review 深度匹配改动实际风险，不要把小风险操作拖进完整审查。

## 3. 核心假设

**review 引入深度分级（quick / full），L4 signal 按改动类型过滤 → 小风险场景 review 耗时显著下降，高风险场景保持完整深度。**

验证方式：同一 sprint 场景分别走 quick 和 full，quick 耗时 ≤ full 的 40%，结论对 L1/L4 关键 signal 保持一致。

## 4. 方案

- **Before**: risk=yes 的任何改动都走完整 5 层分析 → **After**: review 根据改动类型选 quick（L1 + L4 关键 signal）或 full（L1-L5），用户可覆盖
- **Before**: L4 每次全扫 12+9 个 signal → **After**: L4 按改动类型过滤——新增 public API 才检测 one-off-as-interface，修改已有函数才检测 patch-on-patch 等

### 深度分级规则

| 场景 | 推荐深度 | 理由 |
|------|---------|------|
| 删除/迁移（少量文件） | quick | 主要看残留风险 + 模式扩散 |
| 添加新功能（单模块） | quick → full（用户选） | 默认快，重要场景升级 |
| 架构重构 / 跨模块 | full | 需要结构+演进全面评估 |

### 任务

| 任务 | 文档 | 进度 |
|------|------|------|
| review 深度分级 + signal 过滤 | [tech](impl/tech.md) | 0/0 |

## 5. 验收标准

- 触发 review 时 → 自动推荐深度（quick / full），用户可覆盖
- quick 深度输出 → 包含 L1 + L4 关键 signal，不包含 L2/L3/L5
- full 深度输出 → 5 层全部包含，与当前行为一致
- L4 signal 扫描 → 只检测与改动类型匹配的 signal（新增 API、修改函数、删除、重构各自有对应 signal 子集）
- 改动类型不匹配的 signal → 不出现在输出里（不是"无此 signal"提示，是完全省略）

## 6. 排除项

- 引入超过 2 个深度档（quick/full 二元足够，custom 放 v5+）
- 用户自定义 signal 集（使用内置映射）
- 跨 review 结果对比
