#!/usr/bin/env bash
set -euo pipefail
CONFIG="${1:-small_smoke}"
python3 python/gen_data.py --config "$CONFIG"
python3 python/run_golden.py --config "$CONFIG"
vsim -c -do "do scripts/run_sim.tcl $CONFIG"
python3 python/compare.py --cfg "$CONFIG" --rtl "results/$CONFIG/rtl_output.bin"
