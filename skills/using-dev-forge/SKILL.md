---
name: using-dev-forge
description: Use when starting any conversation - establishes how to find and use forge-* skills, requiring skill invocation before ANY response including clarifying questions
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, ignore this skill.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a forge-* skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

## The Rule

**Invoke relevant or requested forge-* skills BEFORE any response or action** — including clarifying questions, exploring the codebase, or checking files. If it turns out wrong for the situation, you don't have to use it.

Then announce "Using [skill] to [purpose]" and follow the skill exactly. If it has a checklist, create a todo per item.

## dev-forge 工作流定位

dev-forge 是一个 SDLC 阶段化工作流框架。根据用户意图选择入口:

- 含混意图 / 新事物 / 恢复 / 跨阶段切换 → `forge-router` (路由入口, 解析意图 + Preflight 门禁 + 预算估算)
- 具体意图 → 直接触发对应 skill:
  - "修这个报错" → `forge-fix`
  - "审查代码" → `forge-review`
  - "拆任务" → `forge-task`
  - "实现这个任务" → `forge-dev`
  - "跑测试" → `forge-test`
  - "发布/上线" → `forge-release`
  - "安全审计" → `forge-sec`
  - "性能优化" → `forge-perf`
  - "回滚" → `forge-rollback`
  - "纯重构" → `forge-refactor`

## Skill Priority

When multiple skills apply, process skills come first — they set the approach, then implementation skills carry it out.

- "我要做一个登录功能" → forge-router 路由 → forge-change → forge-requirement → forge-design → forge-task → forge-dev → ...
- "Fix this bug" → forge-fix first.

## Subagent Dispatch (Platform-Neutral)

forge-* skills dispatch subagents using the **`Subagent (general-purpose):`** template. This is a platform-neutral syntax that gets translated to the appropriate tool by the loaded tool mapping.

**Example:**
```
Subagent (general-purpose): "Fix the auth module bug"
```

**How it works:**
1. Skill writes `Subagent (general-purpose):` with the task description
2. Agent reads the platform's tool mapping file (see below)
3. Agent translates to the platform-specific tool call

| Platform | `Subagent (general-purpose):` translates to |
|----------|---------------------------------------------|
| Antigravity | `invoke_subagent` with `TypeName: "self"` |
| Gemini CLI | `invoke_agent` with `agent_name: "generalist"` |
| Hermes Agent | `delegate_task(goal=..., context=...)` |
| Claude Code | `Task` tool (native) |
| Codex CLI | `shell` with subagent command (native) |
| Grok Build TUI | `spawn_subagent` with `subagent_type: "general-purpose"` |

**Tool mapping files** (in `references/`):
- `antigravity-tools.md` — Antigravity (`agy`)
- `gemini-tools.md` — Gemini CLI
- `hermes-tools.md` — Hermes Agent
- `grok-tools.md` — Grok Build TUI (`grok`)
- `code-navigation.md` — Code exploration & navigation protocol (CodeGraph MCP & fallback)

On Grok Build TUI, read `references/grok-tools.md` before the first subagent dispatch. Call `spawn_subagent` — never emit `Subagent (general-purpose):` as prose. If the child is backgrounded, wait with `get_command_or_subagent_output` before treating the dispatch as done.

**If no subagent tool is available:** Execute the task inline in the current session (no context isolation). A missing mapping-table row is not "no tool". Grok Build TUI's native tool is `spawn_subagent`; do not fall back to inline while that tool is in your tool list.

## Red Flags

These thoughts mean STOP—you're rationalizing:

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "I need more context first" | Skill check comes BEFORE clarifying questions. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
| "这个改动很小, 不用走流程" | 每个 Change 都要过 Artifact Preflight Gate。 |
| "我直接改就行了" | 先检查是否有对应 forge-* skill。 |
| "I remember this skill" | Skills evolve. Read current version. |
