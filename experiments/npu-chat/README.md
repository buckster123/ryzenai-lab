# npu-chat

A tiny one-file CLI to go from "I have the stack installed" to "I'm chatting with an LLM on the Ryzen AI NPU" in one command.

## Prerequisites

See the [repo-level README](../../README.md) for full setup. In short:

- Ryzen AI SDK 1.7.1 installed at `~/ryzen_ai/venv`
- amdxdna + XRT working (`xrt-smi examine` sees your NPU)
- `hf auth login` done (any HF account; Pro helps for bulk pulls)
- Recommended: `sudo /opt/xilinx/xrt/bin/xrt-smi configure --pmode turbo`

## Install

```bash
cp experiments/npu-chat/npu-chat ~/.local/bin/
chmod +x ~/.local/bin/npu-chat
```

or just run it in place.

## Use

```bash
npu-chat                          # chat with Llama-3.2-3B-Instruct (default)
npu-chat --list                   # show all curated presets
npu-chat -m phi-4-mini            # chat with a different preset
npu-chat -m smollm2-135m          # blazing fast tiny model
npu-chat -m deepseek-r1-7b        # reasoner

# any AMD-hosted NPU-4K repo also works:
npu-chat -m amd/Qwen2.5-Coder-7B-Instruct_rai_1.7.1_npu_4K

# or run a short benchmark instead of a chat:
npu-chat -b -m llama-3b
```

On first use of a model it downloads ~2-15 GB to `~/run_llm/<model>/`, then hands off to AMD's stock `model_chat.py`.

## What it does

1. Sources `/opt/xilinx/xrt/setup.sh` and the Ryzen AI venv
2. Sets `LD_LIBRARY_PATH`, `RYZENAI_EP_PATH`, `XRT_INI_PATH` (num_heap_pages=8)
3. Downloads the requested model via `hf download` if missing
4. Applies known model-specific fixups (currently: gemma-3 `dd_cache` symlink)
5. Execs into `model_chat.py` or `model_benchmark` with the right flags

No magic — it's a thin ergonomic wrapper so newcomers don't have to remember the env dance.

## Presets (curated, Krackan-validated)

Numbers are from [../../benchmarks/npu-4k-sweep-apr2026/](../../benchmarks/npu-4k-sweep-apr2026/) on a Ryzen AI 5 340 at pmode turbo.

| Preset | Model | Decode t/s | Peak RAM |
|---|---|---:|---:|
| `smollm2-135m` | SmolLM2-135M | 137 | 1.4 GB |
| `llama-1b` | Llama-3.2-1B-Instruct | 65 | 6.8 GB |
| `qwen-1.5b` | Qwen-2.5-1.5B-Instruct | 44 | 6.7 GB |
| `qwen-3b` | Qwen2.5-3B-Instruct | 27 | 9.0 GB |
| `llama-3b` (default) | Llama-3.2-3B-Instruct | 25 | 10.3 GB |
| `phi-4-mini` | Phi-4-mini-instruct | 23 | 13.0 GB |
| `phi-4-mini-reason` | Phi-4-mini-reasoning | 23 | 13.0 GB |
| `gemma-3-4b` | gemma-3-4b-it | 17 | 10.1 GB |
| `mistral-7b` | Mistral-7B-Instruct-v0.3 | 14 | 11.9 GB |
| `qwen-7b` | Qwen2.5-7B-Instruct | 13 | 14.7 GB |
| `deepseek-r1-7b` | DeepSeek-R1-Distill-Qwen-7B | 13 | 14.9 GB |
| `llama-8b` | Meta-Llama-3.1-8B-Instruct | 13 | 15.8 GB |
