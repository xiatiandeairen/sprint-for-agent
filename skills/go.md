---
name: go
description: 带人工检查的 chunk 循环执行。每个 chunk 经过 implementer → 门禁 → anchor review → 人审查
---

# Sprint Go

## 前置条件

需要已有 anchor.md + chunks.md + 活跃 sprint（通过 `sprint:plan` 创建）。

## 通用规则

1. 所有 subagent 必须注入 Anchor Boundaries + Invariants
2. 每个 chunk 开始前重新读取 anchor.md（re-anchor）
3. 发现改进机会但不在 scope 内 → 追加到 `.sprint/observations.md`
4. 禁止"先跳过后面处理"。每个 chunk 独立达标
5. 门禁失败时不继续下一个 chunk

## 对每个 Chunk 循环

**Step 1: Re-anchor**
重新读取 anchor.md 和 chunks.md，获取当前 chunk 信息。

**Step 2: 推进 chunk**
```bash
bash "src/plugins/sprint/scripts/sprint-ctl.sh" advance
```

**Step 3: Dispatch implementer**
- 读取 `src/plugins/sprint/prompts/implementer.md`
- 替换模板变量：CHUNK_DESCRIPTION, ANCHOR_BOUNDARIES, ANCHOR_INVARIANTS, CHUNK_COMPLETION_CRITERIA
- Model 选择：sonnet（默认）/ opus（跨 3+ 文件接口变更或架构判断时）

**Step 4: 自动门禁**
```bash
bash "src/plugins/sprint/scripts/gate.sh" "{anchor_path}" {chunk_number}
```
- FAIL → 停止。输出报告，要求修复。修复后重跑门禁。
- WARN → 输出警告，继续。
- PASS → 继续。

**Step 5: Dispatch anchor-reviewer**
- 读取 `src/plugins/sprint/prompts/anchor-reviewer.md`
- 替换：FULL_ANCHOR_CONTENT, IMPLEMENTER_REPORT
- Model: sonnet
- ❌ → implementer 修复 → re-review
- ✅ → 继续

**Step 6: 生成 Decision Summary**

```markdown
### Chunk {N} — {一句话}

**决策点**: {Y/N 问题列表，没有就写"无"}
**门禁**: {G1-G9 状态摘要}
**观察**: {implementer 报告的 observations}
**下一步**: {下一个 chunk 的预告}
```

**Step 7: 人审查**

🔴 **深度审查**（Chunk 1 + 每 3-4 个 + 最后）：
- 展示 Decision Summary + 当前代码状态快照
- 建议用户跑 app
- 等待：✅ 继续 / 🔄 调整 / ⏪ 回退

🟡 **快速审查**（其余）：
- 展示 Decision Summary（30 秒可读）
- 等待：✅ 继续 / 🔄 调整 / ⏪ 回退

**Step 8: Commit + 更新状态**

### 回退处理

⏪ 时：`git revert HEAD` → 更新 chunks.md → 讨论下一步

### 循环结束

所有 chunk 完成后：
1. 运行全量测试
2. 输出指标摘要（`sprint-ctl.sh status`）
3. 展示 `.sprint/observations.md`
4. 建议最终 review
5. 执行 `sprint-ctl.sh end`
