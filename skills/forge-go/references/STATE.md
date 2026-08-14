# STATE.md 模板（字段契约）

> STATE.md 是 dev-forge 的中断恢复文件，位于项目根目录。以下 9 个字段为**完整契约**：forge-go 路由、中断续跑（"继续"/"恢复"）都依赖它们。字段缺失 = Preflight 失败，禁止伪造"已满足"。

## 字段契约

| 字段 | 必填 | 说明 |
|---|---|---|
| `active_change` | ✅ | 当前活跃 change-id（如 `20260814-login`）；无活跃 change 则为 `-` |
| `current_stage` | ✅ | 当前阶段（0 / 1 / 2 / 2a / 3 / 4 / 5 / 6 / 7）；无活跃 change 则为 `-` |
| `current_task` | ✅ | 当前任务编号（如 `T03`）；非 dev 阶段则为 `-` |
| `interrupted_at` | ✅ | 最近中断位置（阶段 + 任务 + 动作），恢复入口 |
| `last_intel_scan` | ✅ | 最近一次 intel-scan 日期（YYYY-MM-DD） |
| `last_architect_at` | ✅ | 最近一次 architect 梳理日期 |
| `last_evolve_at` | ✅ | 最近一次 evolve 同步日期 |
| `last_evolve_promoted` | ✅ | 最近一次被 promote 的沉淀条目（LESSONS / ARCHITECTURE） |
| `ai_context_doc` | ✅ | 检测到的既有 AI 上下文文档（AGENTS.md / CLAUDE.md / .cursor/rules 等）；无则为 `-` |

## 模板

```markdown
# STATE.md

- active_change: -
- current_stage: -
- current_task: -
- interrupted_at: -
- last_intel_scan: -
- last_architect_at: -
- last_evolve_at: -
- last_evolve_promoted: -
- ai_context_doc: -
```
