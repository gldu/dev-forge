# 性能压测与基准报告 (Performance Report)

- **压测场景**: <接口 / 关键计算路径>
- **目标 QPS / 延迟预算**: <要求>

---

## 1. 基准测量 (Baseline)

- **压测工具**: k6 / locust / benchmark-runner
- **Baseline 数据**:
  - p50 延迟: XX ms
  - p95 延迟: XX ms
  - p99 延迟: XX ms
  - QPS: XX req/s
  - 内存峰值: XX MB

---

## 2. 瓶颈定位 (Profiling)

- **主要瓶颈**: N+1 数据库查询 / 同步阻塞 IO / 内存泄漏
- **受压符号/热点路径**: `<filename>:<function_name>`

---

## 3. 递归优化对比表 (Optimization Iterations)

| 优化迭代 | 实施方案 | p95 延迟 | QPS | 全量单测状态 | 结论 |
|---|---|---|---|---|---|
| Baseline | 优化前 | 450ms | 120 req/s | ✅ | 基线 |
| Iteration 1 | 加 Redis 缓存 | 45ms | 1100 req/s | ✅ | ⚡ 保留 |
| Iteration 2 | 异步多线程 | 40ms | 1150 req/s | ❌ 测试竞争 | ❌ 放弃 |

---

## 4. 最终结论

优化后性能相比 Baseline 提升：**⚡ XX%**，且全量测试 100% 跑通。
