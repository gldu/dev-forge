---
name: forge-rollback
description: Use when safely rolling back failed deployments, reverting database schema migrations, executing emergency hotfixes, or producing RCA incident reports.
---

# forge-rollback — 线上故障回滚与 RCA 复盘

## Goal

在发布失败或发生线上故障时，安全撤销异常变更、执行数据库 Migration 回滚、快速上线 Hotfix 并产出 Root Cause Analysis (RCA) 故障复盘报告。

## Workflow

### 1. 紧急安全回滚 (Emergency Rollback)

1. 确认线上异常范围与影响面。
2. 回滚 Commit 或发布版本至上一个已知稳定版本。
3. **数据库 Migration 回滚**：若变更涉及 DB Schema，执行对应迁移文件的 `down` 脚本，恢复数据一致性。

### 2. 紧急修补路径 (Hotfix Fast-track)

若无法直接回滚，走最小化修补：
1. 从稳定 tag 切出 hotfix 分支。
2. 走 `forge-fix` 编写重现测试并应用最小补丁。
3. 跑通快速测试集后直接部署。

### 3. RCA 故障复盘报告 (Root Cause Analysis)

故障平息后，生成 RCA 复盘报告：
1. **故障时间线**：触发时间、发现时间、止血时间。
2. **根本原因 (Root Cause)**：触发故障的技术与流程诱因。
3. **改进措施 (Action Items)**：防止同类故障再次发生的措施。
4. **沉淀到 LESSONS**：将 RCA 核心教训写入 `.specs/LESSONS.md`。

## Constraints

- 回滚数据库变更前必须确认数据安全
- Hotfix 必须有自动化测试覆盖，严禁无测试直接改线上

## Validation

- [ ] 线上系统已恢复至正常状态
- [ ] 数据库 schema 与数据已对齐一致
- [ ] RCA 故障复盘报告已输出并同步至 `.specs/LESSONS.md`

## Resources

- `references/ROLLBACK-RCA.md` — 线上故障回滚与 RCA 复盘报告模板
