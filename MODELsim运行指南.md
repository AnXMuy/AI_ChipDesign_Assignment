# ModelSim 图形界面实验指南

本文从工程打开、数据准备、编译、运行到结果保存逐步说明。RTL 结果由 `tb/tb_conv.v` 在仿真内部直接与 `expected.bin` 逐字节比较；最终判断看 Transcript 的 `TB_PASS`、误码数和错误数。波形颜色只表示信号值，不能单独证明计算结果正确。

## 1. 实验目标与标准参数

标准实验使用课程要求配置：输入 `256×256×16`，输出通道 `32`，卷积核 `3×3×16`，stride=1，padding=1；输入和输出为有符号 8-bit，中间累加为 32-bit。输出尺寸为 `256×256×32`。

需要验证的内容：

1. 输入、权重文件按预期数量完成握手。
2. RTL 输出数量等于 `OH×OW×KN`。
3. 每个 RTL 输出与 Python 生成的参考输出一致。
4. 仿真无超时，任务结束后 `busy=0` 并产生 `done`。
5. 参数实验改变配置后，输出几何或周期变化符合参数含义。
6. 并行配置的计算周期有实际变化，结果仍然正确。

## 2. 仓库准备

用 GitHub Desktop 克隆仓库，或在终端执行一次克隆。后续 ModelSim 操作全部通过 GUI 完成。安装 Python 3 和 NumPy 后，在系统文件管理器中打开仓库目录。

为运行标准配置，需要先生成数据文件。可用任意 Python IDE（如 IDLE、VS Code）打开并运行：

```text
python/gen_data.py
python/run_golden.py
```

两个脚本的启动参数分别设置为：

```text
--config baseline
--config baseline
```

生成目录 `data/baseline/`，其中应有：

- `input.bin`：输入特征图。
- `weight.bin`：卷积权重。
- `expected.bin`：参考 8-bit 输出，testbench 将直接读取此文件并比较。
- `expected_int32.bin`：参考累加值，供分析溢出/量化时查看。
- `meta.json`：配置、几何尺寸和数据布局。

创建目录 `results/baseline/`，用于保存 ModelSim 输出。

## 3. 在 ModelSim 中创建工程

1. 启动 ModelSim。
2. 选择 `File → Change Directory`，设置为仓库根目录。
3. 选择 `File → New → Project`，工程名可填 `AIChipAssignment`，工程位置选仓库根目录。
4. 选择 `Add Existing File`，加入：
   - `rtl/conv_top.v`
   - `tb/tb_conv.v`
5. 确认文件显示在 Project 窗口，Library 窗口能看到 `work`。
6. 建议将 Transcript、Project、Library、Wave 窗口都打开，便于截图。

## 4. 编译与启动标准实验

在 Transcript 输入：

```tcl
vlib work
vlog -sv rtl/conv_top.v tb/tb_conv.v
```

没有编译错误后，启动标准配置：

```tcl
vsim -voptargs=+acc work.tb_conv +CFG=baseline
```

`+acc` 用于保留内部信号，方便查看波形。添加波形信号：

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
add wave sim:/tb_conv/output_data
add wave sim:/tb_conv/busy
add wave sim:/tb_conv/done
add wave sim:/tb_conv/mismatch_count
add wave sim:/tb_conv/errors
```

点击 Wave 窗口工具栏的 Run-All 按钮，或在 Transcript 输入：

```tcl
run -all
```

标准配置数据量大，仿真会运行较长时间。不要因为波形长时间没有变化就提前中止。完成后 Transcript 应包含：

```text
TB_SUMMARY ... mismatches=0 errors=0
TB_PASS cfg=baseline
```

`TB_PASS` 是通过条件。`mismatches` 或 `errors` 非零、出现 `TB_FAIL`、`$fatal` 或超时信息，都表示本轮实验失败，需要排查。

## 5. testbench 怎样验证结果

Testbench 在仿真内完成以下工作：

- 读取输入和权重文件并驱动 `valid/ready`。
- 检查数据文件没有提前结束。
- 对每一个 `output_valid && output_ready` 周期，读取 `expected.bin` 的下一个字节。
- 将 RTL 输出与参考字节逐项比较，并累计 `mismatch_count`。
- 保存实际 RTL 输出到 `results/<配置名>/rtl_output.bin`。
- 统计输入、权重和输出数量。
- 检查超时、`done`、输出总数和结果误码。
- 输出首个错误位置和实际/期望值。

因此，正确性结论来自 testbench 的数值比较和 Transcript 状态。Wave 窗口的颜色不能代替数值比较。

## 6. 在 GUI 中运行其他参数配置

每次切换配置前：

1. 在 Python IDE 中运行 `gen_data.py` 和 `run_golden.py`，两者都传入相同配置名。
2. 在文件管理器中创建 `results/<配置名>/`。
3. 在 ModelSim Transcript 输入 `restart -f`。
4. 用下面命令重新加载 testbench，替换配置名。
5. 执行 `run -all`，记录 Transcript 并保存波形。

```tcl
vsim -voptargs=+acc work.tb_conv +CFG=配置名
run -all
```

推荐参数实验：

| 配置 | 改动 | 应观察的现象 |
|---|---|---|
| `stride2_pad0` | stride=2、padding=0 | `OH/OW` 变为 127×127 |
| `kernel1` | kernel=1×1 | `OH/OW` 变为 258×258 |
| `kernel5` | kernel=5×5 | `OH/OW` 变为 254×254 |
| `height64` | 输入高度=64 | 输出高度随之变化 |
| `width64` | 输入宽度=64 | 输出宽度随之变化 |
| `input_channels8` | 输入通道=8 | 输入、权重文件大小变化 |
| `output_channels16` | 输出通道=16 | 输出数量减半 |
| `acc24` | 累加位宽=24 | 检查低位截断/溢出表现 |
| `truncate_quant` | 输出低 8 位截断 | 与饱和模式比较输出值 |

参数变化必须同时反映在 `meta.json`、输入/权重/参考输出尺寸和 testbench 配置中。当前配置由 `python/config.py` 与 `tb/tb_conv.v` 成对定义；改配置时两处名称和数值必须一致。

## 7. 并行度实验：固定条件、比较周期

四组实验保持输入、权重、kernel、stride、padding、输出尺寸一致，只改变输出通道并行度；`P_KH=P_KW=P_C=1`。配置如下：

| 名称 | `P_KN` | 其余并行度 | 理论 MAC 组数比例 |
|---|---:|---|---:|
| `parallel_2x` | 2 | 1,1,1 | 16 倍基准组数 |
| `parallel_4x` | 4 | 1,1,1 | 8 倍基准组数 |
| `parallel_8x` | 8 | 1,1,1 | 4 倍基准组数 |
| `parallel_16x` | 16 | 1,1,1 | 2 倍基准组数 |

理论 MAC 组数以 32 个输出通道全部串行为参照。整体仿真周期还包含加载和输出时间，所以实际加速比会低于理论 MAC 计算加速比。

每组分别在 Python IDE 生成数据，在 ModelSim Transcript 运行：

```tcl
restart -f
vsim -voptargs=+acc work.tb_conv +CFG=parallel_2x
run -all
```

其他三组把 `parallel_2x` 替换为 `parallel_4x`、`parallel_8x`、`parallel_16x`。每次运行前均需为对应配置生成数据并创建同名结果目录。

记录每组 Transcript 的：

- `cycles`
- `mismatches`
- `errors`
- `TB_PASS/TB_FAIL`

计算：

```text
实测加速比 = baseline 的 cycles ÷ 当前并行配置的 cycles
```

仅当四组结果都 `TB_PASS` 且误码为零，才纳入速度比较。若周期没有随 `P_KN` 增加而下降，先检查 testbench 是否选择了正确配置、并行参数是否进入 DUT、周期起止点是否一致。

## 8. 结果和截图保存

在仓库根目录建立：

```text
report/
├── figures/
├── logs/
└── tables/
```

至少保存这些文件：

- `figures/01_project_and_compile.png`：工程文件和编译成功信息。
- `figures/02_baseline_waveform.png`：标准配置的复位、加载、输出、done 波形。
- `figures/03_baseline_pass.png`：Transcript 的 `TB_SUMMARY` 与 `TB_PASS`。
- `figures/04_parallel_2x.png`、`05_parallel_4x.png`、`06_parallel_8x.png`、`07_parallel_16x.png`：每组的关键波形与 Transcript 周期。
- `logs/<配置名>_transcript.txt`：Transcript 全部内容。可在 Transcript 窗口右键保存，或使用 `File → Export`。
- `tables/实验记录.csv`：按报告模板填写参数、输出尺寸、周期、误码和截图文件名。
- `data/<配置名>/meta.json` 和 `results/<配置名>/rtl_output.bin`：保留数据与实际输出，便于复核。

不要只保存波形截图。Transcript 的 `TB_PASS`、误码统计和周期数据是报告结论的直接依据。
