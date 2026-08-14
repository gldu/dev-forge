---
name: forge-sec
description: Use when performing security code audits, secret leakage detection, vulnerability scanning, or checking OWASP/PHI/LLM compliance.
---

# forge-sec — 安全合规与漏洞审计

## Goal

对代码库进行专项安全与合规审计，识别硬编码密钥、OWASP Top 10 漏洞、依赖库 CVE 风险以及 AI Prompt 注入风险。

## 触发条件

应触发：
- 发布 / 上线前强制安全审计（作为发布门禁）
- 依赖变更后（升级 / 新增 / 移除依赖，重点复查 CVE）
- 涉及敏感数据 / 支付 / PHI 的功能改动
- AI 应用上线前（Prompt 注入、系统提示泄漏、工具调用越权）
- 用户明确要求「安全审计」/「检查密钥泄露」

不应触发：
- 日常 code review 已覆盖的安全维度（单次 diff 的注入 / 越权检查）→ 走 forge-review，无需专门跑本 skill
- 纯文档 / 注释 / 非生产脚本改动，无真实攻击面

## Workflow

### 1. 敏感信息与密钥扫描 (Secret Leakage Scan)

1. 扫描代码与配置文件中的硬编码 Key、Token、私钥与数据库密码：
   - 正则检测：`API_KEY` / `SECRET` / `PRIVATE_KEY` / `password` / `Bearer` / `AKIA[0-9A-Z]{16}`
2. 确认敏感凭据是否被硬编码或误提交至 git。发现漏出立即警告并要求移入 `.env` / 环境变量。

### 2. OWASP Top 10 专项审计

对核心业务代码进行 5 大安全维度扫描：
1. **SQL 注入**：检查 ORM / SQL 拼接，强制使用参数化预编译查询。
2. **XSS 跨站脚本**：检查前端 DOM 渲染（如 `dangerouslySetInnerHTML` / `v-html`），确认已做 HTML 转义。
3. **越权访问 (IDOR / RBAC)**：检查 API 路由是否强制验证用户身份与资源所有权。
4. **CSRF / CORS**：检查敏感接口的跨域策略与 CSRF Token 校验。
5. **不安全解包 / 序列化**：检查 JSON/XML 动态反序列化风险。

### 3. 依赖库安全审计 (Dependency Audit)

按项目语言环境执行依赖漏洞扫描：
- Node.js: `npm audit` / `pnpm audit`
- Python: `pip audit` / `safety check`
- Go: `govulncheck ./...`

### 4. AI & Prompt 注入安全 (AI/LLM 应用专用)

如果是 AI 驱动的应用：
1. **Prompt 注入**：检查用户输入是否未经隔离直接作为系统指令拼接。
2. **系统提示泄漏**：检查敏感 Prompt 是否暴露至前端或日志中。
3. **工具调用越权**：检查 Agent Tool 是否带有毁灭性文件操作或无限制 Shell 执行权限。

## 扫描范围声明（输出报告前必做）

出报告前必须显式声明本次扫描边界，防止「未扫到」被误报为「全库安全」：
- 路径范围：本次覆盖的目录 / 文件清单（如 `src/`、`server/`；未含 `tests/`、`vendor/`、构建产物）
- 语言 / 框架：如 Node.js + Express / Python + FastAPI / Go + Gin
- 依赖清单：`package.json` / `requirements.txt` / `go.mod` 及扫描时的版本快照
- 扫描命令：实际执行的工具与命令（`npm audit`、`pip audit`、`govulncheck ./...`）
- 不覆盖项：显式列出未扫描范围（如「未扫 iOS 原生代码」「未审第三方闭源 SDK」「未做黑盒渗透」）

## 严重度分级输出

报告按以下分级标注（与 forge-review 一致），每条发现必须包含 5 要素：位置（`文件:行号`）、漏洞类型、利用路径、修复建议、严重度标签：
- 🔴 **Critical**：必须修复（数据泄露、RCE、高危越权、硬编码凭据进 git）
- 🟡 **Major**：建议修复（中危越权、依赖 High 漏洞、安全配置缺失）
- 🟢 **Minor**：可选改进（低危告警、安全风格建议）

## 依赖 CVE 修复路径

依赖扫描报 High / Critical 时按以下路径处置（R5.5：判断必须基于工具输出，禁止「看起来没问题」空话）：
1. **有修复版本** → 升级到已修复版本 → 重跑测试回归（R4.4：跑完 verify 并贴出输出）→ 通过后更新依赖清单与报告
2. **无修复版本** → 记录缓解措施（WAF 规则 / 禁用受影响入口 / 网络隔离 / 限制输入范围），报告标注「缓解中 · 待跟踪」并附复查日期
3. **严禁直接忽略**：无法修复也无法缓解 → 标 🔴 Critical 上报人工决策（R2.5：必须修复或显式「已知接受」并经人工确认）

## Constraints

- 发现 High / Critical 级别漏洞必须停止发布并先修补
- 严禁在代码或注释中保留测试用的真实 Token / 密码
- 出报告前必须先完成「扫描范围声明」

## 边界

- 本 skill 为专项深度审计（全量密钥扫描 + OWASP 专项 + 依赖 CVE + AI 安全），产出独立安全报告
- 日常 code review 中的安全维度（单次 diff 查注入 / 越权）→ 由 forge-review 顺带覆盖，不重复触发本 skill
- Scout 角色只产报告与修复建议，不直接修改业务代码（R3.3）；需改代码的修复生成 fix 任务交回 forge-dev

## Validation

- [ ] 无硬编码密钥或 Token
- [ ] 动态 SQL 均使用参数化绑定
- [ ] 前端非信任 HTML 均经过转义
- [ ] 依赖库漏洞扫描零 High/Critical 报告
- [ ] 扫描范围已声明（路径 / 语言框架 / 依赖清单 / 不覆盖项）
- [ ] 所有 High/Critical 均有处置（已修复 / 缓解中 / 人工确认接受）
- [ ] 每条发现含严重度标签与文件行号

## Resources

- `references/SECURITY-AUDIT.md` — 安全与合规审计报告模板
- OWASP Top 10 安全规范
