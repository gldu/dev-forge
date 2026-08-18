# dev-forge

[English](./README.md) | **简体中文**

dev-forge 是一套面向 Claude Code、Codex、Lingma、Grok Build TUI 等**编程智能体工作流框架**，通过标准化、可协作的阶段性工作流，将软件开发生命周期（SDLC）中的需求、设计、开发、测试、审查、集成等环节转化为结构化、可追溯、可复现的 AI 驱动流程。

## 定位

dev-forge 融合 **Harness Engineering、GStack、OMO、OpenSpec、Spec-Kit、Superpowers** 等工程方法学与智能体框架思想，不是单纯的代码生成器，而是一套**流程编排与质量控制体系**。它通过 21 个专业化 Skill 构成完整的工作流管道，确保每一次变更（Change）都经过需求澄清、技术设计、任务拆解、TDD 开发、五轮测试、三轮审查、集成验收、发布部署的完整闭环，最终沉淀为可维护的项目级知识资产。

## 核心特性

- **阶段化流水线**：从 Change 提案到归档，每个阶段有明确的输入输出和准入门槛（Artifact Preflight Gate）
- **质量内建**：TDD（RED→GREEN→REFACTOR）、五轮测试金字塔、6 维代码衰退风险诊断（R1认知过载 / R2变更传播 / R3知识重复 / R4偶然复杂 / R5依赖混乱 / R6领域扭曲）、UI 反 AI-slop 扫描
- **可追溯性**：每个变更都有唯一 change-id，所有产物（REQUIREMENT/DESIGN/TASK/SUMMARY/REVIEW）按变更隔离归档
- **知识沉淀**：LESSONS.md 记录跨任务失败教训，ARCHITECTURE.md / CONTEXT.md 积累项目级决策与抽象索引
- **Token 预算管理**：自动估算变更规模并让用户选择执行模式（完整 / 极简 / 单点）
- **Brownfield 友好**：既有项目自动检测已有 AI 上下文文档（AGENTS.md / CLAUDE.md / .cursor/rules 等），对齐既有架构

## 工作流全景

```
用户意图
    │
    ├── 直连触发（R0.1）→ 平台 description 匹配直接进入对应子 skill（如 "修这个报错" → forge-fix）
    │        （跳过 forge-router 路由，各 skill 自带 Preflight）
    │
    └── 路由触发 → forge-router（R0 路由入口）
              │
              ├── 新事物 → 0-change（变更提案）
              │                ↓
              │           1-requirement（需求分析）
              │                ↓
              │           2-design（技术设计）
              │                ↓
              │           2a-ui-design（UI 设计，前端项目）
              │                ↓
              │           3-task（任务拆解）
    │                ↓
    │           4-dev（单任务开发 / TDD）
    │                ↓
    │           5-test（五轮测试）
    │                ↓
    │           6-review（3+1 轮审查） ──(Critical/Fail)──┐
    │                ↓                                   │
    │           7-integration（集成验收 + 归档）           ↓
    │                ↓                                   │
    │           8-release（发布部署 · 版本推导/灰度/回滚预案）↓
    │                ▲────────────────────────── 4-dev (增量修复 T-NN)
    │
    ├── 横向命令与专项流程（不属于特定 change）
    │       ├── I-intel-scan    代码扫描 / 生成 CONTEXT.md
    │       ├── A-architect     项目级架构梳理
    │       ├── E-evolve        架构沉淀同步
    │       ├── M-health        代码库健康巡检
    │       ├── L-restyle       视觉风格切换
    │       ├── F-fix           缺陷诊断与重现修复 (RED → GREEN → LESSONS)
    │       ├── S-sec           安全合规与密钥漏洞审计 (OWASP / Secret)
    │       ├── P-perf          性能基准与压测优化 (p95 / QPS / Profiling)
    │       ├── R-rollback      线上故障止血回滚与 RCA 复盘 (Migration down)
    │       └── C-refactor      行为保持型代码重构 (测试保护网 / 契约无损)
    │
    └── 恢复 → 加载 STATE.md → 从中断处继续
```

## 项目结构

```
dev-forge/
└── skills/
    ├── forge-router/          # R0 路由入口 Orchestrator — 解析意图、路由阶段、估算预算
    ├── forge-change/          # 变更提案生成器 — 澄清想法、生成 CHANGE.md
    ├── forge-requirement/     # 需求分析师 — 用户故事、AC、范围切分
    ├── forge-design/          # 技术设计师 — 技术选型、架构图、ADR、风险分析
    ├── forge-ui-design/       # UI 美学导演 — Design Tokens、组件规约、反 AI-slop
    ├── forge-task/            # 任务拆解规划师 — 原子任务、波次依赖、并行标记
    ├── forge-dev/             # 单任务开发执行器 — TDD、既有抽象 grep、破坏性变更协议
    ├── forge-test/            # 五轮测试金字塔 — 功能/性能/安全/兼容/可观测
    ├── forge-review/          # 3+1 轮审查官 — Spec 合规 / 代码质量 / UI 视觉
    ├── forge-integration/     # 集成验证与归档 — UAT、失败诊断、LESSONS 提名、归档
    ├── forge-release/         # 发布部署 — 发布前检查、版本推导、灰度、回滚预案
    ├── forge-architect/       # 项目级架构梳理 — 模块图、ADR、跨模块契约
    ├── forge-evolve/          # 架构演进同步器 — 批量同步沉淀到 CONTEXT/ARCHITECTURE
    ├── forge-health/          # 代码库健康巡检 — 冗余/死代码/技术债扫描
    ├── forge-intel-scan/      # 代码扫描 — 生成/更新 CONTEXT.md
    ├── forge-restyle/         # 视觉风格切换 — 已有项目换调性
    ├── forge-fix/             # 缺陷诊断重现 — RED 重现测试、根因排查、LESSONS 沉淀
    ├── forge-sec/             # 安全合规审计 — 密钥泄露扫描、OWASP Top 10、Prompt 注入
    ├── forge-perf/            # 性能基准优化 — Benchmark 测量、瓶颈定位、递归优化
    ├── forge-rollback/        # 线上故障回滚 — 可逆 Migration、Hotfix、RCA 复盘
    └── forge-refactor/        # 行为保持重构 — 测试保护网、契约不变下的代码结构优化
```

每个 Skill 目录包含：

- `SKILL.md` — Skill 指令文件（触发条件、工作流、约束、验证清单）
- `references/` — 模板、规则节选、决策框架等参考材料

## 各 Skill 职责速查

| Skill | 阶段 | 角色 | 核心产出 |
|---|---|---|---|
| `forge-router` | 全局 | Orchestrator | 路由声明、阶段切换、预算估算 |
| `forge-change` | 0 | Partner | `.specs/<id>/CHANGE.md` |
| `forge-requirement` | 1 | Partner | `.specs/<id>/REQUIREMENT.md` |
| `forge-design` | 2 | Architect | `.specs/<id>/DESIGN.md`、ADR |
| `forge-ui-design` | 2a | Architect | `.specs/<id>/UI-DESIGN.md` |
| `forge-task` | 3 | Navigator | `.specs/<id>/TASK.md`（含 XML 任务） |
| `forge-dev` | 4 | Operator | `*-SUMMARY.md`、代码提交 |
| `forge-test` | 5 | Operator | `.specs/<id>/TEST.md` |
| `forge-review` | 6 | Scout | `.specs/<id>/REVIEW.md`、fix 任务 |
| `forge-integration` | 7 | Operator | `archive/<date>-<id>/`、CHANGELOG |
| `forge-release` | 8 | Operator | 版本 tag、发布记录、回滚预案 |
| `forge-architect` | A | Architect | `.specs/ARCHITECTURE.md` |
| `forge-evolve` | E | Philosopher | `.specs/evolve/<date>-EVOLVE.md` |
| `forge-health` | M | Scout | `.specs/health/<date>-HEALTH.md` |
| `forge-intel-scan` | I | Navigator | `.specs/CONTEXT.md` |
| `forge-restyle` | L | Partner | `UI-DESIGN.md` v2 |
| `forge-fix` | F | Operator | 重现测试、缺陷修补、`.specs/LESSONS.md` |
| `forge-sec` | S | Scout | 安全漏洞报告、密钥扫描结果 |
| `forge-perf` | P | Operator | Benchmark 性能对比报告 |
| `forge-rollback` | R | Operator | 数据库撤销、Hotfix、RCA 复盘报告 |
| `forge-refactor` | C | Architect | 代码重构提交、契约无损验证 |

## 产物规范

dev-forge 在项目中使用 `.specs/` 目录管理所有变更级和项目级产物：

```
<repo-root>/
├── .specs/
│   ├── CONTEXT.md                 # 项目级：术语表、已锁决策、既有抽象索引
│   ├── ARCHITECTURE.md            # 项目级：模块图、ADR、跨模块契约（可选）
│   ├── LESSONS.md                 # 项目级：跨任务失败教训知识库
│   ├── lessons/                   # 项目级：教训分册（code / architecture / security / test / performance / ux）
│   ├── CHANGELOG.md               # 项目级：变更历史
│   ├── adr/                       # 项目级技术决策记录 ADR
│   ├── <change-id>/
│   │   ├── CHANGE.md
│   │   ├── REQUIREMENT.md
│   │   ├── DESIGN.md
│   │   ├── UI-DESIGN.md           # 前端项目
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
└── STATE.md                       # 活跃 change、当前阶段、中断任务
```

## 安装

dev-forge 遵循 [Agent Skills](https://agentskills.io) 开放标准（Skill 目录 + `SKILL.md`，frontmatter 含 `name` / `description`），Claude Code、Codex CLI、通义灵码（Lingma）、Antigravity、OpenCode、Pi、Grok Build TUI 等平台均原生支持。将 `skills/` 下的各 Skill 目录放到平台的加载路径即可，无需注册：

| 平台 | 用户级（全局生效） | 项目级（随仓库分发） |
|---|---|---|
| Claude Code | `~/.claude/skills/` | `.claude/skills/` |
| Codex CLI | `~/.agents/skills/`（旧路径 `~/.codex/skills/`） | `.agents/skills/`（仓库根目录） |
| 通义灵码（Lingma） | `~/.lingma/skills/` | `.lingma/skills/` |
| Antigravity | `~/.gemini/config/skills/`（AGY / IDE / CLI 三端统一） | `.agents/skills/`（workspace 根，兼容旧 `.agent/skills/`） |
| OpenCode | `~/.config/opencode/skills/`（兼容 `~/.agents/skills/`、`~/.claude/skills/`） | `.opencode/skills/`（兼容 `.agents/skills/`、`.claude/skills/`） |
| Pi | `~/.pi/agent/skills/`（兼容 `~/.agents/skills/`） | `.pi/skills/`（兼容 `.agents/skills/`） |
| Grok Build TUI | `~/.grok/skills/`（兼容 `~/.agents/skills/`） | `.grok/skills/`（兼容 `.agents/skills/`） |

> 注：`.agents/skills/` 是 Codex、Antigravity、OpenCode、Pi、Grok Build TUI 共同识别的项目级路径，一套项目内分发即可覆盖多个平台；全局路径各平台不同，需按平台分别链接。

**方式一：符号链接（推荐，跟随仓库更新）**

```bash
SRC="$(pwd)/skills"

# 项目级通用路径（Codex / Antigravity / OpenCode / Pi 均识别）
mkdir -p .agents/skills && for d in "$SRC"/forge-*; do ln -sfn "$d" .agents/skills/"$(basename "$d")"; done

# 用户级（按所用平台选择其一）
# Claude Code
mkdir -p ~/.claude/skills && for d in "$SRC"/forge-*; do ln -sfn "$d" ~/.claude/skills/"$(basename "$d")"; done
# Codex CLI
mkdir -p ~/.agents/skills && for d in "$SRC"/forge-*; do ln -sfn "$d" ~/.agents/skills/"$(basename "$d")"; done
# 通义灵码
mkdir -p ~/.lingma/skills && for d in "$SRC"/forge-*; do ln -sfn "$d" ~/.lingma/skills/"$(basename "$d")"; done
# Antigravity
mkdir -p ~/.gemini/config/skills && for d in "$SRC"/forge-*; do ln -sfn "$d" ~/.gemini/config/skills/"$(basename "$d")"; done
# OpenCode
mkdir -p ~/.config/opencode/skills && for d in "$SRC"/forge-*; do ln -sfn "$d" ~/.config/opencode/skills/"$(basename "$d")"; done
# Pi
mkdir -p ~/.pi/agent/skills && for d in "$SRC"/forge-*; do ln -sfn "$d" ~/.pi/agent/skills/"$(basename "$d")"; done
# Grok Build TUI
mkdir -p ~/.grok/skills && for d in "$SRC"/forge-*; do ln -sfn "$d" ~/.grok/skills/"$(basename "$d")"; done
```

**方式二：项目内分发（团队共享）**：将 `skills/` 目录复制或链接到目标仓库的 `.agents/skills/`、`.claude/skills/`、`.lingma/skills/`、`.opencode/skills/`、`.pi/skills/` 或 `.grok/skills/`（按团队所用平台选择，`.agents/skills/` 覆盖面最广），随仓库提交即可让团队成员共享同一套工作流。

安装后重启对应 CLI（或重新打开 IDE），在对话中输入 `/` 查看已加载的 Skill 列表确认。触发依赖各 `SKILL.md` 的 `description` 语义匹配，描述写得越具体，自动触发越准。

## 使用方式

安装完成后，即可通过自然语言直接触发对应工作流。

**典型入口指令示例：**

- "我想做一个用户登录功能" → 触发 `forge-change`，启动完整流水线
- "/grill-me" / "拷问我" → 触发 Grill-me 交互式高对比度追问模式打磨提案
- "执行 T03" → 触发 `forge-dev`，执行 TASK.md 中的 T03 任务
- "修这个报错" / "修复 bug" → 触发 `forge-fix`，编写 RED 重现测试并定位根因修补
- "安全审计" / "检查密钥泄露" → 触发 `forge-sec`，扫描硬编码 Token、OWASP 漏洞与依赖 CVE
- "跑下压测" / "性能优化" → 触发 `forge-perf`，测量 Baseline 延迟/QPS 并开展压测优化
- "紧急回滚" / "线上故障复盘" → 触发 `forge-rollback`，执行安全回滚与 RCA 复盘
- "发布上线" / "发版" / "灰度发布" → 触发 `forge-release`，发布前检查、版本推导、灰度与回滚预案
- "纯重构这个模块" → 触发 `forge-refactor`，在测试保护下重构结构且保持契约无损
- "继续" / "恢复" → 加载 `STATE.md`，恢复中断的开发任务
- "审查代码" → 触发 `forge-review`，执行三轮审查
- "健康检查" → 触发 `forge-health`，扫描代码库技术债
- "同步架构" → 触发 `forge-evolve`，批量沉淀架构决策

## 设计原则

1. **人工在环（Human-in-the-loop）**：关键决策（技术选型、范围切分、ADR 确认）必须经用户确认，AI 不替用户做不可逆决定
2. **小步快跑**：每个开发任务控制在 2~10 分钟可完成的原子粒度，支持中断恢复
3. **失败即知识**：每次试错耗时 > 30 分钟或具有复用价值的失败，必须沉淀到 LESSONS.md
4. **只读不动**：审查、健康检查、架构梳理等 Scout/Architect 角色只产报告，不直接修改业务代码
5. **Token 效率**：通过 CONTEXT.md 的域语言和既有抽象索引，减少重复上下文消耗

## 约束红线

- `forge-dev`：verify 未通过禁止标记完成；破坏性变更必须走 grep 引用图 + 反问协议
- `forge-review`：禁止直接修改代码；所有 Critical 必须修复或经人工确认
- `forge-test`：测试用例从 AC 派生，不从实现派生；禁止通过删除/弱化测试来"修复"失败
- `forge-integration`：归档操作必须用户确认；UAT 失败自动重试不超过 3 轮
- `forge-router`：Preflight 失败必须回退；禁止要求用户提供 ID/路径/阶段名
