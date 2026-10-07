# ModelSim 运行指南

这份文档按课程作业标准配置编写。仓库默认只使用 `baseline`，不需要额外的小规模配置。

## 一、准备环境

需要准备：

- ModelSim 或 QuestaSim，并确保 `vsim`、`vlib`、`vlog` 在终端中可用。
- Python 3.9 或更高版本。
- NumPy。安装命令：

```bash
python3 -m pip install numpy
```

进入仓库根目录后检查：

```bash
vsim -version
python3 --version
```

## 二、课程标准参数

| 参数 | 数值 |
|---|---:|
| 输入特征图 | `H=256, W=256, C=16` |
| 输出通道数 | `KN=32` |
| 卷积核 | `KH=3, KW=3, KC=16` |
| 步长 | `STRIDE=1` |
| 填充 | `PAD=1` |
| 输入/权重/输出 | 有符号 `int8` |
| 累加结果 | `32-bit` |
| 输出量化 | 饱和到 `[-128, 127]` |
| 随机种子 | `42` |

输出尺寸为 `OH=256, OW=256`。

## 三、生成输入和 Python 参考结果

在仓库根目录运行：

```bash
python3 python/gen_data.py --config baseline
python3 python/run_golden.py --config baseline
```

生成文件位于 `data/baseline/`：

- `input.bin`：`256×256×16` 的有符号 8-bit 输入特征图。
- `weight.bin`：`32×3×3×16` 的有符号 8-bit 卷积核。
- `expected.bin`：Python 参考输出，形状为 `256×256×32`。
- `expected_int32.bin`：Python 参考累加结果。
- `meta.json`：完整参数和数据布局说明。

## 四、在 ModelSim 中运行

### 方式 A：命令行运行

在仓库根目录执行：

```bash
vsim -c -do "do scripts/run_sim.tcl baseline"
```

脚本会完成：

1. 创建并清理 `work` 库。
2. 编译 `rtl/conv_top.v` 和本地 testbench。
3. 加载 `data/baseline/input.bin` 和 `data/baseline/weight.bin`。
4. 运行卷积计算。
5. 将 RTL 输出写入 `results/baseline/rtl_output.bin`。
6. 保存仿真日志。

### 方式 B：ModelSim GUI 运行

在仓库根目录打开 ModelSim：

```bash
vsim
```

在 Transcript 窗口逐行执行：

```tcl
vlib work
vlog -sv rtl/conv_top.v tb/tb_conv.v
vsim work.tb_conv
run -all
```

建议同时打开 Wave 窗口，加入以下信号：

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
run -all
```

如果 GUI 中使用的是仓库外的 testbench，请确保 testbench 使用相同的输入路径和输出路径：

```text
data/baseline/input.bin
data/baseline/weight.bin
results/baseline/rtl_output.bin
```

## 五、结果比对

ModelSim 运行完成后，执行：

```bash
python3 python/compare.py \
  --cfg baseline \
  --rtl results/baseline/rtl_output.bin
```

正确结果应满足：

```text
num_err: 0
err_rate: 0.0
max_abs_err: 0
```

比对结果位于：

```text
results/baseline/compare.txt
results/baseline/compare.csv
```

如果结果不一致，按下面顺序检查：

1. 输入和权重文件是否来自同一次 `gen_data.py` 执行。
2. 数据布局是否为 input=`H,W,C`、weight=`KN,KH,KW,KC`、output=`OH,OW,KN`。
3. 输入和权重是否按有符号 8-bit 读取。
4. padding 边界是否补零。
5. 累加是否使用有符号 32-bit。
6. 输出是否按 `[-128,127]` 饱和。
7. RTL 输出文件长度是否为 `256×256×32=2,097,152` 字节。

## 六、需要截取的截图

建议截图保存到你自己的报告目录，例如：

```text
report/figs/
```

需要准备以下截图：

### 图 1：工程文件与配置

截图内容应包含 ModelSim Project/Library 窗口，能看到：

- `conv_top`
- RTL 源文件
- testbench
- `work` library

建议文件名：

```text
01_modelsim_project.png
```

### 图 2：编译成功

Transcript 中显示 `vlog -sv` 编译完成，没有 Error。

建议文件名：

```text
02_compile_success.png
```

### 图 3：复位和启动波形

Wave 窗口显示：

- `clk`
- `rst_n`
- `start`
- `busy`
- `input_valid`
- `input_ready`
- `weight_valid`
- `weight_ready`

建议文件名：

```text
03_load_and_start_waveform.png
```

### 图 4：卷积计算和输出波形

Wave 窗口显示：

- `busy`
- `output_valid`
- `output_ready`
- `output_data`
- `done`

建议文件名：

```text
04_output_waveform.png
```

### 图 5：仿真完成

Transcript 中显示 testbench 完成、仿真结束或 `done` 被拉高。

建议文件名：

```text
05_simulation_done.png
```

### 图 6：Python 结果比对

终端中显示：

```text
num_err: 0
err_rate: 0.0
max_abs_err: 0
```

建议文件名：

```text
06_compare_pass.png
```

### 图 7：输出文件和元数据

文件管理器或终端中显示：

```text
data/baseline/meta.json
results/baseline/rtl_output.bin
results/baseline/compare.txt
results/baseline/compare.csv
```

建议文件名：

```text
07_result_files.png
```

## 七、运行日志和结果应放在哪里

建议最终整理为：

```text
report/
├── figs/
│   ├── 01_modelsim_project.png
│   ├── 02_compile_success.png
│   ├── 03_load_and_start_waveform.png
│   ├── 04_output_waveform.png
│   ├── 05_simulation_done.png
│   ├── 06_compare_pass.png
│   └── 07_result_files.png
├── sim.log
├── compare.txt
├── compare.csv
└── summary.csv
```

`report/` 不需要提交到开源代码仓库。它属于最终课程报告材料。

## 八、推荐执行顺序

```bash
python3 python/gen_data.py --config baseline
python3 python/run_golden.py --config baseline
vsim -c -do "do scripts/run_sim.tcl baseline"
python3 python/compare.py --cfg baseline --rtl results/baseline/rtl_output.bin
```

确认比对为零误码后，再截取截图并填写报告。
