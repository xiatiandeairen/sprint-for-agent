---
name: long
description: 方向驱动循环。用户给方向，AI 自主拆解目标并循环执行子 sprint
---

# Long Task

核心价值：**方向驱动的可控循环** — 用户只给方向，AI 自主拆解为可验证目标，每轮用子 sprint 推进一个目标，通过 ROI 和风险预警保证方向不偏、质量不腐、过程不偷懒。

> 本文件是执行指令。必须按「步骤」段逐步执行，每步验证「完成标志」后才进下一步。

<HARD-RULE>
1. 每轮子 sprint 完成后必须跑 long-risk，不是口头说没问题。
2. ROI 下降或方向偏移时必须暂停等用户介入，不能自行决定继续。
3. 子 sprint 是独立的完整 sprint，走常规流水线，不跳阶段。
</HARD-RULE>

## 输入

| 字段 | 来源 | 必需 | 校验 |
|------|------|------|------|
| 方向描述 | 用户输入 | 是 | 非空 |
| sprint ID | entry.md | 是 | DB 中 type=long |

## 输出

| 产出 | 路径 | 消费方 | 聚焦内容 |
|------|------|--------|---------|
| 目标清单 | DB long_task_goals | 每轮检查 | 可验证目标 + 完成状态 |
| 轮次记录 | DB long_task_rounds | 风险检查 + 报告 | 成本/ROI/风险 |
| 总结报告 | `{sprint}/reports/long-summary.md` | 人看 | 目标完成 + ROI 趋势 + 风险 |

## 步骤

### Phase 1: 方向分析

#### Step 1: 扫描现状

**做什么**: 理解项目当前状态，为目标拆解提供素材
**怎么做**:
- 读方向描述
- 扫描相关代码/文档/近期 commit
- 列出现状事实（>= 3 个）

**完成标志**: 能列出现状 + 改进空间

#### Step 2: 拆解目标 [STOP:confirm]

**做什么**: 将方向转化为可验证的目标清单
**怎么做**:
- 每个目标必须可验证（有检查命令或可观测的结果）
- 目标按优先级排序（高 ROI 的排前面）
- 目标数量 3-7 个（太少说明方向太窄，太多说明方向太散）

呈现目标清单给用户确认：
```
目标清单:
  [ ] #1: {描述} | 验证: {检查方式}
  [ ] #2: {描述} | 验证: {检查方式}
  ...
退出条件: {轮次上限} 轮 或 全部完成
```

用 Bash 工具执行：
```bash
bash "$SPRINT_PLUGIN/scripts/sprint-ctl.sh" long-goal "{id}" add "{desc}" "{verify}"
```

**完成标志**: 用户确认目标清单 + 所有目标已写入 DB

### Phase 2: 循环执行

对每个待完成目标，执行一轮子 sprint：

#### Step 3: 选目标 + 规划子 sprint

**做什么**: 选择下一个要推进的目标，规划子 sprint
**怎么做**:
- 查看待完成目标（long-goal list）
- 选优先级最高的 pending 目标
- 评估该目标适合什么类型的 sprint（simple/medium/complex）
- 预估成本（diff 行数）

**完成标志**: 选定目标 + 子 sprint 类型 + 成本预估

#### Step 4: 执行子 sprint

**做什么**: 创建并执行子 sprint
**怎么做**:

1. 记录轮次开始：
```bash
bash "$SPRINT_PLUGIN/scripts/sprint-ctl.sh" long-round "{parent_id}" start "{child_id}" {est_cost}
```

2. 创建子 sprint（带 parent_id 参数）：
```bash
bash "$SPRINT_PLUGIN/scripts/sprint-ctl.sh" create "{type}" "{desc}" "{stages}"
```

3. 按子 sprint 类型走常规流水线（读对应 stage 文件执行）

4. 子 sprint 完成后统计实际 diff：
```bash
git diff --stat {base_commit}..HEAD | tail -1
```

5. 记录轮次结束：
```bash
bash "$SPRINT_PLUGIN/scripts/sprint-ctl.sh" long-round "{parent_id}" end "{child_id}" {actual_cost}
```

**完成标志**: 子 sprint completed + 轮次记录完整

#### Step 5: 更新目标

**做什么**: 检查这轮推进了哪些目标
**怎么做**:
- 逐个 pending 目标，执行其验证方式
- 通过的标记 achieved：
```bash
bash "$SPRINT_PLUGIN/scripts/sprint-ctl.sh" long-goal "{parent_id}" achieve {seq} "{child_id}"
```

**完成标志**: 目标状态已更新

#### Step 6: 风险检查 [用 Bash 执行]

**做什么**: 检测方向偏移/ROI下降/质量恶化
**怎么做**:
```bash
bash "$SPRINT_PLUGIN/scripts/sprint-ctl.sh" long-risk "{parent_id}"
```

处理结果：

处理结果 [BRANCH]：

| 条件 | 路径 |
|------|------|
| status=ok | → 继续下一轮 |
| status=warn | → [INFO:warn] 输出警告，继续 |
| status=halt | → [STOP:confirm] 暂停，输出预警，等用户介入 |

**完成标志**: 风险检查执行 + 结果已处理

#### Step 7: 退出条件检查

**做什么**: 判断是否继续循环
**怎么做**:

| 条件 | 检查方式 | 动作 |
|------|---------|------|
| E1 所有目标完成/放弃 | long-goal list 无 pending | 退出循环 |
| E2 轮次上限 | 当前轮次 >= 配置上限（默认 5） | 退出循环 |
| E3 用户终止 | 用户说「够了」 | 退出循环 |

未满足退出条件 → 回到 Step 3

**完成标志**: 继续或退出已决定

### Phase 3: 总结

#### Step 8: 生成总结报告

**做什么**: 汇总所有轮次数据
**怎么做**:

1. 用 Bash 工具执行：
```bash
bash "$SPRINT_PLUGIN/scripts/sprint-ctl.sh" long-summary "{parent_id}"
```

2. 将输出写入 `{sprint}/reports/long-summary.md`

**完成标志**: 报告文件存在

#### Step 9: 用户确认 [STOP:choose]

**做什么**: 呈现总结，用户确认
**怎么做**: 展示报告 + 问后续操作：
- A. 合并到 main / 创建 PR
- B. 继续追加轮次
- C. 结束

**完成标志**: 用户选择了后续操作

## 提前终止

| 条件 | 行为 |
|------|------|
| 用户说「直接结束」 | 跳到 Phase 3 |
| 子 sprint 失败且用户放弃 | 记录，跳到 Phase 3 |
| 风险预警 halt 且用户选放弃 | 跳到 Phase 3 |

## 验证清单 [CHECKLIST]

- [ ] 目标清单 >= 3 个且用户确认
- [ ] 每轮子 sprint 有完整的 long_task_rounds 记录
- [ ] 每轮执行了 long-risk
- [ ] halt 时暂停等用户（不自行继续）
- [ ] 总结报告存在
- [ ] [人工] 用户确认总结

## 排查指南

**1. 子 sprint 反复失败**
症状: 连续 2 轮子 sprint failed
处理: 暂停循环，让用户重新评估方向或调整目标

**2. ROI 为 0 但有实际工作**
症状: 改了代码但目标没推进
处理: 目标粒度可能太粗，建议拆分目标

**3. 目标全部 dropped**
症状: 用户放弃了所有目标
处理: 方向本身可能需要重新评估，不是 long task 的问题
