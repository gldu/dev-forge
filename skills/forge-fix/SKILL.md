---
name: forge-fix
description: Use when reproducing, diagnosing, and fixing bugs, defects, or test failures before writing implementation code.
---

# forge-fix — 缺陷诊断与复盘修复

## Goal

通过严谨的测试驱动方法诊断与修复 Bug，确保先通过测试重现问题、定位根因后再进行最小化修复，并将失败教训沉淀至项目知识库。

## Workflow

### 1. 缺陷重现 (RED 阶段 · 强制)

在修改任何业务代码之前：
1. 根据用户描述或错误日志，编写一个能 **100% 稳定重现 Bug** 的失败单元测试或集成测试。
2. 运行该测试，确认测试输出预期的失败信息。
3. **禁止绕过本步直接修改代码**。未通过测试重现的 Bug 修复视为不合格。

### 2. 日志与根因定位

1. 读取完整的 Error Stack Trace 和运行时日志。
2. 遵循反假设原则：根据日志与断点证据推导根因，禁止盲目修改或吞掉异常。
4. **grep 回退**：`grep -rn "<符号/方法名>" src/` 查引用图。

### 3. 最小化修复 (GREEN 阶段)

1. 编写最少量的代码使重现测试通过 (GREEN)。
2. 运行全量测试套件，确保修复未引发任何回归问题 (Regression)。
3. 遵循防护原则：严禁通过注释断言、返回 Dummy 假数据或吞掉异常来“解决”报错。

### 4. 重构与知识沉淀 (REFACTOR 阶段)

1. 在测试保护下重构修复逻辑，消除临时代码。
2. 将本次 Bug 的触发原因、根因分析及防范建议追加至 `.specs/LESSONS.md`。

## Constraints

- 严禁在没有重现测试的情况下直接修改业务代码
- 严禁通过修改或删除原测试断言来伪造修复成功
- 破坏性修复（涉及导出接口变动）必须先警告用户

## Validation

- [ ] 已编写可稳定重现 Bug 的失败测试
- [ ] 运行测试证明代码修改后测试变绿
- [ ] 全量回归测试全部通过
- [ ] 修复教训已写入 `.specs/LESSONS.md`

## Resources

- `references/FIX.md` — 缺陷排查与修复报告模板
- `.specs/LESSONS.md` — 失败教训知识库
