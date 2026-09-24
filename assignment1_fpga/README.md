# 作业一：Ultra96 FPGA 卷积加速

本目录对应 Ultra96 的 PS/PL 协同实现。`sim/` 使用共享 Python 参考模型产生 golden 输出；`ps/` 是 PYNQ 集成入口（尚未接入真实 overlay）；`pl/` 包含 Verilog MAC 模块及数据流约定。Vivado 工程和 bitstream 尚未生成，板端运行并未完成。

## 推荐数据通路

1. PS 通过 `pynq.allocate` 分配 contiguous buffer，写入 NHWC int8 输入和 HWIO int8 权重。
2. AXI DMA 将窗口数据送入 PL，PL 内部以 int32 累加并在输出端饱和到 int8。
3. PS 等待 DMA 完成，校验输出与 `common/python/conv_reference.py` 的 golden 文件一致。

`K_H/K_W/K_C/K_N`、stride、padding 和张量地址均应做成 AXI-Lite 寄存器或 Verilog 参数。课程规模下建议采用行缓存和输出通道分块，避免一次性片上存储完整特征图。

## 板端运行

```bash
python -m assignment1_fpga.sim.generate_golden --height 256 --width 256 --channels 16 --outputs 32
# 在 Vivado 中补齐滑窗/AXI 包装并生成 overlay，随后实现 PYNQ 端数据传输
```

实际报告请补充板卡型号、时钟频率、资源利用率、吞吐率、端到端延迟和功耗测量。
