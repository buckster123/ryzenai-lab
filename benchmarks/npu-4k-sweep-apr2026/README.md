# Ryzen AI 5 340 (Krackan Point) NPU LLM Benchmark Sweep

**Hardware:** Lenovo laptop · AMD Ryzen AI 5 340 · Radeon 840M iGPU · 24 GB LPDDR5
**NPU:** XDNA 2, Krackan 1 variant, `aie2p`, 6×8 = 48 AIE tiles, firmware 1.1.2.64
**OS:** Ubuntu 25.10 (questing), kernel **6.19.13-061913-generic**
**Stack:** AMD Ryzen AI Software 1.7.1, XRT 2.23.0, out-of-tree `amdxdna` 2.23.0_20260419 (DKMS from `github.com/amd/xdna-driver`), NPU power mode **turbo**
**Date:** April 2026

---

## TL;DR

Krackan Point's NPU — a cut-down XDNA 2 block with 48 AIE tiles (vs Strix's 64) rated around 16 TOPS — runs modern LLMs at unexpectedly good speed on Linux through AMD's official Ryzen AI Software 1.7.1 stack. With NPU-only Full-Fusion 4K models and `pmode turbo`, this laptop's NPU **matches or beats AMD's published Strix numbers** on identical workloads, at roughly 10–15 W of NPU+SoC power.

The "hybrid" NPU+iGPU flow, by contrast, is effectively broken on Linux 1.7.1 (no GPU execution provider in the Linux binaries — only VitisAI and CPU). Always prefer the **NPU-4K Full-Fusion** collection on Linux.

## Results

| Model | Arch | Params (B) | Prefill (t/s) | Decode (t/s) | Peak RAM (GB) | Init (s) |
|---|---|---:|---:|---:|---:|---:|
| SmolLM2-135M-Instruct | Llama-style | 0.14 | 1422 | 137.10 | 1.4 | 0.7 |
| Llama-3.2-1B-Instruct | Llama 3.2 | 1.24 | 2133 | 64.60 | 6.8 | 2.0 |
| Qwen-2.5_1.5B_Instruct | Qwen 2.5 | 1.54 | 1600 | 43.95 | 6.7 | 2.3 |
| Qwen2.5_3B_Instruct | Qwen 2.5 | 3.09 | 985 | 27.03 | 9.0 | 3.4 |
| Llama-3.2-3B-Instruct | Llama 3.2 | 3.21 | 985 | 25.21 | 10.3 | 3.7 |
| Phi-4-mini-instruct | Phi-4 | 3.84 | 853 | 22.62 | 13.0 | 4.8 |
| Phi-4-mini-reasoning | Phi-4 | 3.84 | 853 | 22.65 | 13.0 | 5.0 |
| gemma-3-4b-it | Gemma 3 (multimodal) | 4.30 | 320 | 17.17 | 10.1 | 4.8 |
| Mistral-7B-Instruct-v0.3 | Mistral | 7.25 | 582 | 13.61 | 11.9 | 5.9 |
| Qwen2.5-7B-Instruct | Qwen 2.5 | 7.62 | 610 | 13.42 | 14.7 | 6.7 |
| DeepSeek-R1-Distill-Qwen-7B | Qwen 2.5 (distill) | 7.62 | 610 | 13.36 | 14.9 | 6.8 |
| Meta-Llama-3.1-8B-Instruct | Llama 3.1 | 8.03 | 557 | 13.22 | 15.8 | 7.0 |

**Benchmark config:** 128-token prompt, 128-token generation, 3 reps, 1 warmup, via AMD's `model_benchmark` binary from the 1.7.1 SDK.

### Did not complete

- **LFM2-1.2B / LFM2-2.6B (Liquid Foundation Models)** — ships as raw ONNX (`full.onnx` + `full.pb.bin`), not OGA format. Needs a different runner (stock `onnxruntime_genai` or AMD's Python high-level SDK). Not benched here, but the files load and run on iGPU via ORT.
- **gpt-oss-20b (OpenAI's open MoE)** — listed in the NPU-4K collection but crashes on Krackan inside `AMDQMoEKernel::AMDQMoEKernel()` (SIGABRT on kernel construction). The quantized-MoE kernel appears to be hardcoded for Strix's 8×8 tile layout; no workaround found via config knobs. Runs on Strix per AMD's materials.

### Highlights

- **Beats Strix on Llama-3.2-3B:** AMD's published reference is ~865 prefill / ~17.6 decode on Strix; Krackan on this benchmark delivered **985 / 25.2** for the same model and context length.
- **Phi-4-mini hits the sweet spot** at 3.84 B params: 853 t/s prefill, 22.6 t/s decode, 13 GB peak RAM. A reasoner variant (Phi-4-mini-reasoning) runs at essentially identical speed on identical weights' size class.
- **Small models fly:** SmolLM2-135M decodes at **137 t/s** (batch-1). Llama-3.2-1B at **64.6 t/s**. Useful as consolidation/rerank/dreaming workhorses that can run continuously in the background at low power.
- **7–8B class lands ~13 t/s decode** with prefill 550–610 t/s. Interactive-chat-usable on a laptop. Mistral-7B, Qwen2.5-7B, DeepSeek-R1-Distill-Qwen-7B, and Llama-3.1-8B all clustered tightly here.
- **Param-to-throughput scaling is clean** — decode t/s tracks roughly `100 / params(B)` across the range (135M → 8B), which is exactly what you'd expect from memory-bandwidth-bound decode on a fixed bus.

## Reproduction recipe (7 steps, Ubuntu 25.10)

```bash
# 1. Build out-of-tree amdxdna + XRT from AMD's xdna-driver repo
#    (fixes SVA-bind ENOTSUP on 25.10 / kernel 6.17+)
git clone --recursive https://github.com/amd/xdna-driver.git ~/xdna-driver
cd ~/xdna-driver && sudo ./tools/amdxdna_deps.sh

cd xrt/build && ./build.sh -npu -opt
cd Release && sudo apt install --fix-broken -y ./xrt_*_25.10-amd64-{base,base-dev,npu}.deb

cd ~/xdna-driver/build && ./build.sh -release
sudo apt install --fix-broken -y ./Release/xrt_plugin.*-amdxdna.deb

# 2. Install SDK 1.7.1 (download ryzen_ai-1.7.1.tgz from ryzenai.docs.amd.com)
tar -xvzf ryzen_ai-1.7.1.tgz -C ~/ryzen_ai
cd ~/ryzen_ai && ./install_ryzen_ai.sh -a yes -p ~/ryzen_ai/venv

# 3. Enable turbo NPU power mode
sudo /opt/xilinx/xrt/bin/xrt-smi configure --pmode turbo

# 4. Env setup
source /opt/xilinx/xrt/setup.sh
source ~/ryzen_ai/venv/bin/activate
export RYZEN_AI_INSTALLATION_PATH="$VIRTUAL_ENV"
export LD_LIBRARY_PATH=/lib/x86_64-linux-gnu:$RYZEN_AI_INSTALLATION_PATH/deployment/lib:$LD_LIBRARY_PATH
export RYZENAI_EP_PATH=$RYZEN_AI_INSTALLATION_PATH/deployment/lib/libonnxruntime_providers_ryzenai.so
cat > xrt.ini <<EOF
[Debug]
num_heap_pages = 8
EOF
export XRT_INI_PATH=$PWD/xrt.ini

# 5. Pull a pre-optimized NPU-4K model from AMD's HuggingFace collection
hf download amd/Llama-3.2-3B-Instruct_rai_1.7.1_npu_4K \
  --local-dir Llama-3.2-3B-Instruct_rai_1.7.1_npu_4K

# 6. Sanity test
python ~/ryzen_ai/venv/quicktest/quicktest.py   # should print "Test Finished"

# 7. Benchmark
~/ryzen_ai/venv/LLM/examples/model_benchmark \
  -i Llama-3.2-3B-Instruct_rai_1.7.1_npu_4K/ \
  -l 128 -g 128 -r 3 -w 1 \
  -f ~/ryzen_ai/venv/LLM/examples/amd_genai_prompt.txt
```

## Gotchas discovered

### 1. "Hybrid" models are slower than NPU-only on Linux
On Linux 1.7.1, `onnxruntime.get_available_providers()` returns only `['VitisAIExecutionProvider', 'CPUExecutionProvider']`. DirectML (the Windows iGPU path) doesn't exist on Linux, and no ROCm / MIGraphX EP is wired into the Ryzen AI runtime. Result: "hybrid" models fall back to **NPU + CPU**, which is *worse* than pure NPU for decode. Empirically on Llama-3.2-3B: hybrid = 324 / 3.25 t/s; NPU-4K = 985 / 25.2 t/s. **Always prefer `ryzen-ai-171-npu-4k` (or `-16k`) over `ryzen-ai-171-hybrid` on Linux.**

### 2. gemma-3-4b needs two manual fixes to run
It's a multimodal model (vision branch + embedding ONNX + partitioned attention):
- Its `genai_config.json` hardcodes a relative `dd_cache` path at `gemma-3-4b-npu-basic-text-logit-pruning/partitioned/cache`. Fix with a symlink tree inside the model dir:
  ```bash
  cd gemma-3-4b-it_rai_1.7.1_npu_4K
  mkdir -p gemma-3-4b-npu-basic-text-logit-pruning
  ln -sfn ../partitioned gemma-3-4b-npu-basic-text-logit-pruning/partitioned
  ```
- The KV cache buffer shape is fixed. Pass `-ml 4096` (or whatever the config's `max_lenght_for_kv_cache` says) to `model_benchmark`, otherwise you'll hit `shape {1,4,256,256} vs {1,4,4096,256}` during the If-node in prefill.

### 3. gpt-oss-20b aborts in AMDQMoEKernel on Krackan
Core dump shows `AMDQMoEKernel::AMDQMoEKernel()` calling `abort()` inside its constructor on session init. Tweaking `hybrid_opt_qmoe_dynamic_experts`, `hybrid_opt_qmoe_num_dynamic_layers`, `hybrid_opt_qmoe_bind_all`, and `hybrid_opt_max_seq_length` doesn't help. Strong smell of a hardcoded Strix tile-layout assumption in the MoE kernel. AMD likely needs to ship a Krackan-specific MoE xclbin.

### 4. The "Legacy TXN flow" XRT warning is benign
Every model ships an xclbin in the older TXN (transaction) format. XRT 2.23 has a compat shim; model runs fine. Warning will go away when AMD re-packs the xclbins.

### 5. Ubuntu 25.10 + kernel 6.19 require the out-of-tree driver
The in-tree `amdxdna` on 6.17+ kernels throws `SVA bind device failed, ret -95` (IOMMU regression). Source-built driver from `amd/xdna-driver` fixes it; dmesg should show `PASID address mode enabled` on load.

### 6. HuggingFace rate limit vs 1000-file repos
The NPU-4K model repos contain hundreds to thousands of tiny per-shape and per-token-position files (one `.ctrlpkt`, `.meta`, `.super` per prefill shape, plus a token-fusion `cache/*.const` file per vocab token for models like gemma-3 — that's ~7700 files). A single repo download on a free HF account can exhaust the 1000-API-req / 5-min quota. HF Pro (10× limit) or scripted backoff (6 min between failed attempts) is advisable for bulk pulls.

### 7. `xrt-smi` isn't on root's PATH after `sudo`
Because XRT sets up its binaries via `source /opt/xilinx/xrt/setup.sh` on the user's shell, sudo gets a fresh env. When needing to change pmode or otherwise root-configure XRT, use the full path:
```bash
sudo /opt/xilinx/xrt/bin/xrt-smi configure --pmode turbo
```

## Context: what this number class means

On Krackan at 15W SoC power (NPU + SoC idle + LPDDR5 refresh):
- **Llama-3.2-3B at 25 t/s decode** = comfortable interactive chat on a laptop, faster than reading speed
- **SmolLM2-135M at 137 t/s** = the sort of throughput where you can run continuous background tasks (embedding, reranking, draft-speculation, dreaming/consolidation workloads) without thinking about battery
- **7–8B class at 13 t/s decode** = usable as a primary local assistant, good RAG backend

Comparing to the same laptop's llama.cpp baselines (Qwen2.5-7B Q4_K_M): CPU = 12.5 t/s decode (35 W), iGPU via HIP = 5.3 t/s decode (~18 W). The NPU, per equivalent-class model, does ~13 t/s at ~15 W — i.e., it's **~1.0×** the CPU decode speed, **~2.5×** the iGPU, and better than both on prefill by several × — at roughly half the power of the CPU.

## What didn't we measure yet

- **Longer contexts (1K, 2K, 4K prompts)** — NPU-4K supports up to 4096 tokens. Prefill t/s will drop as prompt grows; we only covered 128.
- **NPU-16K (Token Fusion)** variants — different compilation target, should handle long-context RAG.
- **Real-world latency vs throughput** — these are `model_benchmark` synthetic; would be good to confirm with `model_chat.py` interactively.
- **Energy measurement** — the 10–15 W number here is estimated, not measured directly. `powertop` + on-chip sensors would pin it down.
- **Quality parity** — these are AWQ uint4 group-128 asymmetric quants with bf16 activations. Perplexity vs FP16 baseline not measured. AMD doesn't publish per-model eval scores for these.

## License / acknowledgments

Models from [amd/ryzen-ai-171-npu-4k](https://huggingface.co/collections/amd/ryzen-ai-171-npu-4k) collection under their respective base-model licenses. Ryzen AI Software 1.7.1 under AMD's EULA. This writeup is CC-BY by Andre (2026).
