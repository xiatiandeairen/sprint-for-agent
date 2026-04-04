---
name: auto
description: 自动执行模式。门禁兜底，失败自动回退重试，连续 WARN 停止等人
---

# Sprint Auto

和 `sprint:go` 相同流程，以下区别：

## 前置条件

同 `sprint:go`。

## 通用规则

同 `sprint:go`。

## 区别

1. **去掉人审查**（Step 7）
2. **新增 quality-reviewer**：anchor-reviewer 通过后 dispatch
   - 读取 `src/plugins/sprint/prompts/quality-reviewer.md`
   - Model: sonnet
   - NEEDS_CHANGES → implementer 修复 → re-review
3. **门禁更严**：
   - diff 预算 × 0.8
   - 连续 2 个 WARN → 停止等人
4. **失败自动处理**：
   - 门禁 FAIL → `git revert HEAD` → 重新 dispatch implementer（重试 1 次）
   - 重试 FAIL → 停止等人
5. **最终交付**：必须有人做 final review

## Chunk 循环

同 `sprint:go` 的 Step 1-6 + Step 8，跳过 Step 7（人审查），增加 quality-reviewer。
