# dev-forge — Grok Build TUI

This repository ships the dev-forge workflow skills. On Grok Build TUI:

1. Follow `skills/using-dev-forge/SKILL.md`.
2. Use the tool mapping in `skills/using-dev-forge/references/grok-tools.md`.
3. Translate `Subagent (general-purpose):` into a real `spawn_subagent` call (`subagent_type: "general-purpose"`). Never write the template as prose. Do not fall back to inline work while `spawn_subagent` is available. If a child is backgrounded, wait with `get_command_or_subagent_output` before treating the dispatch as done.
