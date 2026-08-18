---
name: forge-change
description: Use when starting a new change proposal, initializing CHANGE.md, or defining scope for new features without an active change.
---

# forge-change — 变更提案

## Goal

把用户的模糊想法通过结构化反问澄清为一份变更提案，并判定影响面、给出后续路径建议。

## Workflow

### 0. 自动生成 change-id

- 从用户描述提取核心关键词，转成 kebab-case（小写、短横线分隔、英文）
- 长度 2~4 个词。例：「设计陪诊网站」→ `companion-platform`；「加个深色模式」→ `dark-mode`
- 检查 `.specs/<id>/` 不存在，若冲突自动加序号 `<id>-2`、`<id>-3`
- 在反问的第一条消息里向用户显式声明：
  ```
  自动生成 change-id：`<id>`（不满意请告诉我新的，否则继续。）
  ```
- 用户没纠正就照用，**不要等确认**

### 0.4. 架构级变更检测（必跑）

**目的**：检测是否涉及项目级架构变更（拆服务 / 换数据库 / 换鉴权方案等），这类变更应先在 ARCHITECTURE 层达成共识。

**代码探索（双轨机制）**：
- **【优先 · CodeGraph】**：`codegraph_explore(query="blast radius and affected modules for changing <module_or_feature>")`
  - 返回 blast-radius 涉及 affected_modules >= 3 或跨核心子系统边界 → 命中架构级变更
  - 返回局部变更且 affected_modules < 3 → 非架构级
- **【回退 · grep/glob】**：按以下 5 条标准启发式判定。

**命中任一即触发**：
1. 影响项目级模块结构（新增/拆分/合并/删除模块）
2. 影响已有 ADR（与 ARCHITECTURE.md §3 冲突或要新增不可逆决策）
3. 改公共契约（API 风格 / 事件总线协议 / Schema 主键策略）
4. 影响容量边界（触发 ARCHITECTURE.md §6 预警阈值）
5. 跨服务编排（容器化 / 上云 / 多区域 / 多租户）

**明确不算架构级**：在既有架构内加新 feature / 业务模块；在既有抽象上加适配器；bug 修复 / UI 改版 / 文案改动。

**命中后反问用户**：
```
检测到本次涉及项目级架构变更。选项：
1. 先跑 forge-architect（推荐 · 重审 ADR + 更新模块图）
2. 我清楚影响，继续 forge-change（DESIGN 会显式声明对 ADR-NNN 的影响）
3. 这其实是 change 级局部改造（请说明理由，我重判）
```

- 选 1：暂停本 skill，引导用户跑 forge-architect。已生成的 change-id 暂留，完成后复用
- 选 2：继续，但强制在 CHANGE.md 末尾加「架构层影响声明」
- 选 3：用户给解释，AI 重新判断

### 0.5. 前端项目识别

描述包含以下任一 → 判定为前端项目：网站/网页/页面/web/app/应用/移动端/小程序/dashboard/后台/界面/UI/前端/用户端/客户端/GUI

非前端项目（CLI / 后端 API / lib / SDK）跳过 0.55 和 0.6。

### 0.55. 已有 UI 探测（仅前端项目，必跑）

**目的**：仓库里已经有前端时，禁止再出 9 张调性卡片。

**视为已有 UI（命中任一）**：
1. `.specs/**/UI-DESIGN.md` 或 `.specs/archive/**/UI-DESIGN.md`
2. 上一份 CHANGE.md 已有「视觉调性」且「选定」非空
3. 存在实际 UI 实现：页面/组件，以及 token / theme 源（`tailwind.config.*` / `:root` CSS variables / `theme.*` / design tokens 文件）

**用户这句已在说换风格**（换调性 / 改风格 / restyle / 重做 UI / 重新做视觉）→ 不沿用。整库换调性优先引导 `forge-restyle`；若用户坚持在本次 change 里选新调性，走 0.6 预选支。

- 命中已有 UI 且不是换风格 → 走 0.6 **沿用支**。**禁止**贴 9 张卡片。
- 未命中 → greenfield，走 0.6 **预选支**。

### 0.6. 视觉调性（仅前端项目）

#### 沿用支（0.55 命中已有 UI）

按顺序推断调性，取第一条能锁定「编号 + 名称」的：
1. 最近一份 `UI-DESIGN.md` 的调性字段
2. 最近一份 CHANGE.md「视觉调性」
3. 从 token / theme / 3 个代表页面反推 9 调性中最接近的一张

写入 CHANGE.md「视觉调性」：**来源**填「沿用既有 UI」，**证据**写路径。

**一句话告知，不等数字、不等确认**：
```
沿用现有调性：<编号> <名称>（来自 <路径>）。要换请走 forge-restyle。
```

然后直接进步骤 1。本支**禁止**加载或展示 `ui-aesthetics-excerpt.md` 的 9 张卡片模板。

#### 预选支（greenfield，或用户要换风格且继续走 change）

**红线：本步不出其他问题。只列调性卡片 + 推荐，用户选定后才开启反问。**

加载 `references/ui-aesthetics-excerpt.md` 的「调性」一节，按标准模板呈现 9 张卡片：
- 项目名 + 一句话业务描述
- 9 张卡片（编号 + 名称 + 关键词 + 3 个参考产品）
- **必给 1 首选 + 1 备选**，理由结合业务
- **显式排除**明显不合适的 1~3 个 + 理由
- 末尾：`请回复数字（如 "6"）或描述你想要的感觉`

**例外**：用户描述含强偏好（"参考 Notion"）→ 直接锁定对应调性，跳过卡片，**来源**填「用户强偏好」。

**选定后**：写入 CHANGE.md「视觉调性」，**来源**填「预选」，继承到 2a-ui-design。

### 1. 反问

用户完成 0.6 后（沿用 / 预选 / 强偏好），或非前端跳过 0.55–0.6 后，用结构化提问把"为什么/给谁/解决什么/何时算完"问清楚。每轮最多 2~3 个问题，等用户回答再继续。
- **不允许与调性卡片同屏呈现**

### 1.1 Grill-me 交互追问机制（当用户显式输入 /grill-me 或意图模糊时开启）

当触发 Grill-me 模式时，开启高对比度交互提问打磨提案：
1. **单消息提问限制**：每条消息只问 **1~2 个高对比度选型问题**，并附带可选项（A/B/C）与推荐选项。
2. **核心追问维度**：
   - **痛点与核心价值**："解决的最高频问题是什么？不做的代价是什么？"
   - **边界与非目标**："本次明确**不做**什么？（v1/v2 隔离）"
   - **极端/异常场景**："如果极端数据量或网络中断，预期退化表现是什么？"
3. **收敛门禁**：完成至少 2 轮有效追问且边界清晰后，汇总输出提案。

### 2. 影响面判定

- 是否需要新增/修改 REQUIREMENT.md？
- 是否触及架构（需要更新 DESIGN.md / 新增 ADR）？
- 是否影响现有 AC？

### 3. 范围排除

明确写出**这次不做什么**。至少 1 条。

### 4. 生成 CHANGE.md

使用 `references/CHANGE.md` 模板，填好后保存到 `.specs/<change-id>/CHANGE.md`。

### 5. 路径建议

- **完整**：REQUIREMENT → DESIGN → TASK → DEV → TEST → REVIEW → INTEGRATION → ARCHIVE → 8-release
- **中等**：(REQUIREMENT 增量) → TASK → DEV → TEST → REVIEW → INTEGRATION → ARCHIVE → 8-release
- **最短**：TASK → DEV → TEST → REVIEW → INTEGRATION（仅纯 bug 修复或微调；发布仍走 8-release）

## Constraints

- 不允许跳过反问直接出方案
- 不允许凭空假设未确认的需求点
- 不允许在 CHANGE.md 里写实现细节（那是 DESIGN 的事）
- 步骤 0.4 已跑：未命中就跳过；命中且用户选 2 → CHANGE.md 末尾有「架构层影响声明」
- 已有 UI 且非换风格：禁止展示 9 张调性卡片；只允许一句话沿用告知

## Validation

- [ ] CHANGE.md 包含：Why / What / 影响面 / 范围排除 / 验收线
- [ ] 至少明确写出 1 条「本次不做」
- [ ] 路径建议有理由，不是默认全跑
- [ ] 没有跳到实现层
- [ ] 步骤 0.4 已跑且处理正确
- [ ] 前端项目：0.55 已跑
- [ ] 已有 UI 且非换风格：未展示 9 张卡片；CHANGE「来源」为「沿用既有 UI」
- [ ] greenfield 或用户要换风格：走了 0.6 预选（或强偏好直接锁定）

## Resources

- `references/CHANGE.md` — 产出模板
- `references/ui-aesthetics-excerpt.md` — 调性卡片源（仅「给 AI 在 0-change 阶段展示用的标准模板」节）
