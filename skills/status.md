---
name: status
description: 显示当前 sprint 进度、chunk 指标、衰减警告
---

# Sprint Status

显示当前 sprint 状态和指标。

## 执行

```bash
bash "src/plugins/sprint/scripts/sprint-ctl.sh" status
```

如果有衰减警告，一并展示：
```bash
bash "src/plugins/sprint/scripts/chunk-metrics.sh" --decay-check
```

展示结果。
