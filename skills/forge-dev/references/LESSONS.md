# LESSONS — 跨 change 失败与纠错知识库

- **维护者**：forge-dev（读）+ forge-integration（提名新条目）
- **原则**：每个 DEV 任务开工前必扫；用户对话中纠错时实时沉淀
- **存储模式**：
  - **模式 A (单文件，条目 < 20)**：统一保存在 `.specs/LESSONS.md` 中。
  - **模式 B (分类分册，条目 >= 20)**：按领域分册存储在 `.specs/lessons/` 目录中：
    - `architecture.md` — 🏛️ 架构分层与设计避坑
    - `code.md` — 💻 语言语法与细节避坑
    - `test.md` — 🧪 测试覆盖与 Mock 避坑
    - `security.md` — 🛡️ 安全漏洞与密钥避坑
    - `performance.md` — ⚡ 性能压测与慢查询避坑
    - `ux.md` — 🎨 UI 美学与交互避坑
- **清理周期**：每 6 个月 review 一次，把 `deprecated` / `superseded` 条目归档到 `.specs/archive/LESSONS-history.md`

---

## 已收录条目

### L-001 · <简短失败描述>

- **标签**: <debug / build / test / deploy / performance / security / ux>
- **关键词**: <grep 用的关键词，3~5 个>
- **适用栈**: <技术栈或 "all">
- **触发场景**: <一句话>
- **失败表现**: <具体报错/现象>
- **根因**: <为什么错>
- **排除的方案（不要重试）**: <列 1~3 个已排除的方案>
- **最终解决**: <怎么解决的>
- **引用来源**: `.specs/<change-id>/<task-id>-SUMMARY.md`
- **状态**: active / deprecated / superseded by L-NNN

---

## 提名与捕获条件

一个失败或偏好要入库，必须满足 **>= 1** 条：

1. **用户显式纠错 (Human Feedback · 优先级最高)**：用户在对话中指出设计不合理、编码错误或明确提出项目偏好（如“这里设计不对/不能这么写/以后都用 X 替代 Y”）。
2. **调试/试错耗时 > 30 分钟**。
3. **错因不局限于本任务，其它任务也会撞**。
4. **6 个月内有合理概率被再次尝试**。

否则不入库（避免污染）。

---

## 新增条目模板

```
### L-NNN · <简短失败描述>

- **标签**: debug / build / test / deploy / performance / security / ux
- **关键词**: <3~5 个 grep 关键词>
- **适用栈**: <栈名或 all>
- **触发场景**: <一句话>
- **失败表现**: <具体现象>
- **根因**: <为什么>
- **排除的方案**: <1~3 个>
- **最终解决**: <怎么解决的>
- **引用来源**: `.specs/<change-id>/<task-id>-SUMMARY.md`
- **状态**: active
```
