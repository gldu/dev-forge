---
name: forge-design
description: Use when creating technical design specifications, choosing tech stacks, or building DESIGN.md for an active change.
---

# forge-design — 技术设计

## Goal

把需求转化为可执行的技术设计，确保 brownfield 项目沿用既有架构，每个决策都有理由和代价。

## Workflow

### 0.0 架构级变更预检（二次保险）

如果 CHANGE.md 末尾已有「架构层影响声明」或「走 A-architect 后回来」标记 → 跳过。

否则按 0-change §0.4 的 5 条标准重新判定：
- 命中 + ARCHITECTURE.md 存在 → 检查 ADR 冲突，提示在 §1 显式声明 supersede 关系
- 命中 + ARCHITECTURE.md 不存在 → 反问用户：先跑 forge-architect / 继续但强制加 ADR 声明 / 重判
- 未命中 → 直接进步骤 0

### 0. 技术栈预选（独立一条消息，等用户选定）

**例外（可跳过）**：
- CONTEXT.md 已有「已锁技术决策」→ 直接读用
- 用户描述含强偏好 → 锁定后跳过
- 纯库/SDK/CLI → 只选语言

**常规路径**：
加载 `references/tech-stacks-excerpt.md`，按「适用矩阵」过滤出 5~6 张最匹配卡片：
- 5~6 张卡片（编号 + 名称 + 一句话栈描述）
- **必给 1 首选 + 1 备选**，理由结合 REQUIREMENT.md 的 AC + 非功能需求
- **显式排除** 1~2 个 + 理由
- 末尾：`请回复数字（如 "1"）或描述偏好，选定后我才出具体 ADR 与架构图。`

**选定后**：写入 DESIGN.md「## 0. 技术栈选定」段，后续所有设计基于这个栈展开。

### 0.5 既有架构对齐（brownfield 必跑）

**触发**：CONTEXT.md 存在且非空。**新创项目跳过**。

#### 0.5.1 列出本次 change 会触碰的既有模块

**代码探索（双轨机制）**：
- **【优先 · CodeGraph】**：`codegraph_explore(query="identify modules, symbols, and blast radius affected by <change_keywords>")`
- **【回退 · grep/glob】**：基于 REQUIREMENT.md 和 CONTEXT.md，grep 出实际会涉及的模块：

明确列出：
- 触碰模块（既有 · 来自 CodeGraph / grep）
- 新增模块
- 禁动清单（与本次无关，AI 不许"顺手"碰）

#### 0.5.2 对齐既有抽象（防重复实现）

**代码探索（双轨机制）**：
- **【优先 · CodeGraph】**：`codegraph_explore(query="how is <capability> implemented and can it be reused?")`
- **【回退 · grep/glob】**：按能力关键词 grep 既有工具函数与抽象层。

针对本次 change 需要的能力，先问已有的能不能用。禁止"顺便引入 X 库"——必须写出为什么不用既有的才能引新。

#### 0.5.3 沿用模式 vs 引入新模式

显式声明每个关键决策的选择。引入新模式必须有充分理由。

#### 0.5.4 写入 DESIGN.md

把上面三段写入 DESIGN.md「## 0.5 既有架构对齐」段。

### 1. 技术决策（每条都要有理由）

格式：决策 → 备选 → 选择理由 → 取舍代价

### 1.1 架构 Grill-me 审视（在锁定关键 ADR/架构图前必跑）

在确定重大架构决策（ADR）前，对备选方案进行多维压力追问：
- **容量与可扩展性 Grill**："如果数据量或 QPS 增长 10 倍，该方案最先在哪里崩溃？"
- **过早优化与复杂性 Grill**："方案是否引入了不必要的抽象层或中间件？（YAGNI 检查）"
- **故障退化与灾备 Grill**："如果核心依赖/第三方 API 响应超时或不可用，系统如何优雅降级？"
- **维护与新人接手 Grill**："新成员接手本模块时，最容易产生认知误区的地方在哪？"

### 2. 数据流 / 架构图

使用 ASCII 框图或 Mermaid。说明数据/事件流向、关键状态机、边界。

### 3. ADR

凡是「以后可能被推翻」的决策，单独写一份 ADR 到 `.specs/adr/<NNN>-<title>.md`。

### 4. 风险

至少列 3 条：实现风险 / 上线风险 / 长期债务。每条给缓解方案。

### 5. 不在范围内

显式列出这次设计不解决但未来需要的问题。

### 9. 架构沉淀建议（软约束 · 为 forge-evolve 准备素材）

本 change 如果引入了"项目级有复用价值"的东西，记在这里。以后 forge-evolve 会扫这段批量同步到 CONTEXT.md。

**入选阈值**（任一）：
- 新增可复用抽象（以后别的场景也用得到）
- 项目级技术决策（"以后都这么干"的取舍）
- 跨模块契约（新增/修改公共 API/Schema/事件总线）
- 依赖变动（新增/升级/替换核心包）
- 禁动清单变动

**没有就整段写「本 change 无架构层面沉淀建议」，不要凑数。**

## Constraints

- **R3.1**：禁止给具体代码实现（伪代码可，函数签名可，完整函数体不可）
- 每条决策必须给理由 + 取舍
- 不允许"使用最佳实践"这类无意义短语

## Validation

- [ ] 技术栈已锁定（## 0 段填齐）
- [ ] 既有架构对齐已写入（brownfield 必跑 · ## 0.5 段齐全）
- [ ] 每条决策都有「备选 + 理由 + 代价」
- [ ] 至少一张数据流/架构图
- [ ] 风险 >= 3 条且每条有缓解
- [ ] 大的或可逆性低的决策都有对应 ADR
- [ ] 不含完整代码实现
- [ ] §9 架构沉淀建议已写（有就填表，没有就写"无建议"，禁凑数）

## Resources

- `references/DESIGN.md` — 产出模板
- `references/tech-stacks-excerpt.md` — 技术栈卡片节选（适用矩阵 + 模板）
