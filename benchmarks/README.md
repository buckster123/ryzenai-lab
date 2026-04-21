# Benchmarks

Reproducible performance data from `ryzenai-lab` hardware. Each subfolder is a dated sweep with its own README.md, writeup, and raw JSON results.

## Index

| Sweep | Hardware | Stack | Coverage |
|---|---|---|---|
| [`npu-4k-sweep-apr2026/`](npu-4k-sweep-apr2026/) | Ryzen AI 5 340 (Krackan Point) | SDK 1.7.1, kernel 6.19, pmode turbo | 12 models, 135M–8B, NPU-4K Full-Fusion |

## Raw JSON format

Each JSON is the output of AMD's `model_benchmark -o <file>` and contains:

- `initialization_time_seconds` — cold-start time to first forward pass
- `overall_peak_memory_gb` — RSS during the run
- `prompt_lengths.<N>.avg_ttft_seconds` — time-to-first-token for N-token prompt (prefill indicator)
- `prompt_lengths.<N>.avg_tokens_per_second` — decode throughput (generation indicator)

Prefill tokens/sec is computed as `N / avg_ttft_seconds`.
