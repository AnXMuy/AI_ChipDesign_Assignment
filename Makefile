.PHONY: help test sim lint report

help:
	@printf '%s\n' 'Targets:' '  test    Run Python reference-model tests' '  sim     Run the Verilator RTL smoke simulation' '  lint    Check Python sources' '  report  Build the three LaTeX reports with Tectonic'

test:
	python -m pytest -q

sim:
	bash scripts/run_rtl_sim.sh

lint:
	python -m compileall -q common assignment1_fpga assignment2_rtl

report:
	@mkdir -p build/reports .tectonic-cache
	@for d in assignment1_fpga assignment2_rtl assignment3_survey; do \
		mkdir -p build/reports/$$d; \
		(cd $$d/report && TECTONIC_CACHE_DIR="$(CURDIR)/.tectonic-cache" tectonic --outdir ../../build/reports/$$d main.tex) || exit 1; \
	done
