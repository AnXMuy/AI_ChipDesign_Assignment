#!/usr/bin/env bash
set -euo pipefail
if ! command -v verilator >/dev/null 2>&1; then
  echo 'verilator is not installed; update the local conda environment.' >&2
  exit 2
fi
build_dir="${TMPDIR:-/tmp}/ai_chip_design_rtl"
mkdir -p "$build_dir"
case "${1:-small}" in
  small) H=4; W=5; C=2; KN=3; OUT="$build_dir/case" ;;
  course) H=256; W=256; C=16; KN=32; OUT="$build_dir/course" ;;
  *) echo 'usage: scripts/run_rtl_sim.sh [small|course]' >&2; exit 2 ;;
esac
"${PYTHON:-python}" -m assignment1_fpga.sim.generate_golden --height "$H" --width "$W" --channels "$C" --outputs "$KN" --out "$OUT"
cp "$OUT"/{input,weight,bias,golden}.hex "$build_dir"/
verilator --binary --timing --trace -Wno-fatal --top-module conv2d_stream_tb \
  -GH="$H" -GW="$W" -GC="$C" -GKN="$KN" --Mdir "$build_dir" \
  assignment2_rtl/rtl/conv2d_stream.sv assignment2_rtl/tb/conv2d_stream_tb.sv
(cd "$build_dir" && ./Vconv2d_stream_tb)
