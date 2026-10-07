# ModelSim 图形界面实验指南

这份指南只讲 ModelSim 图形界面操作。实验结果由 `tb/tb_conv.v` 在仿真内部直接完成校验：testbench 会读取 Python 生成的 `expected.bin`，把每个 RTL 输出与参考值逐项比较，并在 Transcript 中输出 `TB_PASS` 或 `TB_FAIL`。你不需要再单独运行结果比对程序来判断波形是否正确。

## 1. 实验目录

从 GitHub 克隆仓库后，在仓库根目录可以看到：

```text
python/                 数据和参考模型
rtl/                    卷积 RTL
 tb/                     自检型 testbench
scripts/run_sim.tcl     ModelSim GUI 初始化脚本
MODELsim运行指南.md     本文档
报告撰写指南.md         报告填写说明
REPORT_TEMPLATE.md      报告模板
```

## 2. 只做一次的准备工作

### 2.1 生成标准配置数据

打开系统终端，进入仓库根目录，执行 Python 数据生成命令：

```bash
python3 python/gen_data.py --config baseline
python3 python/run_golden.py --config baseline
```

这两条命令只负责生成输入、权重和参考输出。真正的正确性判断在 ModelSim 的 testbench 内完成。

生成后应存在：

```text
data/baseline/input.bin
data/baseline/weight.bin
data/baseline/expected.bin
data/baseline/expected_int32.bin
data/baseline/meta.json
```

### 2.2 创建结果目录

在仓库根目录创建：

```text
results/baseline/
```

testbench 会把 RTL 输出写入：

```text
results/baseline/rtl_output.bin
```

## 3. 使用 ModelSim GUI 建立工程

1. 打开 ModelSim。
2. 选择 `File → Change Directory`。
3. 把工作目录切换到仓库根目录。
4. 选择 `File → New → Project`。
5. 工程名填写 `AIChipDesignAssignment`。
6. 工程位置选择仓库根目录。
7. 将下面文件加入工程：

```text
rtl/conv_top.v
tb/tb_conv.v
```

8. 确认 Library 窗口中存在 `work`。
9. 确认 Project 窗口中出现 `conv_top.v` 和 `tb_conv.v`。

## 4. 编译

在 ModelSim 底部 Transcript 窗口输入：

```tcl
vlib work
vlog -sv rtl/conv_top.v tb/tb_conv.v
```

编译成功的判断：

- Transcript 没有 `Error`。
- Library → `work` 中出现 `conv_top` 和 `tb_conv`。
- Project 窗口中的源文件没有红色错误标志。

截图保存为：

```text
report/figs/01_编译成功.png
```

## 5. 运行标准配置

在 Transcript 输入：

```tcl
vsim -voptargs=+acc work.tb_conv +CFG=baseline
```

添加波形：

```tcl
add wave sim:/tb_conv/clk
add wave sim:/tb_conv/rst_n
add wave sim:/tb_conv/start
add wave sim:/tb_conv/input_valid
add wave sim:/tb_conv/input_ready
add wave sim:/tb_conv/weight_valid
add wave sim:/tb_conv/weight_ready
add wave sim:/tb_conv/output_valid
add wave sim:/tb_conv/output_ready
add wave sim:/tb_conv/busy
add wave sim:/tb_conv/done
add wave sim:/tb_conv/output_data
```

点击 GUI 的绿色运行按钮，或在 Transcript 输入：

```tcl
run -all
```

testbench 完成后，Transcript 应出现类似内容：

```text
TB_SUMMARY cfg=baseline input=.../... weight=.../... output=.../... cycles=... mismatches=0 errors=0
TB_PASS cfg=baseline
```

判断标准只有一组：

```text
mismatches=0
errors=0
TB_PASS
```

`TB_PASS` 表示输入数量、权重数量、输出数量、超时状态和逐元素参考结果都通过。

截图保存为：

```text
report/figs/02_标准配置通过.png
```

## 6. 如何看波形

### 6.1 复位和启动

重点查看：

- `rst_n` 先为低，随后拉高。
- `start` 出现一个时钟周期的高电平。
- `busy` 在任务开始后拉高。

截图保存为：

```text
report/figs/03_复位启动波形.png
```

### 6.2 输入和权重加载

重点查看：

- `input_valid` 和 `input_ready` 同时有效时接收输入。
- 输入加载结束后进入权重加载阶段。
- `weight_valid` 和 `weight_ready` 同时有效时接收权重。

截图保存为：

```text
report/figs/04_输入权重加载波形.png
```

### 6.3 输出和完成

重点查看：

- `output_valid` 拉高后输出有效。
- `output_ready` 保持高电平，输出可以连续被接收。
- `done` 在全部输出完成后拉高。
- `busy` 在任务结束后拉低。

截图保存为：

```text
report/figs/05_输出完成波形.png
```

## 7. 参数实验

每组参数实验都遵循同一个流程：

1. 在系统终端生成对应配置的 `input.bin`、`weight.bin` 和 `expected.bin`。
2. 在 ModelSim GUI 中重新编译。
3. 通过 `+CFG=配置名` 启动 testbench。
4. 观察 Transcript 中的 `TB_PASS`。
5. 保存配置对应的波形和 Transcript 截图。

### 7.1 步长和填充

终端生成数据：

```bash
python3 python/gen_data.py --config stride2_pad0
python3 python/run_golden.py --config stride2_pad0
```

ModelSim Transcript：

```tcl
vsim -voptargs=+acc work.tb_conv +CFG=stride2_pad0
run -all
```

记录 `meta.json` 中的 `OH`、`OW`，并确认 Transcript 为 `TB_PASS`。

### 7.2 卷积核尺寸

分别生成并运行：

```text
kernel1
kernel5
```

它们对应 `1×1` 和 `5×5` 卷积核。每次启动 ModelSim 时使用对应的 `+CFG`。

### 7.3 输入和输出尺寸参数

分别使用：

```text
height64
width64
input_channels8
output_channels16
```

这些实验验证输入高度、输入宽度、输入通道数和输出通道数都能改变，并且 testbench 会按实际输出数量检查结果。

### 7.4 累加位宽和量化模式

使用：

```text
acc24
truncate_quant
```

`acc24` 验证累加位宽变化；`truncate_quant` 验证输出量化模式变化。两组实验都必须观察 `TB_PASS`，并在报告中说明输出差异。

## 8. 并行实验

并行实验只改变并行配置，输入特征图、卷积核和输出尺寸保持课程标准配置。这样周期差异可以归因于并行参数。

| 配置名 | 输出通道并行度 | 输入通道并行度 | 卷积核高并行度 | 卷积核宽并行度 |
|---|---:|---:|---:|---:|
| `parallel_2x` | 2 | 1 | 1 | 1 |
| `parallel_4x` | 4 | 1 | 1 | 1 |
| `parallel_8x` | 8 | 1 | 1 | 1 |
| `parallel_16x` | 16 | 1 | 1 | 1 |

对每个配置分别执行：

```bash
python3 python/gen_data.py --config parallel_2x
python3 python/run_golden.py --config parallel_2x
```

然后在 ModelSim GUI 的 Transcript 中：

```tcl
vsim -voptargs=+acc work.tb_conv +CFG=parallel_2x
run -all
```

四组实验重复相同操作，只替换配置名。

每组都要记录：

- `TB_PASS` 是否出现。
- `mismatches` 是否为 0。
- `errors` 是否为 0。
- Transcript 中的 `cycles`。
- `busy` 持续时间。
- 输出波形的开始和结束位置。

截图文件名建议：

```text
report/figs/06_2倍并行.png
report/figs/07_4倍并行.png
report/figs/08_8倍并行.png
report/figs/09_16倍并行.png
```

加速比按下面公式计算：

```text
加速比 = baseline 周期数 ÷ 当前并行配置周期数
```

报告中必须填写实际周期。理论上并行度提高会缩短计算阶段，但输入加载、权重加载和输出写回仍然占用时间，因此实际加速比不一定等于并行倍数。

## 9. GUI 截图清单

最终至少准备：

```text
01_编译成功.png
02_标准配置通过.png
03_复位启动波形.png
04_输入权重加载波形.png
05_输出完成波形.png
06_2倍并行.png
07_4倍并行.png
08_8倍并行.png
09_16倍并行.png
```

所有截图放入：

```text
report/figs/
```

## 10. Testbench 自检说明

`tb/tb_conv.v` 内部已经完成以下验证：

- 输入文件读取数量检查。
- 权重文件读取数量检查。
- 输出数量检查。
- 输出顺序检查。
- RTL 输出与 `expected.bin` 逐元素比较。
- 首个错误位置、实际值和期望值记录。
- 仿真超时检查。
- `done` 信号检查。
- `busy` 结束状态检查。
- `TB_PASS/TB_FAIL` 总结。

因此，ModelSim Transcript 中的 `TB_PASS` 是本实验的主要验收结果。Python 生成 `expected.bin` 只负责提供参考数据，逐元素验证在 testbench 内完成。
