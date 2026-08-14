---
name: forge-rollback
description: Use when safely rolling back failed deployments, reverting database schema migrations, executing emergency hotfixes, or producing RCA incident reports.
---

# forge-rollback — 线上故障回滚与 RCA 复盘

## Goal

在发布失败或发生线上故障时，安全撤销异常变更、执行数据库 Migration 回滚、快速上线 Hotfix 并产出 Root Cause Analysis (RCA) 故障复盘报告。

## 触发条件

- **何时触发**：发布失败 / 线上服务异常 / DB 迁移失败 / 出现需要紧急止血的故障（安全漏洞、数据损坏、大规模功能异常）时直接触发本 skill，线上止血优先于现场修复。
- **何时不该触发**：本地 / 开发环境 bug、测试失败、未上线的代码缺陷 → 不属于线上故障，转 `forge-fix` 走 RED → GREEN → REFACTOR 常规修复流程，本 skill 不介入。

## 故障处置决策表

面对线上故障先按下表**三选一**定处置路径，再进入对应 Workflow：

| 场景 | 处置 | 负责 skill |
|---|---|---|
| 数据损坏 / 安全漏洞 / 大规模功能异常 | **回滚**至上一已知稳定版本（本 skill 主路径） | `forge-rollback` |
| 小范围 bug 且已有快速补丁方案 | **热修**：从稳定 tag 切 hotfix 分支，修复后直接部署 | `forge-rollback` 统筹，补丁走 `forge-fix` |
| 配置漂移 / 环境问题（代码本身无缺陷） | **重部署**：核对配置与环境后重新部署同版本，不回滚代码 | `forge-rollback` 确认，重部署由运维 / 平台侧执行 |

> 判定规则：先确认**根因是否在代码**——代码缺陷且影响面大 → 回滚；代码缺陷且影响面小 → 热修；代码无缺陷（配置 / 环境 / 依赖漂移）→ 重部署。

## Workflow

### 1. 紧急安全回滚 (Emergency Rollback)

**前置确认（执行回滚前必做）**：
1. 确认**当前线上版本号**（`git describe` / 发布记录 / 容器镜像 tag）。
2. 确认**目标稳定版本**：选择受影响范围最小的上一已知稳定版本。
3. 确认**DB 迁移文件 up/down 状态**：核对迁移文件存在可逆 `down` 脚本（R4.5），明确目标版本对应的 schema 状态后再执行。

随后执行回滚：
1. 确认线上异常范围与影响面。
2. 回滚 Commit 或发布版本至上一已知稳定版本。
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

## 回滚后 STATE.md 更新

回滚完成后读取仓库根 `STATE.md`（字段契约见 forge-router 的 STATE.md 模板），按现状更新**仅字段契约内存在**的字段，禁止自造字段：

- 回滚发生在**活跃 change 中断**时（如线上故障打断 dev）→ 更新 `interrupted_at` 记录中断位置与原因，例如：
  ```yaml
  interrupted_at: 回滚 2026-08-14: v1.3.0 → v1.2.1，线上故障止血，待恢复后继续
  ```
- 无活跃 change（`active_change` 已为 `-`）→ 无需改动 STATE.md 版本相关字段；回滚前后的版本号记录在 RCA 报告与 `.specs/LESSONS.md`，不写入 STATE.md。

## 边界

- **与 `forge-release`**：`forge-release` 管**发布前预防**（pre-release gate / 回滚预案 / 灰度 / 可逆 migration 验证），本 skill 管**发布后止血**（回滚 / 热修 / 重部署 + RCA）。上线前由 forge-release 写回滚预案；发布失败后按预案调用本 skill 执行，本 skill 产出的 RCA 教训反向补充后续发布的预案。
- **与 `forge-fix`**：`forge-fix` 处理**本地 / 开发环境**的缺陷重现与修复（RED → GREEN → REFACTOR，先写重现测试）；本 skill 处理**线上故障止血**（回滚 / 热修 / 重部署 + RCA）。线上故障优先止血，不允许先花时间在本地环境完整重现再处理；热修补丁本身的测试要求沿用 `forge-fix` 纪律。

## Constraints

- 回滚数据库变更前必须确认数据安全
- Hotfix 必须有自动化测试覆盖，严禁无测试直接改线上
- 执行回滚前必须确认当前线上版本号与目标稳定版本，禁止盲回滚

## Validation

- [ ] 线上系统已恢复至正常状态
- [ ] 数据库 schema 与数据已对齐一致
- [ ] 已记录回滚前版本号与目标版本
- [ ] STATE.md 已按字段契约更新（如适用）
- [ ] RCA 故障复盘报告已输出并同步至 `.specs/LESSONS.md`

## Resources

- `references/ROLLBACK-RCA.md` — 线上故障回滚与 RCA 复盘报告模板
