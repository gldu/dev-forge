# Code Navigation & Exploration Protocol

> **适用范围**：dev-forge 全生命周期 Skills（从 `forge-intel-scan` 入场扫描到 `forge-review` 审查、`forge-refactor` 重构等）。
> **核心原则**：**渐进增强（Progressive Enhancement）+ 优雅降级（Graceful Degradation）**。

---

## 1. 架构与工具定位

在代码库理解、依赖分析和符号跳转场景中，dev-forge 采用**两级双轨代码探索体系**：

```
                    ┌─────────────────────────┐
                    │     代码探索请求         │
                    └────────────┬────────────┘
                                 │
                   [检查 CodeGraph 是否可用]
                   (已安装 MCP 且存在 .codegraph 索引)
                                 │
                 ┌───────────────┴───────────────┐
                 ▼                               ▼
       【Level 1 · 首选】               【Level 2 · 回退】
        CodeGraph MCP                    文本 / 正则工具
    (`codegraph_explore`)            (`grep` / `glob` / `find`)
  跨文件符号源码 + 调用链路追踪           正则匹配 / 目录列表 / 抽样抽检
   动态派发跳转 + 爆炸半径评估            零依赖 / 任何环境保底运行
```

### 1.1 首选：CodeGraph MCP (`codegraph_explore`)
- **单一高能入口**：CodeGraph MCP 统一暴露 `codegraph_explore` 工具。
- **单次调用获取完整上下文**：
  1. 相关符号按文件聚合的带行号源码（Verbatim Source）。
  2. 符号间的调用链路（Call Paths）与动态派发跳转（Dynamic Dispatch：回调函数、React 重新渲染、接口→具体实现）。
  3. 改动爆炸半径摘要（Blast-Radius Summary）与受影响模块清单。
- **参数规范**：
  - `query` (string, 必需)：自然语言意图描述、探索流向（"how does X reach Y"）、或指定符号/文件名。
  - `projectPath` (string, 可选)：多模块/Monorepo 场景下指定索引根目录路径。

### 1.2 回退：内置文本工具 (`grep` / `glob` / `find`)
- **触发条件**：
  1. 当前宿主环境未安装或未注册 CodeGraph MCP 工具。
  2. 目标项目根目录未建立 `.codegraph/` 索引（工具返回 guidance 提示无索引）。
- **降级行为**：
  - **静默切换**：无需向用户抛出异常或阻断流程，直接使用 Skill 章节中注明的 `【回退 · grep/glob】` 命令执行文本与正则检索。

---

## 2. 标准双轨书写规范

各阶段 Skill 在涉及代码检索、依赖分析或模块探测时，统一遵循以下结构书写：

```markdown
**代码探索（双轨机制）**：
- 【优先 · CodeGraph】: `codegraph_explore(query="<意图/符号/流向>")`
- 【回退 · grep/glob】: `<grep/find/glob 具体命令>`
```

---

## 3. 典型阶段 Query 模板矩阵

| SDLC 阶段 | 探索意图 | CodeGraph 推荐 Query 模板 | grep / 基础工具回退建议 |
|---|---|---|---|
| **0-change** (`forge-change`) | 评估改动爆炸半径与受影响模块 | `codegraph_explore(query="blast radius and affected modules for changing <module_or_feature>")` | 根据拟改动文件 import 关系人工核对 |
| **0-intel-scan** (`forge-intel-scan`) | 扫描项目架构拓扑与既有抽象 | `codegraph_explore(query="survey project structure, entrypoints, and existing abstractions (HTTP client, DB access, state management, errors)")` | `find src -type d -maxdepth 3` + 关键字正则 `grep -rn "axios\|fetch\|Repository"` |
| **0-architect** (`forge-architect`) | 模块发现、边界划分与依赖流向 | `codegraph_explore(query="map architecture modules, boundaries, and dependency directions")` | `find src/` + `grep -rn "^import" src/` |
| **2-design** (`forge-design`) | 变更触碰模块与既有抽象对齐 | `codegraph_explore(query="identify modules, symbols, and blast radius affected by <change>")` | 基于需求关键词 grep 涉及文件 |
| **4-dev** (`forge-dev`) | 定位既有实现细节与已有调用方 | `codegraph_explore(query="how is <existing_symbol_or_hook> implemented and where is it called?")` | `grep -rn "<symbol_name>" src/` |
| **B-fix** (`forge-fix`) | 追溯崩溃入口与反向调用链路 | `codegraph_explore(query="trace call paths from entrypoints to <error_symbol_or_function>")` | 从错误堆栈向上传播逐层 grep 方法名 |
| **6-review** (`forge-review`) | 检查循环依赖与跨边界 import | `codegraph_explore(query="check circular dependencies, reverse dependencies, and cross-boundary imports in <modified_modules>")` | 抽样 `grep -rn "^import"` 配合人工逻辑核对 |
| **C-refactor** (`forge-refactor`) | 重构影响面分析与全局 Caller 查找 | `codegraph_explore(query="find all callers, callees, and blast radius for refactoring <target_symbol>")` | `grep -rn "\b<target_symbol>\b" src/` 全局匹配 |
| **H-health** (`forge-health`) | 发现死代码与 0 引用导出 | `codegraph_explore(query="find dead code and exports with zero external callers")` | `grep "^export "` 提取后逐个反向统计引用计数 |
