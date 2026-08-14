---
name: forge-refactor
description: Use when restructuring code without changing existing behavior or external API contracts under test protection.
---

# forge-refactor — 行为保持型代码重构

> **C 前缀表示 Refactor / 横向命令**，不属于任何 change，不写 CHANGE.md / REQUIREMENT.md。直接产出代码重构提交 + 契约无损验证报告。

## Goal

在不改变现有业务行为和外部 API 契约的前提下，重构代码结构、降低复杂度、消除重复并改善可维护性。

## 触发条件

**应该触发本 skill：**
- 既有代码结构混乱（巨型函数、深度嵌套、重复逻辑、依赖倒挂），需要在不改行为的前提下理顺结构
- 用户明确要求"纯重构 / 重构不改行为 / 保持契约不变"
- 目标模块已有测试保护，或愿意先经 forge-test 补齐测试

**不该触发，转交对应 skill：**
- 加新功能 / 改变业务行为 → **forge-dev**（TDD 开发流水线）
- 修 bug（现有行为本身就是错的）→ **forge-fix**（RED 重现测试 + 根因修复）
- UI 视觉调整 / 换调性 → **forge-restyle**
- 上线失败需止血回滚 → **forge-rollback**
- 清理无关死代码 / 技术债巡检 → **forge-health**

## 边界

- **改动中发现必须改变业务行为**（正确性缺陷、契约冲突、需求矛盾）→ **立即停下**，转 forge-dev 处理（若属缺陷修复则转 forge-fix），禁止夹带在重构里
- **改动规模过大**（单次 diff 影响面失控）→ **拆批执行**，一次只重构一个关注点，每批独立跑通测试后再进下一批，避免巨型 diff
- 只重构目标模块，不顺手清理无关文件（那是 forge-health 的职责）

## 输入与产出

**输入：**
- 目标模块代码（明确 `read_files` / `write_files` 边界）
- 既有测试套件（作为行为基线）

**产出：**
- `references/REFACTOR.md` 报告（重构前后结构对比、复杂度变化、契约无损验证结论）
- 代码重构提交（原子提交）

**前置条件：**
- 目标模块缺少测试保护时，先经 forge-test 补回归测试，测试保护到位前不动重构

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

1. 确认公共 API 签名、HTTP 接口格式及数据库 Schema 未发生任何破坏性变动。
2. 运行全量测试套件，确认测试结果与重构前完全一致（0 测试修改，0 行为改变）。

## Constraints

- 严禁在重构过程中顺便增加新 feature 或改变既有业务逻辑
- 严禁通过修改测试断言来使重构后的代码通过测试
- 单次重构只处理一个关注点，禁止一次性推翻多个模块的巨型 diff；提交前按 R6.5 做 diff 边界 verify
- 需要改动公共导出 / 公共 API 时按 R4.6 走破坏性变更协议（grep 引用图 + 反问用户），否则视为契约破坏

## Validation

- [ ] 重构前测试 100% 跑通
- [ ] 公共 API 签名与接口契约未发生改动
- [ ] 重构后原测试套件无需任何修改且 100% 跑通
- [ ] 重构 diff 已控制在单一关注点内，无巨型 diff（按 R6.5 verify）
- [ ] 未夹带新功能 / 无关代码修改（范围控制 R7.1 / R7.2）

## Resources

- `references/REFACTOR.md` — 行为保持型重构报告模板
