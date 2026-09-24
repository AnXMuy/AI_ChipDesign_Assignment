# 作业二：RTL 仿真卷积算子

`rtl/conv2d_stream.sv` 是可综合的完整参数化卷积控制器：加载 NHWC 输入、HWIO 权重和 bias 后，按 stride/padding 扫描所有输出像素与通道，使用 32-bit 累加并输出饱和 int8。上层 line buffer、DMA 和板卡寄存器仍属于作业一硬件集成层。

```bash
make sim                 # small complete image regression
bash scripts/run_rtl_sim.sh course  # course dimensions; computationally expensive
```

testbench 通过 `$readmemh` 加载同一组确定性输入、权重、bias 和 Python golden 输出，逐元素比对输出地址。小回归覆盖完整加载、padding、stride、累加和 int8 饱和；`course` 模式使用课程默认尺寸。
