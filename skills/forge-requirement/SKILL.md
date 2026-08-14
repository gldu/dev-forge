---
name: forge-requirement
description: Use when analyzing user specifications, drafting REQUIREMENT.md, or converting user intent into formal requirements.
---

# forge-requirement — 需求分析

## Goal

把 CHANGE.md 的粗粒度想法通过反问澄清为可执行需求，提取域语言到 CONTEXT.md。

## 触发条件

何时触发：
- CHANGE.md 已有粗粒度想法（问题描述 + 期望方向），需要细化为可执行需求（用户故事 / AC / 范围切分）
- 需求存在歧义或不可验证点，需要停下来反问澄清
- 流水线从 forge-change 进入需求阶段（R2.1 门禁：没有 CHANGE.md 不能进 REQUIREMENT）

何时不该触发，转交别的 skill：
- 用户只有一个模糊想法、还没有 CHANGE.md → 先跑 `forge-change` 生成变更提案，本 skill 不接收无 CHANGE 的输入
- 纯技术实现方案讨论（选型 / 架构 / 模块拆分）→ `forge-design`

## 与 forge-change 的边界

| 工作流 | 干什么 | 粒度 | 产出 |
|---|---|---|---|
| **forge-change** | 澄清想法、判定影响面、给出后续路径 | 粗粒度（决定"做什么"）| `.specs/<id>/CHANGE.md` |
| **forge-requirement**（本文）| 把 CHANGE 细化为可验证需求 | 细粒度（决定"做成什么样才算好"）| `.specs/<id>/REQUIREMENT.md` + CONTEXT.md 追加 |

若 CHANGE.md 已包含完整 AC：本 skill 只做校验补漏（对照 Validation 清单），**不重写**已锁定的内容。

## CONTEXT.md 幂等规则

在 `.specs/CONTEXT.md` 追加任何术语 / 决策前，先 grep 是否已存在同名条目：

    grep "术语名" .specs/CONTEXT.md

- 已存在 → 直接引用既有定义，不重复定义
- 不存在 → 追加一条一句话定义
- 同一概念只保留一条定义；别名用「见 XXX」指向主条，不单开新条

## Workflow

### 1. 写需求

使用 `references/REQUIREMENT.md` 模板填写：

- **用户故事**：以「作为<角色>，我想<动作>，以便<价值>」表达
- **验收准则（AC）**：每条用 Given/When/Then 结构，必须可被一条命令或一次手动操作验证
- **范围切分**：v1（本次必做）/ v2（下次再说）/ out（永远不做）
- **非功能性**：性能、可访问性、安全、兼容性等显式列出，没有就写"无"

### 2. 提取域语言（关键步骤）

在 `.specs/CONTEXT.md`（项目级）里**追加**或更新：
- **术语表**：本次引入的新名词，每个一句话定义
- **已锁决策**：本次确定的偏好
- **默认行为**：留给 AI 的可信默认值

> 域语言是 token 优化的基石。"主题切换的级联触发" 比展开描述短得多，但要先在 CONTEXT.md 里定义清楚。

### 3. 反问

任何不能被一句话验证的 AC，必须停下来反问。例：
- "界面要好看" → 反问："好看的标准是什么？是否对照某个设计稿？"
- "Lighthouse Performance >= 90" → 直接可验证

## Constraints

- 不允许写"如何实现"（那是 DESIGN 的事）
- AC 必须能被验证；不可验证的 AC 视为不合格
- 范围排除（v2 / out）至少各 1 条，否则说明范围切分还不够
- CONTEXT.md 追加遵循幂等规则：同名术语只保留一条定义，先 grep 后追加

## Validation

- [ ] 每条 AC 都有 Given/When/Then 结构
- [ ] 每条 AC 都能用一条命令或一次操作验证
- [ ] CONTEXT.md 至少新增 1 条术语或决策
- [ ] v1 / v2 / out 三类都有内容
- [ ] 范围切分 v1 / v2 / out 已与用户确认
- [ ] CONTEXT.md 无重复术语定义（追加前已 grep 同名术语）
- [ ] 非功能性需求显式列出（含"无"也要写）

## Resources

- `references/REQUIREMENT.md` — 产出模板
- `.specs/CONTEXT.md` — 项目级域语言/术语表（追加模式，模板见 `forge-intel-scan/references/CONTEXT.md`）
