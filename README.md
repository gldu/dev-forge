# dev-forge

**English** | [简体中文](./README.zh-CN.md)

dev-forge is an **agentic workflow framework for programming agents** (Claude Code, Codex, Lingma, Antigravity, OpenCode, Pi, and more). It turns the stages of the software development lifecycle (SDLC) — requirements, design, development, testing, review, integration, release — into structured, traceable, reproducible AI-driven processes through a standardized, collaborative, stage-based workflow.

## Positioning

dev-forge fuses engineering methodologies and agent-framework ideas from **Harness Engineering, GStack, OMO, OpenSpec, Spec-Kit, Superpowers**, among others. It is not a plain code generator, but a **workflow orchestration and quality-control system**. It builds a complete workflow pipeline from 21 specialized Skills, ensuring every Change passes the full closed loop of requirement clarification, technical design, task decomposition, TDD development, five-round testing, three-round review, integration acceptance, and release deployment — finally distilling into maintainable, project-level knowledge assets.

## Core Features

- **Stage-based pipeline**: from Change proposal to archival, every stage has explicit inputs, outputs, and admission gates (Artifact Preflight Gate)
- **Quality built-in**: TDD (RED→GREEN→REFACTOR), five-round test pyramid, 6-dimension code regression risk diagnosis (R1 Cognitive Overload / R2 Change Propagation / R3 Knowledge Duplication / R4 Accidental Complexity / R5 Dependency Entanglement / R6 Domain Distortion), UI anti-AI-slop scanning
- **Traceability**: every change has a unique change-id; all artifacts (REQUIREMENT/DESIGN/TASK/SUMMARY/REVIEW) are archived in per-change isolation
- **Knowledge accumulation**: LESSONS.md records cross-task failure lessons; ARCHITECTURE.md / CONTEXT.md accumulate project-level decisions and an abstraction index
- **Token budget management**: automatically estimates change size and lets the user choose an execution mode (full / minimal / single-point)
- **Brownfield friendly**: auto-detects existing AI context documents in existing projects (AGENTS.md / CLAUDE.md / .cursor/rules, etc.) and aligns with the existing architecture

## Workflow Overview

```
User intent
    │
    ├── Direct trigger (R0.1) → platform description matching enters the matching sub-skill directly (e.g. "fix this error" → forge-fix)
    │        (skips forge-router routing; each skill carries its own Preflight)
    │
    └── Routed trigger → forge-router (R0 routing entry)
              │
              ├── New thing → 0-change (change proposal)
              │                     ↓
              │                1-requirement (requirements analysis)
              │                     ↓
              │                2-design (technical design)
              │                     ↓
              │                2a-ui-design (UI design, frontend projects)
              │                     ↓
              │                3-task (task decomposition)
    │                     ↓
    │                4-dev (single-task development / TDD)
    │                     ↓
    │                5-test (five-round testing)
    │                     ↓
    │                6-review (3+1 round review) ──(Critical/Fail)──┐
    │                     ↓                                       │
    │                7-integration (acceptance + archival)         ↓
    │                     ↓                                       │
    │                8-release (release deploy · version/canary/rollback plan) ↓
    │                     ▲────────────────────────── 4-dev (incremental fix T-NN)
    │
    ├── Horizontal commands & specialized flows (not tied to a specific change)
    │       ├── I-intel-scan    code scan / generate CONTEXT.md
    │       ├── A-architect     project-level architecture review
    │       ├── E-evolve        architecture distillation sync
    │       ├── M-health        codebase health inspection
    │       ├── L-restyle       visual style switching
    │       ├── F-fix           defect diagnosis & reproducible fix (RED → GREEN → LESSONS)
    │       ├── S-sec           security compliance & secret audit (OWASP / Secret)
    │       ├── P-perf          performance benchmark & tuning (p95 / QPS / Profiling)
    │       ├── R-rollback      production containment rollback & RCA review (Migration down)
    │       └── C-refactor      behavior-preserving refactor (test safety net / contract lossless)
    │
    └── Resume → load STATE.md → continue from the interruption point
```

## Project Structure

```
dev-forge/
└── skills/
    ├── forge-router/              # R0 routing entry Orchestrator — parse intent, route stages, estimate budget
    ├── forge-change/          # change proposal generator — clarify ideas, produce CHANGE.md
    ├── forge-requirement/     # requirements analyst — user stories, AC, scope splitting
    ├── forge-design/          # technical designer — tech selection, architecture diagram, ADR, risk analysis
    ├── forge-ui-design/       # UI aesthetics director — Design Tokens, component specs, anti AI-slop
    ├── forge-task/            # task decomposition planner — atomic tasks, wave dependencies, parallel flags
    ├── forge-dev/             # single-task development executor — TDD, existing-abstraction grep, breaking-change protocol
    ├── forge-test/            # five-round test pyramid — functional/performance/security/compatibility/observability
    ├── forge-review/          # 3+1 round reviewer — Spec compliance / code quality / UI visual
    ├── forge-integration/     # integration validation & archival — UAT, failure diagnosis, LESSONS nomination, archival
    ├── forge-release/         # release deployment — pre-release checks, version derivation, canary, rollback plan
    ├── forge-architect/       # project-level architecture review — module diagram, ADR, cross-module contracts
    ├── forge-evolve/          # architecture evolution sync — batch-distill into CONTEXT/ARCHITECTURE
    ├── forge-health/          # codebase health inspection — redundancy/dead code/tech debt scanning
    ├── forge-intel-scan/      # code scan — generate/update CONTEXT.md
    ├── forge-restyle/         # visual style switching — restyle an existing project
    ├── forge-fix/             # defect diagnosis & reproduction — RED reproduction test, root cause, LESSONS
    ├── forge-sec/             # security compliance audit — secret scanning, OWASP Top 10, prompt injection
    ├── forge-perf/            # performance benchmark & optimization — Benchmark measurement, bottleneck, iterative tuning
    ├── forge-rollback/        # production incident rollback — reversible Migration, Hotfix, RCA review
    └── forge-refactor/        # behavior-preserving refactor — test safety net, contract-lossless structure optimization
```

Each Skill directory contains:

- `SKILL.md` — the Skill instruction file (triggers, workflow, constraints, verification checklist)
- `references/` — reference material: templates, rule excerpts, decision frameworks

## Skill Responsibilities at a Glance

| Skill | Stage | Role | Core Output |
|---|---|---|---|
| `forge-router` | Global | Orchestrator | routing declaration, stage switching, budget estimation |
| `forge-change` | 0 | Partner | `.specs/<id>/CHANGE.md` |
| `forge-requirement` | 1 | Partner | `.specs/<id>/REQUIREMENT.md` |
| `forge-design` | 2 | Architect | `.specs/<id>/DESIGN.md`, ADR |
| `forge-ui-design` | 2a | Architect | `.specs/<id>/UI-DESIGN.md` |
| `forge-task` | 3 | Navigator | `.specs/<id>/TASK.md` (incl. XML tasks) |
| `forge-dev` | 4 | Operator | `*-SUMMARY.md`, code commits |
| `forge-test` | 5 | Operator | `.specs/<id>/TEST.md` |
| `forge-review` | 6 | Scout | `.specs/<id>/REVIEW.md`, fix tasks |
| `forge-integration` | 7 | Operator | `archive/<date>-<id>/`, CHANGELOG |
| `forge-release` | 8 | Operator | version tag, release record, rollback plan |
| `forge-architect` | A | Architect | `.specs/ARCHITECTURE.md` |
| `forge-evolve` | E | Philosopher | `.specs/evolve/<date>-EVOLVE.md` |
| `forge-health` | M | Scout | `.specs/health/<date>-HEALTH.md` |
| `forge-intel-scan` | I | Navigator | `.specs/CONTEXT.md` |
| `forge-restyle` | L | Partner | `UI-DESIGN.md` v2 |
| `forge-fix` | F | Operator | reproduction test, defect patch, `.specs/LESSONS.md` |
| `forge-sec` | S | Scout | security vulnerability report, secret scan results |
| `forge-perf` | P | Operator | Benchmark performance comparison report |
| `forge-rollback` | R | Operator | database undo, Hotfix, RCA review report |
| `forge-refactor` | C | Architect | refactoring commits, contract-lossless verification |

## Artifact Conventions

dev-forge uses the `.specs/` directory to manage all change-level and project-level artifacts:

```
<repo-root>/
├── .specs/
│   ├── CONTEXT.md                 # project-level: glossary, locked decisions, existing-abstraction index
│   ├── ARCHITECTURE.md            # project-level: module diagram, ADR, cross-module contracts (optional)
│   ├── LESSONS.md                 # project-level: cross-task failure-lesson knowledge base
│   ├── lessons/                   # project-level: lesson volumes (code / architecture / security / test / performance / ux)
│   ├── CHANGELOG.md               # project-level: change history
│   ├── adr/                       # project-level ADR (architecture decision records)
│   ├── <change-id>/
│   │   ├── CHANGE.md
│   │   ├── REQUIREMENT.md
│   │   ├── DESIGN.md
│   │   ├── UI-DESIGN.md           # frontend projects
│   │   ├── TASK.md
│   │   ├── T01-SUMMARY.md
│   │   ├── T02-SUMMARY.md
│   │   ├── TEST.md
│   │   ├── REVIEW.md
│   │   └── UAT.md
│   ├── archive/
│   │   └── <YYYY-MM-DD>-<change-id>/
│   ├── health/
│   │   └── <YYYY-MM-DD>-HEALTH.md
│   ├── evolve/
│   │   └── <YYYY-MM-DD>-EVOLVE.md
│   └── release/
│       └── <YYYY-MM-DD>-RELEASE.md
└── STATE.md                       # active change, current stage, interrupted task
```

## Installation

dev-forge follows the [Agent Skills](https://agentskills.io) open standard (a Skill directory + `SKILL.md` with `name` / `description` in frontmatter) and is natively supported by Claude Code, Codex CLI, Lingma, Antigravity, OpenCode, Pi, and more. Just drop each Skill directory from `skills/` into your platform's skill load path — no registration needed:

| Platform | User-level (global) | Project-level (shipped with the repo) |
|---|---|---|
| Claude Code | `~/.claude/skills/` | `.claude/skills/` |
| Codex CLI | `~/.agents/skills/` (legacy `~/.codex/skills/`) | `.agents/skills/` (repo root) |
| Lingma | `~/.lingma/skills/` | `.lingma/skills/` |
| Antigravity | `~/.gemini/config/skills/` (unified across AGY / IDE / CLI) | `.agents/skills/` (workspace root, backward-compatible with `.agent/skills/`) |
| OpenCode | `~/.config/opencode/skills/` (also reads `~/.agents/skills/`, `~/.claude/skills/`) | `.opencode/skills/` (also reads `.agents/skills/`, `.claude/skills/`) |
| Pi | `~/.pi/agent/skills/` (also reads `~/.agents/skills/`) | `.pi/skills/` (also reads `.agents/skills/`) |

> Note: `.agents/skills/` is the shared project-level path recognized by Codex, Antigravity, OpenCode, and Pi — one in-repo distribution covers multiple platforms. Global paths differ per platform and must be linked separately.

**Option 1: Symlink (recommended — stays in sync with the repo)**

```bash
SRC="$(pwd)/skills"

# Project-level shared path (recognized by Codex / Antigravity / OpenCode / Pi)
mkdir -p .agents/skills && for d in "$SRC"/forge-*; do ln -sfn "$d" .agents/skills/"$(basename "$d")"; done

# User-level (pick the one for your platform)
# Claude Code
mkdir -p ~/.claude/skills && for d in "$SRC"/forge-*; do ln -sfn "$d" ~/.claude/skills/"$(basename "$d")"; done
# Codex CLI
mkdir -p ~/.agents/skills && for d in "$SRC"/forge-*; do ln -sfn "$d" ~/.agents/skills/"$(basename "$d")"; done
# Lingma
mkdir -p ~/.lingma/skills && for d in "$SRC"/forge-*; do ln -sfn "$d" ~/.lingma/skills/"$(basename "$d")"; done
# Antigravity
mkdir -p ~/.gemini/config/skills && for d in "$SRC"/forge-*; do ln -sfn "$d" ~/.gemini/config/skills/"$(basename "$d")"; done
# OpenCode
mkdir -p ~/.config/opencode/skills && for d in "$SRC"/forge-*; do ln -sfn "$d" ~/.config/opencode/skills/"$(basename "$d")"; done
# Pi
mkdir -p ~/.pi/agent/skills && for d in "$SRC"/forge-*; do ln -sfn "$d" ~/.pi/agent/skills/"$(basename "$d")"; done
```

**Option 2: In-repo distribution (team sharing)**: copy or link the `skills/` directory into `.agents/skills/`, `.claude/skills/`, `.lingma/skills/`, `.opencode/skills/`, or `.pi/skills/` of the target repo (pick per your team's platform; `.agents/skills/` has the widest coverage). Commit it to the repo so every team member shares the same workflow.

After installing, restart the corresponding CLI (or reopen the IDE) and type `/` in a conversation to confirm the loaded Skills. Triggering relies on semantic matching against each `SKILL.md` `description` — the more specific the description, the more reliable the auto-trigger.

## Usage

Once installed, you can trigger the corresponding workflow directly via natural language.

**Typical entry prompts:**

- "I want to build a user login feature" → triggers `forge-change`, starts the full pipeline
- "/grill-me" / "interrogate me" → triggers Grill-me interactive high-contrast questioning mode to refine a proposal
- "Execute T03" → triggers `forge-dev`, executes task T03 in TASK.md
- "Fix this error" / "fix bug" → triggers `forge-fix`, writes a RED reproduction test and fixes the root cause
- "Security audit" / "check for secret leaks" → triggers `forge-sec`, scans hardcoded tokens, OWASP vulnerabilities, and dependency CVEs
- "Run load tests" / "performance optimization" → triggers `forge-perf`, measures baseline latency/QPS and runs load-test optimization
- "Emergency rollback" / "incident postmortem" → triggers `forge-rollback`, performs safe rollback and RCA review
- "Release" / "ship it" / "canary release" → triggers `forge-release`, pre-release checks, version derivation, canary, and rollback plan
- "Pure refactor of this module" → triggers `forge-refactor`, restructures under test protection with contract losslessness
- "Continue" / "resume" → loads `STATE.md`, resumes the interrupted development task
- "Review the code" → triggers `forge-review`, runs the three-round review
- "Health check" → triggers `forge-health`, scans codebase tech debt
- "Sync architecture" → triggers `forge-evolve`, batch-distills architecture decisions

## Design Principles

1. **Human-in-the-loop**: key decisions (tech selection, scope splitting, ADR confirmation) must be confirmed by the user; the AI never makes irreversible decisions on the user's behalf
2. **Small steps, fast iteration**: each development task is kept at an atomic granularity completable in 2–10 minutes, with interruption/resume support
3. **Failure becomes knowledge**: any failed attempt taking > 30 minutes, or any failure with reuse value, must be distilled into LESSONS.md
4. **Read-only by default**: Scout/Architect roles (review, health check, architecture review) only produce reports and never modify business code directly
5. **Token efficiency**: CONTEXT.md's domain language and existing-abstraction index reduce repeated context consumption

## Hard Constraints

- `forge-dev`: must not mark a task complete if verify fails; breaking changes must go through the grep reference-graph + cross-questioning protocol
- `forge-review`: never modify code directly; every Critical must be fixed or human-confirmed
- `forge-test`: test cases derive from AC, not from implementation; never "fix" failures by deleting or weakening tests
- `forge-integration`: archival requires user confirmation; UAT failure auto-retry is capped at 3 rounds
- `forge-router`: Preflight failure must fall back; never ask the user to provide IDs/paths/stage names
