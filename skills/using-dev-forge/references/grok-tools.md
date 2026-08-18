# Grok Build TUI Tool Mapping

> **Note**: This file is for **Grok Build TUI** (`grok`) only. Other platforms have their own mapping files in this directory.

Skills speak in actions ("dispatch a subagent", "create a todo", "read a file"). On Grok Build TUI these resolve to the tools below.

| Action skills request | Grok Build TUI equivalent |
|----------------------|---------------------------|
| Read a file | `read_file` |
| Create a new file | `write` |
| Edit a file | `search_replace` |
| Run a shell command | `run_terminal_command` |
| Search file contents | `grep` |
| List files and subdirectories | `list_dir` |
| Fetch a URL | `web_fetch` / `open_page` |
| Search the web | `web_search` |
| Invoke a skill | Read that skill's `SKILL.md` (Grok auto-discovers skills; there is no separate Skill tool) |
| Dispatch a subagent (`Subagent (general-purpose):` template) | `spawn_subagent` with `subagent_type: "general-purpose"` |
| Collect a background subagent's result | `get_command_or_subagent_output` with the returned `subagent_id` |
| Multiple parallel dispatches | Multiple `spawn_subagent` calls in the same response |
| Task tracking ("create a todo", "mark complete") | `todo_write` |
| forge-* `read_files` / `read` | `read_file` |
| forge-* `write_files` / `write_to_file` | `write` |
| forge-* `edit` / `multi_edit` | `search_replace` |
| forge-* `bash` / shell commands | `run_terminal_command` |
| forge-* `grep` / searching file contents | `grep` |
| forge-* `glob` / finding files by name | `grep` / `list_dir` |
| forge-* `codegraph_explore` / code exploration | `codegraph_explore` (MCP via `search_tool` / `use_tool`) if available & indexed; fallback to `grep` / `list_dir` (see `code-navigation.md`) |
| `TodoWrite` references | `todo_write` |

## Instructions file

When a skill mentions "your instructions file", on Grok Build TUI this is **`AGENTS.md`** (also recognized: `Agents.md`, `AGENT.md`, `CLAUDE.md`, `Claude.md`). Grok loads matching files from the home rules directory, then from the repo root down to the current working directory. Project rules directories (`.grok/rules/*.md`) are loaded the same way.

## Personal skills directory

User-level skills live at **`~/.grok/skills/`**, with **`~/.agents/skills/`** as a cross-runtime alias (shared with Codex and Copilot CLI). Project-level skills live at **`.grok/skills/`** and **`.agents/skills/`**. Each skill is a subdirectory containing a `SKILL.md` (with `name` and `description` frontmatter).

## Subagent support

Grok Build TUI dispatches subagents through the **`spawn_subagent`** tool. Required / common parameters:

| Parameter | Use |
|-----------|-----|
| `prompt` | The full task prompt for the child. Fill every skill-template placeholder first. |
| `description` | A short 3–5 word label shown in the tasks pane. |
| `subagent_type` | `general-purpose` (default, full capability), `explore` (read-only research), or `plan` (read-only planning). |
| `background` | `false` to block until the child finishes (prefer this for sequential forge-* work). `true` returns a `subagent_id` immediately. |
| `capability_mode` | Optional tool filter: `read-only`, `read-write`, `execute`, or `all`. |
| `isolation` | `none` (shared workspace, default) or `worktree` (isolated git worktree). |

dev-forge skills dispatch work with subagents using the `Subagent (general-purpose):` template. On Grok Build TUI:

| Skill dispatch form | Grok Build TUI equivalent |
|---------------------|---------------------------|
| References a `*-prompt.md` template | Fill the template, then `spawn_subagent` with `subagent_type: "general-purpose"` and the filled prompt |
| Inline prompt (no template referenced) | `spawn_subagent` with `subagent_type: "general-purpose"` and your inline prompt |
| Read-only exploration | `spawn_subagent` with `subagent_type: "explore"` and the prompt |

### Hard rules (do not skip)

- **Never emit** `Subagent (general-purpose):` as prose or chat text. Always call the `spawn_subagent` tool.
- Saying you will dispatch a subagent but not calling `spawn_subagent` does **not** satisfy the skill.
- Do **not** fall back to inline work while `spawn_subagent` is available. The "no subagent tool" fallback in `using-dev-forge` does not apply on Grok Build TUI.
- If `background` is `true` (or the tool defaults to background), you **must** wait with `get_command_or_subagent_output` and incorporate the child's result before treating the dispatch as done.
- For sequential work (one forge-dev task, a review round that depends on the previous output), pass `background: false` so the parent blocks until the child finishes.

### Prompt filling

Skills provide prompt templates with placeholders like `{WHAT_WAS_IMPLEMENTED}` or `[FULL TEXT of task]`. Fill all placeholders before passing the complete prompt to `spawn_subagent`. The prompt template itself contains the agent's role, review criteria, and expected output format — the subagent will follow it.

### Parallel dispatch

Grok Build TUI supports parallel subagent dispatch. Issue multiple `spawn_subagent` calls in the same response to run independent subagent work in parallel. Keep dependent tasks sequential, but do not serialize independent subagent tasks just to preserve a simpler history.

### Subagent fallback

If `spawn_subagent` is genuinely unavailable in this session (the tool is not in your tool list), do the work inline rather than inventing tool calls. This is the only case where inline execution is allowed. A missing row in a mapping table is **not** "tool unavailable" — `spawn_subagent` is Grok Build TUI's native subagent tool.

### Depth limit

Only the top-level session may spawn subagents. A child cannot call `spawn_subagent`. If you were dispatched as a subagent, do the assigned work yourself.

## Additional Grok Build TUI tools

These tools are unique to (or distinctive on) Grok Build TUI:

| Tool | Purpose |
|------|---------|
| `get_command_or_subagent_output` | Wait for / read a background subagent or command by id |
| `kill_command_or_subagent` | Cancel a running background subagent or command |
| `ask_user_question` | Pose structured multiple-choice questions to the user |
| `enter_plan_mode` / `exit_plan_mode` | Switch into and out of read-only plan mode |
| `search_tool` / `use_tool` | Discover and call MCP tools (including CodeGraph when connected) |
| `workflow` | Launch a Rhai workflow that orchestrates multiple child agents |
