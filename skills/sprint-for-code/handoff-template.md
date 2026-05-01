# Handoff 模板

## 初始模板

创建归档时复制本段代码块内容到 `$SPRINT_DIR/$SPRINT_SID.md`，替换占位符。

```
---
id: {SPRINT_SID}
type: sprint
desc: {desc}
stages: [{stage_list}]
sequence: {执行序列字符串}
status: running
created: {now ISO8601}
---

# Sprint Handoff — {desc}
```

占位符替换说明：

- `{SPRINT_SID}` — §3 变量
- `{desc}` — 用户输入
- `{stage_list}` — §4.1 已挂载 stage 列表（如 `[plan, implement, verify]`）
- `{执行序列字符串}` — §4.1 step 1 得到的序列（如 `plan → loop(implement → verify) until pass, max=3`）
- `{now ISO8601}` — 创建时刻（UTC）

后续每个 stage 完成时由 §4.3 step 3 append 章节，loop 内最后 stage 在 frontmatter 追加/更新 `loop_round` 和 `loop_result`，§4.4 收尾时更新 `status` + `completed_at`。

## 完整示例

场景：修登录失败 bug，编排 `plan → loop(implement → verify) until pass, max=3`，循环跑 2 轮 pass。

```
---
id: 20260501-103045-123
type: sprint
desc: 修登录失败 bug
stages: [plan, implement, verify]
sequence: plan → loop(implement → verify) until pass, max=3
status: completed
created: 2026-05-01T10:30:45Z
completed_at: 2026-05-01T10:42:18Z
loop_round: 2
loop_result: pass
---

# Sprint Handoff — 修登录失败 bug

## 1. plan
<!-- ts: 2026-05-01T10:32:01Z -->

### 文件清单
- src/auth.ts
- src/session.ts

### 任务拆分
1. auth.ts: 修复 token 解析在过期时的空指针
2. session.ts: 加 session 过期前的自动刷新

## 2. implement (循环第 1 轮)
<!-- ts: 2026-05-01T10:35:18Z -->

### 改动
- src/auth.ts:42 加 null check
- src/session.ts:88 加 refreshIfExpiringSoon()

## 3. verify (循环第 1 轮)
<!-- ts: 2026-05-01T10:36:02Z -->

### 测试结果
- npm test: 11/12 pass
- FAIL: auth.test.ts:42

(此节末 frontmatter 写入 loop_round: 1, loop_result: fail；不满足 pass，继续循环)

## 4. implement (循环第 2 轮)
<!-- ts: 2026-05-01T10:39:55Z -->

### 改动
- src/auth.ts:42 修正 null check 顺序

## 5. verify (循环第 2 轮)
<!-- ts: 2026-05-01T10:42:18Z -->

### 测试结果
- npm test: 12/12 pass

(此节末 frontmatter 更新为 loop_round: 2, loop_result: pass；满足 pass，跳出循环)
```
