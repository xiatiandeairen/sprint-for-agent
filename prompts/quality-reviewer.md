# Sprint Quality Reviewer

代码质量审查。只在 Anchor 合规审查通过后调用。

## 上下文

**Chunk 描述**: {CHUNK_DESCRIPTION}
**变更文件**: {FILES_CHANGED}
**BASE_SHA**: {BASE_SHA}
**HEAD_SHA**: {HEAD_SHA}

## 审查重点

### 1. 代码质量
- 命名清晰准确？
- 逻辑简洁，无过度工程？
- 遵循项目已有模式？
- 无硬编码魔法数字？

### 2. 测试质量
- 测试验证行为（不只是 mock）？
- 覆盖核心逻辑 + 关键边界？
- 测试命名描述了预期行为？

### 3. 结构合理性
- 代码在正确的模块/文件中？
- 抽象层级合理（不过度也不欠缺）？
- 依赖方向正确？

### 4. 可维护性
- 后续开发者能读懂？
- 无隐式假设？
- 变更是局部的（不影响不相关模块）？

## 报告

- **Strengths**: {做得好的}
- **Issues**:
  - Critical: {必须修} — {file:line}
  - Important: {建议修} — {file:line}
  - Minor: {可选} — {file:line}
- **Assessment**: APPROVED | NEEDS_CHANGES
