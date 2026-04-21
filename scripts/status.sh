#!/bin/bash
# Live status of the bench sweep
cd ~/run_llm
echo "=== BENCH STATUS ==="
echo ""
echo "--- Completed benchmarks ---"
python3 <<'EOF'
import json, glob, os
from pathlib import Path
jsons = sorted(glob.glob(os.path.expanduser("~/run_llm/results/*_l128g128.json")))
print(f"{'MODEL':<42} {'PREFILL':>10} {'DECODE':>10} {'PEAK':>7} {'INIT':>6}")
print("-"*80)
for j in jsons:
    d = json.load(open(j))
    name = Path(j).stem.replace("_rai_1.7.1_npu_4K_l128g128","").replace("_rai_1.7.1_l128g128","")
    pl = d.get("prompt_lengths",{}).get("128",{})
    ttft = pl.get("avg_ttft_seconds", 0)
    prefill = 128/ttft if ttft else 0
    decode = pl.get("avg_tokens_per_second", 0)
    peak = d.get("overall_peak_memory_gb", 0)
    init = d.get("initialization_time_seconds", 0)
    print(f"{name:<42} {prefill:>9.1f}  {decode:>9.2f}  {peak:>5.1f}G  {init:>4.1f}s")
print(f"\nTotal: {len(jsons)} models benched")
EOF
echo ""
echo "--- Disk usage ---"
du -sh ~/run_llm/*_rai_1.7.1* 2>/dev/null | sort -h | tail -15
echo ""
echo "--- Current activity ---"
tail -3 ~/run_llm/results/bench_resume.log 2>/dev/null
