#!/bin/bash
# NPU-4K broad benchmark suite — Krackan Point (Ryzen AI 5 340)
# Downloads each model, benches it, records JSON results, moves on.

set -u
source /opt/xilinx/xrt/setup.sh >/dev/null 2>&1
source ~/ryzen_ai/venv/bin/activate
export RYZEN_AI_INSTALLATION_PATH="${VIRTUAL_ENV}"
export LD_LIBRARY_PATH="/lib/x86_64-linux-gnu:${RYZEN_AI_INSTALLATION_PATH}/deployment/lib:${LD_LIBRARY_PATH:-}"
export RYZENAI_EP_PATH="${RYZEN_AI_INSTALLATION_PATH}/deployment/lib/libonnxruntime_providers_ryzenai.so"
export XRT_INI_PATH="${HOME}/run_llm/xrt.ini"
export PATH="${RYZEN_AI_INSTALLATION_PATH}/LLM/examples:${PATH}"

PROMPT=~/ryzen_ai/venv/LLM/examples/amd_genai_prompt.txt
LONG_PROMPT=~/ryzen_ai/venv/LLM/examples/amd_genai_prompt_long.txt
RESULTS=~/run_llm/results
LOG=~/run_llm/results/bench.log
mkdir -p "$RESULTS"
: > "$LOG"

MODELS=(
  "amd/SmolLM2-135M-Instruct_rai_1.7.1_npu_4K"
  "amd/Llama-3.2-1B-Instruct_rai_1.7.1_npu_4K"
  "amd/Qwen-2.5_1.5B_Instruct_rai_1.7.1_npu_4K"
  "amd/LFM2-2.6B-ONNX_rai_1.7.1"
  "amd/Qwen2.5_3B_Instruct_rai_1.7.1_npu_4K"
  "amd/Llama-3.2-3B-Instruct_rai_1.7.1_npu_4K"
  "amd/gemma-3-4b-it_rai_1.7.1_npu_4K"
  "amd/Phi-4-mini-instruct_rai_1.7.1_npu_4K"
  "amd/Phi-4-mini-reasoning_rai_1.7.1_npu_4K"
  "amd/Mistral-7B-Instruct-v0.3_rai_1.7.1_npu_4K"
  "amd/Qwen2.5-7B-Instruct_rai_1.7.1_npu_4K"
  "amd/DeepSeek-R1-Distill-Qwen-7B_rai_1.7.1_npu_4K"
  "amd/Meta-Llama-3.1-8B-Instruct_rai_1.7.1_npu_4K"
  "amd/gpt-oss-20b_rai_1.7.1_npu_4K"
)

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

for full in "${MODELS[@]}"; do
  name="${full##*/}"
  dir="$HOME/run_llm/$name"
  log "=== $name ==="
  
  if [ ! -d "$dir" ] || [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
    log "  Downloading..."
    hf download "$full" --local-dir "$dir" >>"$LOG" 2>&1 || { log "  DOWNLOAD FAILED"; continue; }
  else
    log "  Already present."
  fi
  sz=$(du -sh "$dir" | awk '{print $1}')
  log "  Size on disk: $sz"
  
  # Standard bench: 128 prompt / 128 gen, 3 reps, 1 warmup
  log "  Bench standard (l=128 g=128 r=3)..."
  timeout 900 model_benchmark -i "$dir/" -l 128 -g 128 -r 3 -w 1 \
    -f "$PROMPT" -o "$RESULTS/${name}_l128g128.json" \
    >>"$LOG" 2>&1
  rc=$?
  if [ $rc -eq 0 ] && [ -f "$RESULTS/${name}_l128g128.json" ]; then
    # Extract key numbers for live log
    python3 -c "
import json
d = json.load(open('$RESULTS/${name}_l128g128.json'))
pp = d.get('prompt_processing', {}).get('avg_tokens_per_sec', 'n/a')
tg = d.get('token_generation', {}).get('avg_tokens_per_sec', 'n/a')
pk = d.get('peak_working_set_size_bytes', 0) / 1e9
print(f'  >> prefill={pp:.1f} t/s  decode={tg:.1f} t/s  peak={pk:.1f}GB')
" 2>/dev/null | tee -a "$LOG" || {
      # Fallback: scrape text log
      tail -40 "$LOG" | grep -E "tokens/s|Peak" | tail -4 | tee -a "$LOG"
    }
  else
    log "  BENCH FAILED (rc=$rc)"
  fi
done

log ""
log "=== All done ==="
log "Results: $RESULTS/"
