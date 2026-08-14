---
name: forge-dev
description: Use when executing a single development task from TASK.md in a fresh context using TDD and impact analysis.
---

# forge-dev — 单任务开发

## Goal

在 fresh context 中执行 TASK.md 中的一个任务，保证代码质量、边界控制和可追溯性。

## Workflow

### 入口门禁（Artifact Preflight）

必须满足二选一：
1. 正式 `.specs/<id>/TASK.md` 中的当前 task
2. 用户显式提供的临时最小 TASK（含 id/name/read_files/write_files/action/verify/done）

AI 不允许自行编造临时 TASK。缺字段必须反问用户或回到 forge-task。

若 task 涉及前端/UI 文件，必须先确认 `UI-DESIGN.md` 存在。缺失时停止，回到 forge-ui-design。

### 1. 读取任务

从 TASK.md 取出对应 task 块，读懂 action/files/verify/done。有歧义停下来反问。

### 1.1 沿用既有抽象（强制 · R6.4）

返回 `process_symbols` 含文件位置 + 模块归属，直接定位既有实现。

**grep 回退**：针对 action 中每个能力执行 grep：
- HTTP 请求：`grep -rn "axios\|fetch\|httpClient\|apiClient" src/`
- 日期格式化：`grep -rn "format.*[Dd]ate\|date.*[Ff]ormat" src/utils src/lib`
- 状态管理：看 package.json
- Repository/DAO：`grep -rn "class.*Repository\|@Entity" src/`
- 错误处理：`grep -rn "ErrorBoundary\|errorHandler\|class.*Error" src/`
- 自定义 hooks：`find src -name 'use*.ts*'`

**必须**把搜索命令和结果贴入 SUMMARY「6 维自查」段。禁止"项目里好像没有"——必须有证据。

### 1.2 扫 LESSONS（强制 · R1.8）

进入实现前：
1. 用当前 task 的 files + action 关键词 grep `.specs/LESSONS.md`
2. 当出现特定领域问题时，可定向扫描 `.specs/lessons/` 下的分册（如 `code.md` / `architecture.md` / `security.md` / `test.md` / `performance.md` / `ux.md`）
3. 对每条命中且 active 的 L-NNN，在执行计划里显式声明差异或确认仍适用
4. 若计划方案与 active 条目完全相同 → 停下来回答差异，禁止盲目重试
5. 若 LESSONS.md 不存在 → 用模板创建空骨架

### 1.3 UI 任务额外检查（仅用户可见 UI）

判定：files 含 `.css/.tsx/.vue/.html/.svelte` 或 action 含 button/颜色/字体/卡片/布局/动画/主题。

命中时必须：
1. 加载 `UI-DESIGN.md`（必须存在）
2. 加载 `references/ui-anti-patterns.md`，按关键词 grep 相关章节
3. 加载 `references/frontend-engineer-rules-excerpt.md`**（第 1+2+10 节必读）**，其他节按需
4. 对每条命中禁忌，显式声明「不涉及」或「采用 Y 替代」
5. **Token 来源单一**：颜色/字体/间距/圆角/动效必须从 UI-DESIGN.md frontmatter 派生。禁止硬编码
6. React 三条硬规则写入计划（禁 `const styles` / 跨文件用 `Object.assign(window, ...)` / 禁 `scrollIntoView`）
7. 实现完成后再扫 anti-patterns + 第 10 节交付清单，写入 SUMMARY

### 1.4 数据库 Schema 任务额外检查（涉及表/字段变更必跑 · R4.5）

判定：action 含「新增表/加字段/改字段类型/加索引/加外键/重命名/删表/删列」或 files 涉及 ORM model / 迁移目录 / DDL SQL。

命中时必须：
1. **声明 schema diff**：在执行计划显式列出新增/修改/删除项
2. **选执行机制**（按优先级探测）：Prisma → Alembic → Active Record → Knex → Flyway → Liquibase → 手写 SQL → 裸项目回退
3. **生成可逆迁移**：每个迁移含 up 和 down
4. **检测 DB 凭据**：找到 → 反问用户是否执行；未找到 → 生成 SQL + SUMMARY 显式提醒
5. **反幻觉**：加字段前先 grep ORM model 确认；改类型确认兼容性；加 NOT NULL 确认有 DEFAULT/backfill

### 1.5 破坏性变更高门槛（强制 · R4.6）

判定：删除既有代码 >= 5 行 / 改公共导出签名 / 改公共 API / 删除文件或重命名导出符号。

命中时必须：
1. **grep 引用图**：对被删/改签名的符号执行 grep，贴出完整结果。
2. **回归测试覆盖**：确保旧路径有测试。
3. **写入 SUMMARY「破坏性变更」段**。

不必走本协议的情况：重构内部实现（导出不变）/ 加可选参数保持兼容 / 删 < 5 行实现细节（无外部引用）。

### 1.6 修改符号前强制影响检查（来自 AGENTS.md）

修改任何方法或符号前，使用 grep 检索其全局引用，并判断影响级别：
- LOW → 可继续
- MEDIUM → 在执行计划中声明影响
- HIGH/CRITICAL → **必须警告用户**，确认后才可继续

### 2. TDD 优先（默认开启）

RED → GREEN → REFACTOR：
1. 先写失败测试（派生自 AC 或 done 条件）
2. 跑测试确认真的失败
3. 写最少代码让它通过
4. 跑测试确认真的通过
5. 在测试保护下重构

纯文档/纯配置可跳过，但需在 SUMMARY 说明原因。

### 3. 跑 verify

按 verify 命令执行，贴出真实输出到 SUMMARY。verify 通过才能下一步。

### 4. 提交前 self-review（6 维 · brooks-lint 优先）

生产代码改动必跑。路径 A（装了 brooks-lint）：`/brooks-review`，Critical 必须修，Major 修或写已知接受理由，Minor 记入 SUMMARY。路径 B（未装）：AI 按 6 维快查：
- R1 认知过载：函数 > 50 行 / 嵌套 > 3 层 → 拆
- R2 变更传播：无关文件被改动 → 越界，回退
- R3 知识重复：同一段逻辑贴到 2+ 处 → 抽函数
- R4 偶然复杂：抽象层级 > 业务实际所需 → 删
- R5 依赖混乱：业务层 import 基础设施实现 → 倒置
- R6 领域扭曲：变量名是技术词而非领域词 → 重命名

### 5. 提交前 diff 边界 verify（强制 · R6.5）

2. **git 回退**：`git diff --name-only` 列出实际改动文件
3. 与 TASK.md write_files 比对
4. 有超出 → 停下来：撤销/扩范围/拆新 task
5. 结果写入 SUMMARY「越界检查」段

### 5.5 原子提交（R4.1）

格式：`<type>(<change-id>): <task-id> <subject>`
代码 + 测试同次或紧邻提交。

### 6. 写 SUMMARY

使用 `references/SUMMARY.md` 模板，填到 `.specs/<id>/<task-id>-SUMMARY.md`。

### 7. 标记完成

回到 TASK.md，把对应任务 done 标记为已完成。

## 中途断点（清窗触发与恢复 · R1.5/R1.6/R1.7）

### 入场恢复

若 STATE.md「中断任务」非空：
1. 加载顺序固定：METHODOLOGY → RULES → 本 skill → CONTEXT → REQUIREMENT → DESIGN → TASK → PROGRESS
2. 执行 R1.6 反重复检查
3. 从 PROGRESS「当前正在做」后续起

### 中途暂停（触发 R1.1 信号时）

1. 立即停手
2. 写 `.specs/<id>/<task-id>-PROGRESS.md`（已完成/当前/已排除方案+理由+失败次数/待确认假设）
3. 更新 STATE.md「中断任务」
4. 输出「重启指令」
5. 检查 R1.7：task 过大 → 在 TASK.md 就地拆为子任务

### 任务完成后

删除 PROGRESS.md，有用信息迁移到 SUMMARY.md。PROGRESS 是临时文件。

## Constraints

- verify 未通过禁止标记完成
- 发现需求/设计有问题 → 不要自己改 REQUIREMENT/DESIGN，停下来开新 CHANGE
- Schema 变更必伴随迁移文件。只改 model 不生迁移就提交 → 违规，AI 自己回滚
- 破坏性变更必走 1.5 协议（R4.6）
- 禁止用 mock 屏蔽真实失败
- 禁止"应该可以工作"——必须实际跑过 verify
- 发现需要扩大范围 → 停下来要求更新 TASK.md
- 每个任务一个 fresh context

## Validation

- [ ] verify 真的跑了，输出已贴出
- [ ] 测试与代码同次或紧邻提交
- [ ] 6 维 self-review 跑了，🔴 已修，🟡 已记
- [ ] 涉及 schema 变更已生成迁移文件且含 up+down
- [ ] 前端任务走了 1.3：读了 UI-DESIGN.md + frontend-rules；交付前过第 10 节清单
- [ ] SUMMARY.md 写完了
- [ ] TASK.md 对应任务已勾选
- [ ] 没有改动 REQUIREMENT.md / DESIGN.md
- [ ] 没有越界改其他任务的文件

## Resources

- `references/SUMMARY.md` — 任务完成报告模板
- `references/PROGRESS.md` — 中断恢复临时文件模板
- `references/LESSONS.md` — 跨任务失败知识库模板
- `references/ui-anti-patterns.md` — 反 AI-slop 清单
- `references/frontend-engineer-rules-excerpt.md` — 前端实现硬规则（第 1+2+10 节必跑）
