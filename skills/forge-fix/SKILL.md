---
name: forge-fix
description: Use when reproducing, diagnosing, and fixing bugs, defects, or test failures before writing implementation code.
---

# forge-fix — 缺陷诊断与复盘修复

## Goal

通过严谨的测试驱动方法诊断与修复 Bug，确保先通过测试重现问题、定位根因后再进行最小化修复，并将失败教训沉淀至项目知识库。

## 触发条件

- **应触发**：本地 / 开发环境中的 bug、测试失败、构建错误，以及可稳定复现的缺陷（如「修这个报错」「修复 bug」）。
- **不应触发，转交其他 skill**：
  - 线上故障（已发布版本出问题）→ 先评估 `forge-rollback`，回滚优先于现场修复
  - 用户要求的行为变更（不是 bug）→ `forge-dev`
  - 性能不达标（延迟 / QPS / 内存等）→ `forge-perf`

### 与 forge-rollback 的边界

- 线上已发布版本出问题 → 先走 `forge-rollback` 决策：回滚 / 热修 / 重部署三选一，本 skill 不直接对线上做现场修复。
- 其中「热修」路径会回到本 skill：从稳定 tag 切出 hotfix 分支后，由本 skill 编写重现测试 + 最小补丁，再跑通快速测试集部署。
- 本地未发布代码的 bug → 直接走本 skill 完整流程（RED → GREEN → REFACTOR），无需经过 `forge-rollback`。

## Workflow

### 1. 缺陷重现 (RED 阶段 · 强制)

在修改任何业务代码之前：
1. 根据用户描述或错误日志，编写一个能 **100% 稳定重现 Bug** 的失败单元测试或集成测试。
2. 运行该测试，确认测试输出预期的失败信息。
3. **禁止绕过本步直接修改代码**。未通过测试重现的 Bug 修复视为不合格。

### 2. 日志与根因定位

1. 读取完整的 Error Stack Trace 和运行时日志。
2. 遵循反假设原则：根据日志与断点证据推导根因，禁止盲目修改或吞掉异常。
3. **代码探索（双轨机制）**：
   - **【优先 · CodeGraph】**：`codegraph_explore(query="trace call paths from entrypoints to <error_symbol_or_function>")`
     获取从入口点到崩溃位置的完整调用链（包含动态派发与回调），精准定位触发时机。
   - **【回退 · grep/glob】**：`grep -rn "<符号/方法名>" src/` 结合错误堆栈逐层人工排查引用图。

### 3. 最小化修复 (GREEN 阶段)

1. 编写最少量的代码使重现测试通过 (GREEN)。
2. 运行全量测试套件，确保修复未引发任何回归问题 (Regression)。
3. 遵循防护原则：严禁通过注释断言、返回 Dummy 假数据或吞掉异常来“解决”报错。

### 4. 重构与知识沉淀 (REFACTOR 阶段)

1. 在测试保护下重构修复逻辑，消除临时代码。
2. 将本次 Bug 的触发原因、根因分析及防范建议追加至 `.specs/LESSONS.md`。

## 输入与产出

- **输入**：错误日志 / Stack Trace / 用户复现描述 / 失败测试。
- **产出**：
  - `references/FIX.md` — 缺陷排查与修复报告
  - 最小补丁（含重现测试 + 回归测试，R4.3）
  - `.specs/LESSONS.md` — 追加本次修复教训

## Constraints

- 严禁在没有重现测试的情况下直接修改业务代码
- 严禁通过修改或删除原测试断言来伪造修复成功
- 破坏性修复（涉及导出接口变动）必须先警告用户

## Validation

- [ ] 已编写可稳定重现 Bug 的失败测试
- [ ] 根因已定位（不是症状修复）
- [ ] 运行测试证明代码修改后测试变绿
- [ ] 全量回归测试全部通过
- [ ] `.specs/LESSONS.md` 已追加本次修复教训

## Resources

- `references/FIX.md` — 缺陷排查与修复报告模板
- `.specs/LESSONS.md` — 失败教训知识库
