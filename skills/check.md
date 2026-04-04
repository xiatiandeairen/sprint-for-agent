---
name: check
description: 手动运行质量门禁（9 项检查）。修复问题后用此命令验证
---

# Sprint Check

手动运行门禁（修复后重新检查）。

## 执行

读取 `.sprint/state.json` 获取 anchor_path 和 current_chunk：

```bash
bash "src/plugins/sprint/scripts/gate.sh" "{anchor_path}" {chunk_number}
```

展示结构化门禁报告。如果 PASS，更新 state.json 的 last_gate 状态。
