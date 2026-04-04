---
name: end
description: 结束当前 sprint。输出最终指标、观察日志、改进建议
---

# Sprint End

结束 sprint 并输出总结。

## 执行

```bash
bash "src/plugins/sprint/scripts/sprint-ctl.sh" end
```

展示：
- 最终指标摘要
- 观察日志（`.sprint/observations.md`）内容
- 建议后续处理的改进项
