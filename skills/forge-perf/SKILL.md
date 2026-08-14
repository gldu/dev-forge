---
name: forge-perf
description: Use when measuring performance baselines, benchmarking latency/throughput, profiling memory leaks, or running performance optimization loops.
---

# forge-perf — 性能基准与压测优化

## Goal

测量系统性能基准，识别 QPS/p95/p99 延迟瓶颈与内存泄漏，并通过测量驱动的迭代循环优化核心路径。

## Workflow

### 1. 建立性能基准 (Baseline Measurement)

1. 在未修改代码前，运行基准测试并记录初始指标：
   - 吞吐量 (QPS / RPS)
   - 延迟分布 (p50 / p95 / p99)
   - CPU 与 内存 峰值占用
   - 前端打包体积 / 首屏加载 (LCP / FID)

### 2. 瓶颈分析与诊断 (Profiling)

1. 定位性能瓶颈的根因：
   - **数据库层**：全表扫描、未建索引、N+1 查询。
   - **计算与 IO**：大循环、同步阻塞 IO、未使用的过大依赖。
   - **前端层**：重复渲染、大图未压缩、阻塞主线程的长任务。

### 3. 递归优化与对比 (Benchmark Iteration Loop)

1. 提出 2~3 种优化方案（如增加缓存、异步并行化、批量处理、索引优化）。
2. 逐一应用方案并重复运行基准测试。
3. **保留条件**：仅保留产生显著性能提升且 100% 跑通全量单元测试的方案。

### 4. 输出性能对比报告

输出 Benchmark 对比表：
| 指标 | 优化前 (Baseline) | 优化后 (Optimized) | 提升幅度 |
|---|---|---|---|
| p95 延迟 | 450ms | 45ms | ⚡ 90% |
| QPS | 120 req/s | 1100 req/s | ⚡ 9.1x |

## Validation

- [ ] 已记录优化前的 Baseline 数据
- [ ] 优化后全量回归测试全部通过
- [ ] 关键性能指标有 empirical 测量数据支撑

## Resources

- `references/PERFORMANCE.md` — 性能压测与 Benchmark 报告模板
