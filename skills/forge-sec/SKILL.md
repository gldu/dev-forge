---
name: forge-sec
description: Use when performing security code audits, secret leakage detection, vulnerability scanning, or checking OWASP/PHI/LLM compliance.
---

# forge-sec — 安全合规与漏洞审计

## Goal

对代码库进行专项安全与合规审计，识别硬编码密钥、OWASP Top 10 漏洞、依赖库 CVE 风险以及 AI Prompt 注入风险。

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

## Constraints

- 发现 High / Critical 级别漏洞必须停止发布并先修补
- 严禁在代码或注释中保留测试用的真实 Token / 密码

## Validation

- [ ] 无硬编码密钥或 Token
- [ ] 动态 SQL 均使用参数化绑定
- [ ] 前端非信任 HTML 均经过转义
- [ ] 依赖库漏洞扫描零 High/Critical 报告

## Resources

- `references/SECURITY-AUDIT.md` — 安全与合规审计报告模板
- OWASP Top 10 安全规范
