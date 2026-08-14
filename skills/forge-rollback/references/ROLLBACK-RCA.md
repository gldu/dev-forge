# 线上故障回滚与 RCA 复盘报告 (Rollback & RCA Report)

- **故障级别**: P0 / P1 / P2
- **故障描述**: <一句话总结>
- **止血措施**: 成功回滚至 Commit `<hash>` / 版本 `<tag>`

---

## 1. 故障时间线 (Timeline)

- **HH:MM**: 变更发布上线
- **HH:MM**: 监控报警 / 用户反馈异常
- **HH:MM**: 确认故障，启动紧急回滚
- **HH:MM**: 回滚完成，业务恢复正常

---

## 2. 数据库 Migration 回滚验证

- **涉及迁移脚本**: `migrations/<timestamp>_xxx.sql`
- **`down` 脚本执行命令**: `<down-command>`
- **数据一致性校验结果**: ✅ 成功恢复至预置状态，数据无丢失

---

## 3. 根本原因分析 (Root Cause Analysis - RCA)

- **直接原因**: <代码/配置/环境的具体诱因>
- **系统性漏洞**: <流程/测试屏蔽的隐患>

---

## 4. 改进措施与 LESSONS 沉淀 (Action Items)

- [ ] Action 1: 补齐针对该故障场景的自动化测试用例
- [ ] Action 2: 将复盘教训 L-NNN 写入 `.specs/LESSONS.md`
