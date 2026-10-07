# AI Chip Design Assignment

A configurable 8-bit convolution RTL accelerator with a Python reference model.

## Included

- `python/`: deterministic data generation, integer reference convolution, comparison and experiment scripts.
- `rtl/`: synthesizable SystemVerilog top-level convolution data path.
- `scripts/`: ModelSim command-line entry point.
- `data/`: generated binary input and weight files are created locally by the Python scripts.

The testbench and report materials are intentionally kept out of the public source repository. The testbench is run in a local ModelSim workspace against the checked-in RTL and generated data.

## Quick start

```bash
python3 python/gen_data.py --config small_smoke
python3 python/run_golden.py --config small_smoke
```

Run ModelSim from the project root:

```bash
vsim -c -do "do scripts/run_sim.tcl small_smoke"
```

The local testbench should write `results/small_smoke/rtl_output.bin`. Compare it with the Python result:

```bash
python3 python/compare.py \
  --cfg small_smoke \
  --rtl results/small_smoke/rtl_output.bin
```

## Configurations

`python/config.py` contains `baseline`, `small_smoke`, and parameter variation experiments. The course baseline is 256×256×16 input, 32 output channels, a 3×3×16 kernel, stride 1, padding 1, signed int8 input/weight/output, and 32-bit signed accumulation.

The RTL uses SystemVerilog constructs and must be compiled with `vlog -sv`.
