# ryzenai-lab

Experiments, notes, and benchmarks for AMD Ryzen AI hardware on Linux.

**Host:** Lenovo laptop · AMD Ryzen AI 5 340 (Krackan Point, PCI `1022:17f0`) · Radeon 840M iGPU (gfx1152) · 24 GB LPDDR5 · Ubuntu 25.10.

## What's inside

- [`docs/`](docs/) — writeups and recipes (setup, gotchas, regressions)
- [`benchmarks/`](benchmarks/) — reproducible perf numbers with raw JSON
- [`experiments/`](experiments/) — small runnable scripts (ONNX on NPU, llama.cpp on iGPU, etc)
- [`scripts/`](scripts/) — helpers (env setup, bench drivers, status tools)

## Highlight: Krackan NPU beats published Strix numbers on Linux

On Ubuntu 25.10 + kernel 6.19.13 + `amdxdna` out-of-tree + Ryzen AI SDK 1.7.1 + `pmode turbo`, running AMD's NPU-4K Full-Fusion models:

| Model | Params | Prefill t/s | Decode t/s |
|---|---:|---:|---:|
| SmolLM2-135M | 0.14B | **1422** | **137** |
| Llama-3.2-1B | 1.2B | **2133** | **65** |
| Llama-3.2-3B-Instruct | 3.2B | **985** | **25** |
| Phi-4-mini | 3.8B | **853** | **23** |
| Mistral-7B / Qwen2.5-7B / DeepSeek-R1-Distill-7B | ~7.5B | ~590 | ~13 |
| Meta-Llama-3.1-8B-Instruct | 8.0B | **557** | **13** |

AMD's published reference for Llama-3.2-3B on **Strix** (full 8×8 tiles) is **865 / 17.6 t/s**. Our Krackan (6×8 tiles) delivers **985 / 25 t/s** on identical workloads, at ~10-15W NPU+SoC power. Full writeup: [`benchmarks/npu-4k-sweep-apr2026/README.md`](benchmarks/npu-4k-sweep-apr2026/README.md).

## Quickstart (7 steps)

Assuming fresh Ubuntu 25.10:

```bash
# 1. Build out-of-tree amdxdna + XRT (fixes SVA ENOTSUP on 25.10)
git clone --recursive https://github.com/amd/xdna-driver.git ~/xdna-driver
cd ~/xdna-driver && sudo ./tools/amdxdna_deps.sh
cd xrt/build && ./build.sh -npu -opt
cd Release && sudo apt install --fix-broken -y ./xrt_*_25.10-amd64-{base,base-dev,npu}.deb
cd ~/xdna-driver/build && ./build.sh -release
sudo apt install --fix-broken -y ./Release/xrt_plugin.*-amdxdna.deb

# 2. Install Ryzen AI SDK 1.7.1 (download ryzen_ai-1.7.1.tgz from ryzenai.docs.amd.com)
tar -xvzf ryzen_ai-1.7.1.tgz -C ~/ryzen_ai
cd ~/ryzen_ai && ./install_ryzen_ai.sh -a yes -p ~/ryzen_ai/venv

# 3. Enable turbo NPU power mode
sudo /opt/xilinx/xrt/bin/xrt-smi configure --pmode turbo

# 4. Source the env helper from this repo
source scripts/env.sh

# 5. Pull a model
hf download amd/Llama-3.2-3B-Instruct_rai_1.7.1_npu_4K \
  --local-dir Llama-3.2-3B-Instruct_rai_1.7.1_npu_4K

# 6. Sanity test
python ~/ryzen_ai/venv/quicktest/quicktest.py   # expect "Test Finished"

# 7. Benchmark
model_benchmark -i Llama-3.2-3B-Instruct_rai_1.7.1_npu_4K/ \
  -l 128 -g 128 -r 3 -w 1 \
  -f ~/ryzen_ai/venv/LLM/examples/amd_genai_prompt.txt
```

Or run the whole sweep with [`scripts/bench_suite.sh`](scripts/bench_suite.sh).

## Key findings

- **Hybrid flow is broken on Linux 1.7.1** — no iGPU execution provider (only VitisAI + CPU). "Hybrid" models fall back to NPU+CPU and run *slower* than NPU-only. Always prefer the [`ryzen-ai-171-npu-4k`](https://huggingface.co/collections/amd/ryzen-ai-171-npu-4k) or [`-npu-16k`](https://huggingface.co/collections/amd/ryzen-ai-171-npu-16k) collections on Linux.
- **Kernel 6.17/6.18 hits an IOMMU-SVA regression** (`SVA bind device failed, ret -95`). Fix: run kernel 6.19+ and use the out-of-tree `amdxdna` driver. Details in [`docs/krackan-npu-ubuntu-25.10.md`](docs/krackan-npu-ubuntu-25.10.md).
- **Decode scales ~100/params(B)** cleanly across the 135M–8B range — memory-bandwidth-bound on the LPDDR5 bus.
- **gpt-oss-20b MoE aborts on Krackan** inside `AMDQMoEKernel::AMDQMoEKernel()` — kernel appears hardcoded for Strix's 8×8 tile layout. Works on Strix.
- **gemma-3-4b-it needs two tweaks** (symlink tree for a hardcoded relative path + `-ml 4096` flag). Details in the benchmark README.

## Status

| Path | Status |
|---|---|
| NPU via ONNX Runtime + VitisAIExecutionProvider | ✅ working |
| iGPU (gfx1152) via llama.cpp HIP | ✅ working |
| NPU LLM inference (NPU-4K Full-Fusion) | ✅ working, 12 models benched |
| NPU hybrid (NPU+iGPU) | ⚠️ broken on Linux 1.7.1 (no iGPU EP) |
| Embedder on NPU (bge-small quantized) | 🚧 next |
| Compile a non-AMD-published model (Qwen3 dense / MoE) | 🚧 planned |

## Community

If you're on Krackan (Ryzen AI 300 series) or Strix Halo and want to help fill in data points, open an issue or PR. Raw JSON bench results are checked in alongside the writeups.

## License

MIT. Benchmark data is CC-BY.
