## Rule

Sprint 流程中的确认点必须携带用户未见过的新信息。无决策内容的 stage 转换和无上下文的中间产物不设确认。

## Why

v4 sprint 中用户指出两个问题：
1. design → plan 转换时问"确认继续？"但用户没有新信息可判断
2. plan Gate 跳过 Step 1/2 后直接展示 anchor 列表让确认，用户不知道在确认什么

根因：stage 转换规则不区分有无决策，所有转换一律确认。

## How to check

- stage handoff 确认后 → 自动进入下一 stage，不再问"确认继续？"
- Gate 跳过前置步骤时 → 剩余步骤合并为一次展示 + 一次确认
