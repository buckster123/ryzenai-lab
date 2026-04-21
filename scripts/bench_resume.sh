#!/bin/bash
# Resume suite — download remaining + bench, with rate-limit-aware sleeps.
set -u
source /opt/xilinx/xrt/setup.sh >/dev/null 2>&1
source ~/ryzen_ai/venv/bin/activate
export RYZEN_AI_INSTALLATION_PATH="${VIRTUAL_ENV}"
export LD_LIBRARY_PATH="/lib/x86_64-linux-gnu:${RYZEN_AI_INSTALLATION_PATH}/deployment/lib:${LD_LIBRARY_PATH:-}"
export RYZENAI_EP_PATH="${RYZEN_AI_INSTALLATION_PATH}/deployment/lib/libonnxruntime_providers_ryzenai.so"
export XRT_INI_PATH="${HOME}/run_llm/xrt.ini"
export PATH="${RYZEN_AI_INSTALLATION_PATH}/LLM/examples:${PATH}"
export HF_HUB_ENABLE_HF_TRANSFER=1

PROMPT=~/ryzen_ai/venv/LLM/examples/amd_genai_prompt.txt
RESULTS=~/run_llm/results
LOG=~/run_llm/results/bench_resume.log
mkdir -p "$RESULTS"
: > "$LOG"

# Every model we still want (gemma-3 already downloaded, just needs bench)
# Omitted: LFM2 (different format, ONNX not OGA), needs separate runner
REMAINING=(
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

bench() {
  local dir="$1"; local name="$2"
  log "  Benching $name..."
  timeout 900 model_benchmark -i "$dir/" -l 128 -g 128 -r 3 -w 1 \
    -f "$PROMPT" -o "$RESULTS/${name}_l128g128.json" >>"$LOG" 2>&1
  local rc=$?
  if [ $rc -eq 0 ] && [ -f "$RESULTS/${name}_l128g128.json" ]; then
    python3 -c "
import json
d=json.load(open('$RESULTS/${name}_l128g128.json'))
pl=d.get('prompt_lengths',{}).get('128',{})
ttft=pl.get('avg_ttft_seconds',0)
prefill=128/ttft if ttft else 0
decode=pl.get('avg_tokens_per_second',0)
peak=d.get('overall_peak_memory_gb',0)
print(f'  >> prefill={prefill:.1f} t/s  decode={decode:.2f} t/s  peak={peak:.2f}GB')
" 2>&1 | tee -a "$LOG"
  else
    log "  BENCH FAILED (rc=$rc) — check log for '$name'"
  fi
}

for full in "${REMAINING[@]}"; do
  name="${full##*/}"
  dir="$HOME/run_llm/$name"
  log "=== $name ==="

  if [ -f "$dir/genai_config.json" ]; then
    log "  Already downloaded"
  else
    # Retry download up to 3x with backoff — 5 min sleeps match HF's 5-min window
    for attempt in 1 2 3; do
      log "  Download attempt $attempt..."
      if hf download "$full" --local-dir "$dir" >>"$LOG" 2>&1; then
        log "  Download OK"
        break
      fi
      log "  Attempt $attempt failed — sleeping 6 min to reset rate limit"
      sleep 360
    done
    if [ ! -f "$dir/genai_config.json" ]; then
      log "  DOWNLOAD FAILED after 3 attempts — skipping"
      continue
    fi
  fi

  sz=$(du -sh "$dir" | awk '{print $1}')
  log "  Size: $sz"
  bench "$dir" "$name"

  # 30s breather between models so sequential downloads don't pile up API calls
  sleep 30
done

log ""
log "=== Resume complete ==="
