# Antigravity CLI (`agy`) Tool Mapping

Skills speak in actions ("dispatch a subagent", "create a todo", "read a file"). On the Antigravity CLI (`agy`) these resolve to the tools below.

| Action skills request | Antigravity CLI equivalent |
|----------------------|----------------------|
| Dispatch a subagent (`Subagent (general-purpose):` template) | `invoke_subagent` with a built-in `TypeName` — `self` for full-capability work, `research` for read-only |
| Task tracking ("create a todo", "mark complete") | a **task artifact** — `write_to_file` with `IsArtifact: true` and `ArtifactType: "task"` (see [Task tracking](#task-tracking)). **Not** `manage_task`, which manages background processes. |
| Deep code exploration / flow tracing / blast radius (`codegraph_explore`) | `codegraph_explore` (MCP tool) if available & indexed; fallback to `grep_search` / `list_dir` / `view_file` (see `code-navigation.md`) |

## Instructions file

When a skill mentions "your instructions file", on Antigravity this is **`GEMINI.md`**. Antigravity loads `GEMINI.md` hierarchically: global at `~/.gemini/GEMINI.md`, project-level files in workspace directories and their ancestors, and sub-directory `GEMINI.md` files when a tool accesses files in those directories.

## Personal skills directory

User-level skills live at **`~/.gemini/config/skills/`** (unified across AGY / IDE / CLI), with **`~/.agents/skills/`** as a cross-runtime alias (shared with Codex and Copilot CLI). When both directories exist at the same scope, `.agents/skills/` takes precedence. Each skill is a subdirectory containing a `SKILL.md` (with `name` and `description` frontmatter).

## Subagent support

Antigravity dispatches subagents through the `invoke_subagent` tool, which takes `TypeName` and `prompt` parameters. Built-in `TypeName` values include:

| TypeName | Use case |
|----------|----------|
| `self` | Full-capability work (implementation, debugging, complex tasks) |
| `research` | Read-only work (exploration, documentation lookup, analysis) |

dev-forge skills dispatch work with subagents using the `Subagent (general-purpose):` template. On Antigravity:

| Skill dispatch form | Antigravity equivalent |
|---------------------|----------------------|
| References a `*-prompt.md` template | Fill the template, then `invoke_subagent` with `TypeName: "self"` and the filled prompt |
| Inline prompt (no template referenced) | `invoke_subagent` with `TypeName: "self"` and your inline prompt |
| Read-only exploration | `invoke_subagent` with `TypeName: "research"` and the prompt |

### Prompt filling

Skills provide prompt templates with placeholders like `{WHAT_WAS_IMPLEMENTED}` or `[FULL TEXT of task]`. Fill all placeholders before passing the complete prompt to `invoke_subagent`. The prompt template itself contains the agent's role, review criteria, and expected output format — the subagent will follow it.

### Parallel dispatch

Antigravity supports parallel subagent dispatch. Issue multiple `invoke_subagent` calls in the same response to run independent subagent work in parallel. Keep dependent tasks sequential, but do not serialize independent subagent tasks just to preserve a simpler history.

### Subagent fallback

If `invoke_subagent` is unavailable in your Antigravity environment, do the work inline (sequentially in the current context) rather than inventing tool calls. Each task will run in the current session context instead of a fresh subagent context.

## Task tracking

Antigravity has **no todo tool** (`manage_task` manages background processes — `list`/`kill`/`status`/`send_input` — it is *not* a checklist). When a skill says to create a todo list or track tasks, maintain a **task artifact**: a markdown checklist saved with `write_to_file` (`IsArtifact: true`, `ArtifactMetadata.ArtifactType: "task"`), edited with `replace_file_content` / `multi_replace_file_content` as you go.

At the start of any multi-step task, create the task artifact listing every step of your plan. As you complete each step, edit the artifact to mark it done (`- [x]`). If the plan changes, update the checklist. Keep it current — it is your source of truth for what remains; once the conversation gets long, re-read it before starting each step.

## Additional Antigravity tools

These tools are unique to Antigravity:

| Tool | Purpose |
|------|---------|
| `save_memory` (legacy) | Persist facts across sessions when `experimental.memoryV2 = false` |
| `get_internal_docs` | Look up Antigravity's bundled documentation |
| `ask_user` | Pose structured questions to the user (text / single-select / multi-select) |
| `enter_plan_mode` / `exit_plan_mode` | Switch into and out of read-only plan mode |
| `update_topic` | Update the current conversation's topic / strategic-intent metadata |
| `complete_task` | Signal that an Antigravity subagent has completed and return its result to the parent agent |
| `tracker_create_task`, `tracker_update_task`, `tracker_get_task`, `tracker_list_tasks`, `tracker_add_dependency`, `tracker_visualize` | Rich task tracker with dependency and visualization support |
| `read_mcp_resource`, `list_mcp_resources` | MCP resource access |
