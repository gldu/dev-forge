---
name: forge-release
description: Use when deploying validated changes to production, running pre-release checklists, deriving semantic versions, planning canary/grayscale rollouts, or preparing rollback plans before going live.
---

# forge-release — 发布部署（8-release · D-deploy）

> **8 前缀表示发布阶段**：接在 7-integration 之后，只在 INTEGRATION 全部通过后触发。不写 CHANGE.md / REQUIREMENT.md。直接产出版本 tag + 发布记录。

## Goal

把通过 INTEGRATION 验收的 change 安全发布到线上：发布前检查（Pre-release Gate）、版本推导（SemVer）、灰度策略、回滚预案、发布后验证。

## Workflow

### 1. 发布前检查（Pre-release Gate · 强制）

逐一核对以下输入，**任一不满足立即回退**：

| 检查项 | 来源 | 通过标准 |
|---|---|---|
| 全量测试 | `TEST.md` | 全绿，无未解决失败 |
| 审查结论 | `REVIEW.md` | 无未解决 Critical（或已人工确认接受）|
| UAT 验收 | `UAT.md` | 全部通过 |
| 归档/CHANGELOG | forge-integration 产物 | 归档完成、CHANGELOG 已更新 |
| 工作区状态 | git | 干净，无未提交改动 |

### 2. 版本推导（SemVer）

1. 读 git tags 取当前最大版本号。
2. 按 change 内容推导：**破坏性变更 → major+1**；**新功能 → minor+1**；**bug 修复 / 内部优化 → patch+1**。
3. 输出建议版本号，**用户确认后**才打 tag。

### 3. 灰度策略（按风险等级选择）

| 风险等级 | 场景 | 策略 |
|---|---|---|
| 高 | 核心链路 / 数据迁移 / 大规模变更 | canary（1%）→ 10% → 50% → 100% |
| 中 | 常规功能发布 | 10% → 100% |
| 低 | bugfix / 内部优化 | 直接全量（仍须保留回滚预案）|

涉及 DB migration 时，先验证 `down` 脚本可逆（详见 forge-rollback）。

### 4. 回滚预案（发布前必写）

- 明确**回滚目标版本** + **触发条件**（错误率 / 延迟阈值 / 关键链路探活失败）
- 记录 DB migration 的 `down` 脚本路径
- 发布失败 → 立即按预案调用 forge-rollback

### 5. 发布后验证（Post-release Smoke）

- 核心链路 5 分钟探活
- 观察错误率 / 延迟指标
- 异常 → 按预案回滚或转 forge-fix 热修

## Constraints

- Pre-release Gate 任一检查失败禁止发布
- **无回滚预案禁止发布**
- 灰度策略必须按风险等级选择，禁止一律全量
- 打 tag / 部署等不可逆动作必须用户确认
- 禁止发布未归档的 change（先走 7-integration）

## Validation

- [ ] 发布前检查清单全部通过
- [ ] 版本号已推导并经用户确认
- [ ] 回滚预案已写明目标版本 + 触发条件
- [ ] 发布后 smoke 验证已完成
- [ ] STATE.md / CHANGELOG 已更新，版本 tag 已打

## Resources

- `references/RELEASE.md` — 发布检查清单与回滚预案模板（产出填好后存 `.specs/release/<YYYY-MM-DD>-RELEASE.md`）
