# 作业二：RTL 仿真卷积算子

`rtl/conv2d_stream.sv` 是可综合的窗口级 MAC 引擎：每个输入 beat 携带一个 feature/weight 对，`window_last` 标记窗口结束，内部使用 32-bit 累加并输出饱和 int8。上层 line buffer、滑窗地址生成和 DMA 可独立替换。

```bash
make sim
```

课程规模 `(256,256,16)->(256,256,32)` 不建议直接在 testbench 中展开全部数据；testbench 应使用同一组确定性输入文件，并逐像素比对 Python golden 输出。
