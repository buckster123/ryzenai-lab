# ryzenai-lab

Experiments, notes, and benchmarks for AMD Ryzen AI hardware on Linux.

Host: Lenovo ThinkBook / ThinkPad, AMD Ryzen AI 5 340 (Krackan Point, PCI 1022:17f0), Radeon 840M iGPU (gfx1152), Ubuntu 25.10.

## What's here

- `docs/` — writeups and recipes (setup, gotchas, regressions).
- `experiments/` — small runnable scripts (ONNX on NPU, llama.cpp on iGPU, etc).
- `benchmarks/` — reproducible perf numbers.
- `scripts/` — helpers (env setup, install patches).

## First recipe: getting the NPU alive on Ubuntu 25.10

See [docs/krackan-npu-ubuntu-25.10.md](docs/krackan-npu-ubuntu-25.10.md).

TL;DR — stock 25.10 kernel 6.17.0-22 hits an `amdxdna` "SVA bind device failed, ret -95" error (known IOMMU-SVA stable-backport regression, xdna-driver#1028). Boot mainline 6.19.x, set memlock unlimited, install RyzenAI SDK 1.7.1 with a small venv patch — done.

## Status

| Path | Status |
|---|---|
| NPU via ONNX Runtime + VitisAIExecutionProvider | ✅ working |
| iGPU (gfx1152) via llama.cpp HIP | ✅ working |
| NPU hybrid-llm path | 🚧 next |
| Embedder on NPU (bge-small quantized) | 🚧 next |

## License

MIT — see [LICENSE](LICENSE).
