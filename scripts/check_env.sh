#!/usr/bin/env bash
set -euo pipefail
python - <<'PY'
import numpy
print('Python/Numpy OK:', numpy.__version__)
PY
command -v verilator >/dev/null && echo 'Verilator: OK' || echo 'Verilator: missing (RTL simulation unavailable)'
command -v tectonic >/dev/null && echo 'Tectonic: OK' || echo 'Tectonic: missing (report build unavailable)'
