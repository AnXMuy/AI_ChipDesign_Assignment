# Python 仿真

`generate_golden.py` 生成确定性的 int8 输入、权重、int32 bias 和饱和 int8 输出，同时写入 NumPy 与 Verilog `$readmemh` 格式。默认参数对应课程规模；RTL 回归可用小尺寸参数快速完成：

```bash
python -m assignment1_fpga.sim.generate_golden --height 4 --width 5 --channels 2 --outputs 3 --out /tmp/conv_case
```

