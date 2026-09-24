#!/usr/bin/env bash
set -euo pipefail
if ! command -v verilator >/dev/null 2>&1; then
  echo 'verilator is not installed; update the local conda environment.' >&2
  exit 2
fi
build_dir="${TMPDIR:-/tmp}/ai_chip_design_rtl"
mkdir -p "$build_dir"
verilator --binary --timing --trace -Wno-fatal --top-module conv2d_stream_tb \
  --Mdir "$build_dir" assignment2_rtl/rtl/conv2d_stream.sv assignment2_rtl/tb/conv2d_stream_tb.sv
(cd "$build_dir" && ./Vconv2d_stream_tb)
