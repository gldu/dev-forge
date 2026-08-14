---
name: forge-go
description: Use when standard entrance or orchestrator for dev-forge is needed, such as starting a new feature, resuming past work, running code reviews, running tests, or managing change lifecycles.
---

# forge-go — dev-forge 路由入口（R0）

## Goal

作为 dev-forge 编程智能体蜂群的**路由入口（R0）**，解析用户一句话意图，自动完成：
1. 读取项目状态（STATE.md）
2. 执行 Artifact Preflight Gate（检查上游工件完整性）
3. 解析用户意图并路由到正确阶段/子 skill
4. 估算 Token 预算并让用户选挡位
5. 自动准备（生成 change-id、加载规则与工件）
6. 显式声明执行计划后进入对应子 skill

> **直连触发（R0.1）**：20 个子 skill 自带 description，可被平台直接触发（如"修这个报错"→ forge-fix、"审查代码"→ forge-review）。直连时**跳过 R0 路由**，各 skill 自行执行 Preflight。forge-go 负责三类场景：① 意图含混 / 新事物 / 恢复；② 跨阶段切换（0→8）；③ 需要预算估算或 Preflight 门禁兜底。两条路径的准入差异见 RULES R0.1。

## Workflow

### 第一步 · 读取项目状态

1. 尝试读仓库根 `STATE.md`。
   - 若 `STATE.md` 损坏/丢失或存在多个未归档 `.specs/<id>/` 目录：自动扫描所有未归档变更，列出结构化菜单（如：`1. companion-platform (停留: 4-dev)`，`2. dark-mode (停留: 2-design)`），提示用户输入序号选择（回复 1 或 2）或自动恢复最新修改时间目录，无需用户输入具体 ID/路径/阶段名。
   - 不存在且 `.specs/` 无未归档变更 → 视为新项目。
2. 关注字段：`活跃 Change` / `当前阶段` / `当前 Task` / `中断任务`
3. 存在 `中断任务` 非空 → **优先级最高**，直接走"恢复中断任务"分支

### 第二步 · Artifact Preflight Gate（强制）

路由到任何阶段前，检查上游工件是否齐全：

| 目标阶段 | 必须已有的上游工件 | 缺失时动作 |
|---|---|---|
| `0-change` | 无 | 直接进入 |
| `1-requirement` | `.specs/<id>/CHANGE.md` | 回 `0-change` |
| `2-design` | `CHANGE.md` + `REQUIREMENT.md` | 缺哪个回哪个 |
| `2a-ui-design` | `CHANGE.md` + `REQUIREMENT.md` + `DESIGN.md` | 回缺失阶段 |
| `3-task` | `REQUIREMENT.md` + `DESIGN.md`；前端还须有 `UI-DESIGN.md` | 回缺失阶段 |
| `4-dev` | 正式 `.specs/<id>/TASK.md` 中的当前 task，或用户显式临时最小 TASK | 反问：回 `3-task` 还是用户提供临时 TASK |
| `5-test` | `REQUIREMENT.md` + `DESIGN.md` + `TASK.md` + 各 `*-SUMMARY.md` | 回缺失阶段 |
| `6-review` | `REQUIREMENT.md` + `TASK.md` + `TEST.md` + 本次 diff | 回缺失阶段 |
| `7-integration` | `.specs/<id>/` 下本 change 全部应有产物 | 回缺失阶段 |
| `8-release` | 归档完成 + `REVIEW.md` + `TEST.md` + `UAT.md` 全绿 | 回 `7-integration` |

Preflight 失败时输出：
```
规则 R2.7 触发：目标阶段缺少 <工件>。本次先回到 <阶段> 补齐，不能直接继续。
```

### 第三步 · 解析用户意图，路由到阶段

**优先级判定**：
- 当前无活跃 change + 用户说"做/想/加/实现/设计 + X" → **优先路由到 `0-change`**（新事物）
- 当前有活跃 change + Artifact Preflight 通过 → 按以下表格匹配

**意图匹配表**（取最先命中）：

| 用户输入特征 | 路由到 | 备注 |
|---|---|---|
| `/grill-me` / `拷问我` / `深度追问` / `交互澄清` | `0-change`（启用 Grill-me 模式） | 进入高对比度交互追问模式打磨提案 |
| `修bug` / `fix` / `排查错误` / `bug` / `报错` | `forge-fix` | 缺陷诊断与重现修复 |
| `安全审计` / `security` / `sec` / `密钥扫描` / `漏洞` | `forge-sec` | 安全合规与漏洞扫描 |
| `性能优化` / `benchmark` / `perf` / `压测` / `瓶颈` | `forge-perf` | 性能基准与压测优化 |
| `回滚` / `rollback` / `线上故障` / `RCA` / `hotfix` | `forge-rollback` | 线上回滚与故障复盘 |
| `纯重构` / `refactor` / `优化结构` / `不改功能` | `forge-refactor` | 行为保持型代码重构 |
| `继续` / `接着上次` / `恢复` / `resume` | `4-dev` 入场恢复 | 加载 STATE.md 中断任务对应的 PROGRESS |
| `执行 T<NN>` / `跑 T<NN>` / `do T<NN>` | `4-dev` | task-id 从用户输入提取 |
| `审查` / `review` / `检查代码` / `code review` | `6-review` | |
| `测试` / `写测试` / `UAT` / `test` | `5-test` | |
| `上线` / `集成` / `验收` / `ship` / `归档` | `7-integration` | |
| `发布` / `发版` / `deploy` / `release` / `灰度发布` | `8-release` | 发布前检查 + 版本推导 + 灰度 + 回滚预案 |
| `拆任务` / `plan tasks` / `分解` | `3-task` | |
| `设计` + `<已有需求>` / `架构` / `design` | `2-design` | 仅当 CHANGE + REQUIREMENT 已存在 |
| `选技术` / `选栈` / `tech stack` | `2-design` 步骤 0 | 只需技术栈选型 |
| `UI` / `视觉` / `美学` / `theme` / `design tokens` | `2a-ui-design` | 前端项目 |
| `换调性` / `改风格` / `restyle` / `重做视觉` | `L-restyle` | 已有项目换视觉 |
| `健康检查` / `health` / `体检` / `扫冗余` / `技术债扫描` | `M-health` | 代码库周期性巡检 |
| `扫描代码` / `scan` / `intel` / `入场扫描` | `I-intel-scan` | 生成/更新 CONTEXT.md |
| `同步架构` / `沉淀架构` / `evolve` / `架构演进` | `E-evolve` | 扫归档 DESIGN §9 批量同步 |
| `建立架构` / `架构梳理` / `architect` / `画架构图` | `A-architect` | 首次/重构建立 ARCHITECTURE.md |
| `需求` / `spec` / `requirement` | `1-requirement` | |
| 任何**新事物描述**（"做/想/加/实现/设计 + X"，且无活跃 change） | `0-change` | **自动生成 change-id** |
| 模糊不清 | 反问用户 | 新需求 / 继续上次 / 别的？ |

> **架构级变更二次拦截**：路由到 0-change / 2-design 时，必须先按 0.4 / 0.5 做架构级预检。

### 第四步 · Token 预算估计

用户首轮路由后，AI 必须输出预算估算：

```
Token 预算估计：
   - 本次 change 规模：<small / medium / large>
   - 默认模式预估：~XXk - YYk tokens
   - 已选挡位：完整 / 极简 / 单点
挡位与质量门禁映射规则：
   - 1. 完整（跑全部 5 轮测试 + 3+1 轮审查，推荐 500+ 行 / 团队项目）
   - 2. 极简（**保留硬质量红线**：第 1 轮功能测试 + 第 3 轮依赖与安全扫描 + 第 1 轮 Spec 审查；可裁剪辅助性能压测与 UI 视觉对比；TDD 与安全红线不可豁免）
   - 3. 单点（仅跑指定阶段，显式提示缺乏前置/后置保障风险）
   - 4. 不走 dev-forge（< 50 行小微变动）

是否继续？或换挡位？
   1. 完整（推荐 500+ 行 / 团队项目 / 长期维护）
   2. 极简（推荐 100~500 行 · 非 UI 项目可跳 2a / 跳第四轮 / 跳跨模型，省 ~20%）
   3. 单点（你只想跑某一阶段，告诉我哪一个）
   4. 不走 dev-forge（< 50 行代码 / bugfix 直接修）
```

**成本影响因子**：
| 因子 | 影响 |
|---|---|
| 前端项目 | +20% |
| 涉及 schema 变更 | +5~10% |
| brooks-lint 已装 | +10% |
| 跨模型 spot-check | +30% |
| task 数 < 3 | -30% |
| task 数 > 10 | +50% |

**不必估预算的情况**：用户已显式指定模式 / 恢复中断任务 / 跑横向命令

### 第五步 · 老项目入场检测（brownfield 必跑）

**触发**：进入 0-change 之前必跑。

探测以下 AI 上下文文档（按优先级）：
- `CONTEXT.md`（仓库根 / `.specs/`）— dev-forge 自己
- `AGENTS.md`（仓库根）— OpenAI Codex
- `CLAUDE.md`（仓库根 / `.claude/`）— Anthropic
- `.cursor/rules/*.md` — Cursor
- `.windsurf/rules/*.md` — Windsurf
- `.github/copilot-instructions.md` — Copilot
- `.clinerules` — Cline

**判决**：
- **A** · 找到标准 AI 文档 → 反问用户：综合+扫描 / 以现有为准 / 忽略重扫 / 不生成 CONTEXT
- **B** · 找到 README/ARCHITECTURE/CONTRIBUTING → 反问用户：当作补充输入 / 仅代码扫描 / 指定遵守依据
- **C** · 无任何文档 → 反问用户：跑扫描 / 手动指定 / 跳过（不推荐）
- **D** · 刚创新项目（无 package.json 等）→ 跳过，CONTEXT 在后续阶段逐步沉淀
- **E** · STATE 已设 `ai_context_doc` → 直接读它，不再询问
- **F** · CONTEXT.md 存在且 last_intel_scan 在 90 天内 → 直接读，跳过本步
- **G** · CONTEXT.md 存在但 > 90 天 → 读 + 提醒用户可重扫

### 第六步 · 自动准备

进入对应阶段前完成：
- **新 CHANGE**：自动生成 `change-id`（kebab-case，2~4 词），检查冲突自动加序号
- **目录**：自行 `mkdir -p .specs/<id>/`
- **规则加载**：读 `references/SYSTEM.md`（精简规则）和 `references/RULES.md`（硬规则 R1~R8）
- **外部扩展检测**：检查 brooks-lint / ui-ux-pro-max / impeccable 是否在路由声明中标明

### 加载工件策略

**语义约定**：
- `⚡︎ 全读`：进阶段首轮必须 read_file 整个文件（SPEC / TEMPLATE）
- `⚡︎ 查表`：只 grep 指定节或 read offset/limit，**禁止默认整读**（reference/*）
- `⚡︎ 按需`：首轮不读，需要时才 grep / 读

| 阶段 | 全读（SPEC） | 查表（REFERENCE） | 按需 |
|---|---|---|---|
| 0 / 1 | — | `skills/forge-change/references/ui-aesthetics-excerpt.md` 只查调性模板卡片（仅前端）| — |
| 2 | `CHANGE.md` + `REQUIREMENT.md` + `CONTEXT.md` + `ARCHITECTURE.md`（如存在）| `skills/forge-design/references/tech-stacks-excerpt.md` 只查「适用矩阵」+ 5~6 张卡片 | ADR 阶段深谈时查 |
| 2a | `CHANGE.md` + `REQUIREMENT.md` + `DESIGN.md` `## 0` 段 + `CONTEXT.md` + `ui-anti-patterns.md`（84 行）| `skills/forge-ui-design/references/ui-aesthetics.md` 查「5 维度」| uipro / impeccable 查询 |
| 3 | `REQUIREMENT.md` + `DESIGN.md` + `UI-DESIGN.md`（前端）+ `CONTEXT.md` | — | 任务模板查询 |
| 4 | `TASK.md`（只读当前 task 块）+ `DESIGN.md` `## 0` 段 + `UI-DESIGN.md`（UI 任务）+ `CONTEXT.md` + `LESSONS.md` | `ui-anti-patterns.md`（UI 任务 · 84 行）| — |
| 5 | `REQUIREMENT.md` + `DESIGN.md` `## 0` 段 + `TASK.md` + 各 `*-SUMMARY.md` | `skills/forge-test/references/test-pyramid-excerpt.md` 只查适用矩阵 | — |
| 6 | `REQUIREMENT.md` + `DESIGN.md` + `TASK.md` + `TEST.md` + `git diff` | `ui-anti-patterns.md`（前端项目第三轮 · 84 行）| — |
| 7 | `.specs/<id>/` 全部产物 + `LESSONS.md` | — | — |
| 8 | `CHANGELOG.md` + 归档产物 | `skills/forge-release/references/RELEASE.md` 只查「发布检查清单」| 回滚预案查 `forge-rollback` |

### 第七步 · 显式声明执行计划（必须）

进入实际工作前，输出**路由声明**：

```
路由：<阶段，例如 0-change>
Change-ID：<id>（已自动生成 / 已恢复活跃 change：<existing-id>）
已加载：
   - <file1>（全读，N 行）
   - <file2>（全读，N 行）
   - <reference-file>（仅查「某节」，line X-Y）
未加载：<本阶段不需但后面可能用到的 reference，明说何时才拉>
第一动作：<具体下一步>
```

### 第八步 · 执行对应子 skill

加载并执行路由到的子 skill 的 instructions。所有规则（`RULES.md` / `SYSTEM.md`）继续生效。

**子 skill 清单与调用条件**：

| 子 skill | Paradigm | 调用条件 | 产出 Artifact |
|---|---|---|---|
| `forge-intel-scan` | Navigator | 新项目首次使用 / 用户说"扫描代码" | `.specs/CONTEXT.md` |
| `forge-architect` | Architect | 首次建立 / 重大重构 / 画架构图 | `.specs/ARCHITECTURE.md` |
| `forge-change` | Partner | 无活跃 change + 新事物 | `.specs/<id>/CHANGE.md` |
| `forge-requirement` | Partner | CHANGE.md 已确认 | `.specs/<id>/REQUIREMENT.md` |
| `forge-design` | Architect | REQUIREMENT.md 已确认 | `.specs/<id>/DESIGN.md` |
| `forge-ui-design` | Architect | DESIGN.md 已确认 + 前端项目 | `.specs/<id>/UI-DESIGN.md` |
| `forge-task` | Navigator | DESIGN.md（+ UI-DESIGN.md）已确认 | `.specs/<id>/TASK.md` |
| `forge-dev` | Operator | TASK.md 已确认 + 用户说"执行 T<NN>" | `*-SUMMARY.md` / `*-PROGRESS.md` |
| `forge-test` | Operator | 所有 DEV 任务完成 | `.specs/<id>/TEST.md` |
| `forge-review` | Scout | TEST.md 已确认 | `.specs/<id>/REVIEW.md` |
| `forge-integration` | Operator | REVIEW.md 已通过 | `archive/<date>-<id>/` + CHANGELOG |
| `forge-release` | Operator | 归档完成 + 用户说"发布/上线" | 版本 tag + 发布记录 |
| `forge-restyle` | Partner | 已有项目换视觉调性 | `.specs/<id>/UI-DESIGN.md` v2 |
| `forge-health` | Scout | 周期性巡检 / 里程碑前 / 接手项目 | `.specs/health/<date>-HEALTH.md` |
| `forge-evolve` | Philosopher | 每月/每季度批量同步沉淀 | (阶段 E) `.specs/evolve/<date>-EVOLVE.md` + patch |
| `forge-fix` | Operator | 缺陷诊断、排查与回归修复 | 重现测试 + `.specs/LESSONS.md` |
| `forge-sec` | Scout | 安全合规、密钥扫描与漏洞审计 | 安全扫描报告 |
| `forge-perf` | Operator | 性能基准测量、延迟/吞吐量压测 | Benchmark 对比报告 |
| `forge-rollback` | Operator | 线上故障应急止血、撤销 Migration | RCA 故障复盘报告 |
| `forge-refactor` | Architect | 保持既有行为与 API 契约不变的纯重构 | 代码提交 + 边界验证 |

**Artifact 传递协议**：
- 所有 change 级产物写入 `.specs/<change-id>/`
- ADR 产物写入 `.specs/adr/<NNN>-<title>.md`
- 项目级产物（CONTEXT / ARCHITECTURE / LESSONS / health / evolve）写入 `.specs/`
- 归档产物写入 `.specs/archive/<YYYY-MM-DD>-<change-id>/`
- 状态文件 `STATE.md` 在仓库根，由 forge-go 和各子 skill 共同维护
- `PROGRESS.md` / `LESSONS.md` 作为跨 change 共享状态，位于 `.specs/`

## Decision Tree

```
[用户输入]
    │
    ├── 空输入 → 反问用户：新想法 / 继续上次 / 审查代码
    │
    ├── 含"继续/恢复/resume" → 加载 STATE.md → 提取中断任务 → 4-dev 入场恢复
    │
    └── 【活跃 change 检测】
            │
            ├── 有活跃 change + Preflight 通过 → 【意图匹配】按表格路由
            │
            └── 无活跃 change 或 Preflight 失败
                    │
                    ├── "做/想/加/实现/设计 + X" → 0-change（生成新ID）
                    ├── "扫描代码/入场扫描" → I-intel-scan
                    ├── "健康检查/体检" → M-health
                    ├── "建立架构/画架构图" → A-architect
                    ├── "同步架构/沉淀" → E-evolve
                    └── 其他 → 反问用户
```

## Constraints

- **用户纠错实时沉淀 (Human Feedback Capture)**：当用户在对话中指出设计不合理、编码错误或架构偏好时，AI 必须确认并在 `.specs/LESSONS.md` 中追加一条 `L-NNN` 经验教训，确保后续任务永不再犯。
- **Token 预算红线**：进入任何阶段的首轮消息，加载的 reference/* 总行数 ≤ **150 行**
- **禁止默认整读 reference**：`tech-stacks-excerpt.md`(140行) / `ui-aesthetics.md`(75行) / `test-pyramid-excerpt.md`(119行) 必须先 grep 标题再 read offset
- **ui-anti-patterns.md 可整读**：各 skill 自带版本（65~84 行）
- **不得要求用户提供 ID/路径/阶段名**：这些 AI 自己决定
- **Preflight 失败必须回退**：禁止伪造"已满足"
- **新事物优先走 0-change**：即使有"设计/UI/测试"等关键词，无活跃 change 时仍先走 change

## Validation

产出路由声明前自检：
- [ ] 已读 STATE.md（如果存在）
- [ ] 已按表格匹配意图，没有跳过
- [ ] 新 CHANGE 已自动生成 ID 并展示
- [ ] **Token 预算**：本轮加载的 reference/* 总行数 ≤ 150
- [ ] **未越界**：没有读「查表」或「按需」列中的文件为全文
- [ ] 路由声明含「已加载 / 未加载 / 起止行」三要素
- [ ] 没有要求用户提供 ID / 路径 / 阶段名

## Resources

- `references/SYSTEM.md` — RULES + METHODOLOGY 精简版（永久注入用）
- `references/RULES.md` — R1~R8 完整硬规则
- `references/METHODOLOGY.md` — 方法论骨架（阶段定义、文件体系、7机制）
- `references/STATE.md` — STATE.md 状态文件模板（字段契约）
