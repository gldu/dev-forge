---
name: forge-refactor
description: Use when restructuring code without changing existing behavior or external API contracts under test protection.
---

# forge-refactor — 行为保持型代码重构

## Goal

在不改变现有业务行为和外部 API 契约的前提下，重构代码结构、降低复杂度、消除重复并改善可维护性。

## Workflow

### 1. 确认测试保护网 (Test Coverage Gate)

在改动任何代码之前：
1. 运行目标模块的全部测试，确认测试套件 **100% 跑通 (GREEN)**。
2. 若缺乏测试保护，先使用 `forge-test` 补齐回归测试，确保覆盖率足够防护重构。

### 2. 行为保持型重构 (Refactoring)

在测试保护下应用结构优化：
- **拆分认知过载**：解耦超过 50 行的巨型函数、消除深度嵌套。
- **消除知识重复**：抽取可复用公共函数或抽象组件。
- **依赖倒置**：解耦具体实现与业务接口。

### 3. API 契约与 diff 边界校验

2. 确认公共 API 签名、HTTP 接口格式及数据库 Schema 未发生任何破坏性变动。
3. 运行全量测试套件，确认测试结果与重构前完全一致（0 测试修改，0 行为改变）。

## Constraints

- 严禁在重构过程中顺便增加新 feature 或改变既有业务逻辑
- 严禁通过修改测试断言来使重构后的代码通过测试

## Validation

- [ ] 重构前测试 100% 跑通
- [ ] 公共 API 签名与接口契约未发生改动
- [ ] 重构后原测试套件无需任何修改且 100% 跑通

## Resources

- `references/REFACTOR.md` — 行为保持型重构报告模板
