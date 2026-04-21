# Source this before running hybrid LLM workloads.
# Usage: source ~/run_llm/env.sh

source /opt/xilinx/xrt/setup.sh >/dev/null
source ~/ryzen_ai/venv/bin/activate

export RYZEN_AI_INSTALLATION_PATH="${VIRTUAL_ENV}"
export LD_LIBRARY_PATH="/lib/x86_64-linux-gnu:${RYZEN_AI_INSTALLATION_PATH}/deployment/lib:${LD_LIBRARY_PATH}"
export RYZENAI_EP_PATH="${RYZEN_AI_INSTALLATION_PATH}/deployment/lib/libonnxruntime_providers_ryzenai.so"
export PATH="${RYZEN_AI_INSTALLATION_PATH}/LLM/examples:${PATH}"

# xrt.ini tuning for LLM workloads
cat > "${HOME}/run_llm/xrt.ini" <<'EOF'
[Debug]
num_heap_pages = 8
EOF
export XRT_INI_PATH="${HOME}/run_llm/xrt.ini"

echo "Ryzen AI env ready. RYZEN_AI_INSTALLATION_PATH=${RYZEN_AI_INSTALLATION_PATH}"
