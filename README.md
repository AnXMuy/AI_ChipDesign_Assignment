# 人工智能芯片导论：可配置 8-bit 卷积加速器

使用 SystemVerilog 实现可综合卷积硬件，以 Python 整数参考、Icarus Verilog 自校验仿真、GTKWave 波形及 Yosys 结构检查验证。主实验输入为 **256×256×16**，卷积核为 **32×3×3×16**，输出为 **256×256×32**；输入、权重和输出均为有符号 int8，乘积为 16-bit，累加为有符号 int32。

仓库包含实验代码和精简的实际运行结果。实验报告、截图、LaTeX 模板及课程作业要求仅在本地保留，不纳入版本管理。

## 阅读顺序与源文件职责

建议先看本页的运行方法和结果导航，再阅读 RTL 接口说明、硬件和测试平台，最后查看 Python 驱动及机器结果。

| 文件 | 作用 |
|---|---|
| [README.md](README.md) | 环境、命令、文件职责和实际结果入口 |
| [.gitignore](.gitignore) | 排除工具环境、生成数据、报告、截图、模板和课程要求；精简结果按文件显式加入版本管理 |
| [environment.yml](environment.yml) | 跨平台 conda 环境和科学计算依赖 |
| [conda-osx-arm64.lock.txt](conda-osx-arm64.lock.txt) | 本次 macOS arm64 实验环境的精确 conda 包清单 |
| [requirements-lock.txt](requirements-lock.txt) | conda 环境内通过 pip 安装的 Ruff、YoWASP/Yosys 等补充依赖版本 |
| [pyproject.toml](pyproject.toml) | Python 3.11、80 字符行宽、导入排序及 Ruff 检查与格式规则 |
| [conv_sim/rtl/conv.sv](conv_sim/rtl/conv.sv) | 参数化状态机、地址生成、分组并行乘累加、饱和量化与独热写回 |
| [conv_sim/rtl/README.md](conv_sim/rtl/README.md) | RTL 参数、通道打包布局、同步读接口、启动/完成时序和周期公式 |
| [conv_sim/tb/tb_conv.sv](conv_sim/tb/tb_conv.sv) | 同步内存、参考装载、int8/int32 双重检查、协议检查、重复任务、结果和 VCD 导出 |
| [conv_sim/python/experiment.py](conv_sim/python/experiment.py) | 固定种子数据生成、向量/标量参考、参数集、编译仿真、输出比较及 JSON 汇总 |
| [conv_sim/python/figures.py](conv_sim/python/figures.py) | 汇集已有结果和真实 VCD，生成结果表；本地绘制数值比较图和性能图，不绘制信号波形 |
| [conv_sim/scripts/install_tools.py](conv_sim/scripts/install_tools.py) | 在 conda 前缀内从固定发布源码构建 Icarus 和 GTKWave，记录源码 SHA-256 |
| [conv_sim/scripts/validate.py](conv_sim/scripts/validate.py) | 无复位重启、参考故障注入和 1/4/16 路 Yosys 结构与资源检查 |
| [conv_sim/wave.gtkw](conv_sim/wave.gtkw) | 综合信号视图，默认显示启动附近时间窗 |
| [conv_sim/wave_start.gtkw](conv_sim/wave_start.gtkw) | 启动、复位和同步读时序视图 |
| [conv_sim/wave_mac.gtkw](conv_sim/wave_mac.gtkw) | 核坐标遍历、通道分组与累加视图 |
| [conv_sim/wave_write.gtkw](conv_sim/wave_write.gtkw) | 前三次输出写回、地址、独热码与量化值视图 |
| [conv_sim/wave_done.gtkw](conv_sim/wave_done.gtkw) | 最后写回和完成采样视图 |

## 已提交结果导航

以下是精简的实际运行记录，数据来自已完成实验。保留 JSON、文本日志和一个小规模真实波形；大体积输入/权重/参考数据、输出十六进制文件、编译产物及临时网表由运行脚本重新生成。

| 结果文件或命名规则 | 内容与用途 |
|---|---|
| [results/summary.json](results/summary.json) | 17 项快速实验和 1 项完整尺寸实验的统一指标，包括配置、周期、误差、耗时、输出摘要和相对串行加速比 |
| [results/environment.json](results/environment.json) | Python、NumPy、操作系统及 Icarus/GTKWave 等实际环境信息 |
| `results/<case>/data/metadata.json` | 该配置的参数、种子、输入范围、累加范围、正负饱和数量，以及生成数据文件的 SHA-256 |
| `results/<case>/lanes<L>/metrics.json` | 单个并行配置的 Python 综合指标：TB 计数、Python 输出比较、编译/仿真耗时、输出 SHA-256；周期加速比在总汇中计算 |
| `results/<case>/lanes<L>/tb_metrics.json` | 测试平台直接输出的最后一项任务周期、理论周期、输出数量、错误数、重复次数、并行度和时钟周期 |
| `results/<case>/lanes<L>/compile.log` | Icarus 编译输出；成功时仍可能包含工具警告 |
| `results/<case>/lanes<L>/simulation.log` | 每次任务的周期、输出数量、`errors=0`、`PASS` 与仿真结束信息 |
| [results/evidence/results_table.md](results/evidence/results_table.md) | 汇总 JSON 的便于阅读的表格版本 |
| [results/evidence/summary.json](results/evidence/summary.json) | 汇总时复制的统一实验指标 |
| [results/evidence/environment.json](results/evidence/environment.json) | 汇总时复制的环境信息 |
| [results/evidence/toolchain_sources.json](results/evidence/toolchain_sources.json) | Icarus/GTKWave 固定源码版本及下载归档 SHA-256 |
| `results/evidence/<case>_data.json` | 对应 `<case>/data/metadata.json` 的便于集中阅读的副本 |
| `results/evidence/<case>_lanes<L>.log` | 对应 `simulation.log` 的集中副本，文件名同时标识配置和并行度 |
| [results/evidence/wave.vcd](results/evidence/wave.vcd) | `small`、16 路并行的真实仿真波形，保留启动附近及任务结束附近，供 GTKWave 查看 |
| [results/validation/restart.json](results/validation/restart.json) | 1/4/16 路不复位连续启动两次的配置与指标 |
| [results/validation/restart.log](results/validation/restart.log) | 无复位重启实验的逐次仿真输出 |
| `results/validation/restart_compile_lanes1.log`、`restart_compile_lanes4.log`、`restart_compile_lanes16.log` | 三种并行度的重启实验编译输出 |
| [results/validation/fault_injection.json](results/validation/fault_injection.json) | 翻转首个参考输出 1 位后的检测结论及预期非零退出码 |
| [results/validation/fault_injection.log](results/validation/fault_injection.log) | 故障注入产生的数据不匹配和 `FAIL`；此处失败表示检测机制按预期工作 |
| [results/validation/synthesis_summary.json](results/validation/synthesis_summary.json) | 1/4/16 路数据乘法器、全部乘法器、加法器、触发器与通用单元数量及结构检查结果 |
| `results/validation/synthesis_lanes1.log`、`synthesis_lanes4.log`、`synthesis_lanes16.log` | 每种并行度的 Yosys 展开、优化、`check` 和 `stat` 原始记录 |
| [results/validation/validation_versions.json](results/validation/validation_versions.json) | 验证使用的 Icarus、vvp 和 Yosys 完整版本输出 |

其中 `<case>` 的取值和验证目的如下；同一配置的各并行度共享同一份数据。

| case | 验证目的 | 已保存 LANES |
|---|---|---|
| `small` | 8×8×16 输入、32 输出通道，建立串并行对照 | 1、4、16 |
| `rectangular` | 7×11×5 矩形输入、尾组屏蔽及并行度超过输入通道数 | 1、4、8 |
| `pointwise` | 1×1 最小核及不满一组的通道 | 1、4 |
| `stride2` | 步长 2、输出尺寸取整与通道尾组 | 1、4 |
| `kernel5` | 5×5 核与填充 2 | 1、4 |
| `valid` | 2×3 非方形有效卷积、填充 0、右移 4 位 | 1、4 |
| `quantization` | 正权重下的负奇数算术右移与正负饱和 | 1、4 |
| `negative_saturation` | 负权重与反向饱和边界 | 1 |
| `full` | 256×256×16 输入、32 输出通道的全量验证 | 16 |

## 实测基准

17 项快速实验各执行两次，两次之间复位；完整尺寸执行一次。下表周期与输出数量均为单次任务值，错误数包含 TB 的 int8/int32 比较，Python 最终输出比较也全部为零。墙钟耗时是配置所含全部任务的主机执行时间，不等同于硬件周期加速。

| case | LANES | 单次输出值数 | 单次周期 | 任务次数 | 错误数 | 最大 int8 误差 |
|---|---:|---:|---:|---:|---:|---:|
| small | 1 | 2,048 | 333,825 | 2 | 0 | 0 |
| small | 4 | 2,048 | 112,641 | 2 | 0 | 0 |
| small | 16 | 2,048 | 57,345 | 2 | 0 | 0 |
| rectangular | 1 | 539 | 34,497 | 2 | 0 | 0 |
| rectangular | 4 | 539 | 19,944 | 2 | 0 | 0 |
| rectangular | 8 | 539 | 15,093 | 2 | 0 | 0 |
| pointwise | 1 | 225 | 1,351 | 2 | 0 | 0 |
| pointwise | 4 | 225 | 901 | 2 | 0 | 0 |
| stride2 | 1 | 270 | 22,141 | 2 | 0 | 0 |
| stride2 | 4 | 270 | 9,991 | 2 | 0 | 0 |
| kernel5 | 1 | 192 | 24,193 | 2 | 0 | 0 |
| kernel5 | 4 | 192 | 14,593 | 2 | 0 | 0 |
| valid | 1 | 144 | 6,193 | 2 | 0 | 0 |
| valid | 4 | 144 | 3,601 | 2 | 0 | 0 |
| quantization | 1 | 8 | 33 | 2 | 0 | 0 |
| quantization | 4 | 8 | 33 | 2 | 0 | 0 |
| negative_saturation | 1 | 8 | 33 | 2 | 0 | 0 |
| full | 16 | 2,097,152 | 58,720,257 | 1 | 0 | 0 |

完整尺寸共验证 **2,097,152** 个 int8 输出与对应 int32 原始累加，执行 **301,989,888** 次 MAC，耗时 **58,720,257** 周期；10 ns 时钟下的模拟时间为 **587.20257 ms**，主机仿真墙钟耗时约 **538.764 s**。

相同 `small` 任务的 1/4/16 路周期为 333,825 / 112,641 / 57,345，对应周期加速 1.000 / 2.964 / **5.821**。综合后有符号 8×8 数据乘法器分别为 1/4/16，结构检查均为零问题；统计为通用 RTL 单元，不代表特定 FPGA/ASIC 的面积或最高频率。

无复位重启实验在 1/4/16 路下均连续完成两次任务，每次 8 个输出、513/297/225 周期、错误数零。故障注入在两次任务中均检测到首个 int8 不匹配，错误数 2、退出码 1，符合“必须检测并失败”的预期。

## 环境配置

macOS 需 Xcode Command Line Tools，Linux 需 C/C++ 编译器。先创建并激活 conda 环境，再安装补充依赖和仿真工具：

```bash
conda env create -f environment.yml
conda activate aichip
python -m pip install -r requirements-lock.txt
python conv_sim/scripts/install_tools.py
iverilog -V
gtkwave --version
```

`install_tools.py` 将 Icarus **12.0** 和 GTKWave **3.3.116** 从固定发布源码构建至 `$CONDA_PREFIX`。源码与构建日志保存在本地 `conv_sim/.build/`，来源摘要位于 `$CONDA_PREFIX/toolchain-sources.json`。GTKWave 使用 GTK3；macOS 使用 Quartz 后端，关闭 X11 窗口嵌入与 TwinWave。源码版本和精确环境清单用于复现实验工具链。

本次运行使用项目内前缀，创建环境时也可使用 `conda env create --prefix ./.conda-env -f environment.yml`，之后以 `conda activate ./.conda-env` 激活。

## 运行与重新生成结果

在仓库根目录、激活环境后执行：

```bash
# 17 个配置与并行度组合，每组默认运行两次。
python conv_sim/python/experiment.py --suite quick

# 完整尺寸，核对全部输出及量化前累加。
python conv_sim/python/experiment.py --suite full

# 无复位连续重启、参考错误注入、综合结构与乘法器计数。
python conv_sim/scripts/validate.py

# 汇集 JSON/日志和真实 VCD、更新结果表，绘制本地数值与性能图。
python conv_sim/python/figures.py

# 静态与格式检查。
ruff check conv_sim/python conv_sim/scripts
ruff format --check conv_sim/python conv_sim/scripts
```

`--suite all` 可替代前两条命令。单独改变参数场景、并行度或重复方式：

```bash
python conv_sim/python/experiment.py --case rectangular --lanes 1 4 8
python conv_sim/python/experiment.py --case small --lanes 16 --runs 2 --reset-between-runs 0
python conv_sim/python/experiment.py --case small --seed 42
```

前端依次执行数据生成、参考计算、小尺寸独立标量交叉检查、编译、仿真自校验、输出文件比较和指标汇总。数据不匹配、X/Z、非法地址、重复/缺失输出及超时均产生非零退出码。正常实验日志含 `errors=0` 和 `PASS`。

每次运行更新 `results/<case>/` 和汇总文件；验证脚本更新 `results/validation/`；汇集脚本更新 `results/evidence/`，不会依赖报告目录。数值与性能图仅写入本地忽略的 `report/figures/`。`results/` 默认仍受忽略规则保护，仓库已显式收录上面列出的精简记录，重新运行会更新相同位置的已跟踪文件。

未收录的大数据由 `experiment.py` 重建：`data/ifm.hex` 为补零输入，`kernel.hex` 为权重，`golden.hex` 为量化参考，`golden_acc.hex` 为 int32 累加参考，`golden.npy` 为 Python 参考张量；`lanes<L>/output.hex` 为 RTL 输出，`sim.vvp` 为仿真可执行文件，`wave.vcd` 为该次真实信号记录。默认随机种子为 **20261017**，元数据内保存参数和数据摘要以便核对。

## 波形查看

无需重跑即可查看仓库中的精简波形：

```bash
gtkwave results/evidence/wave.vcd conv_sim/wave.gtkw
```

也可查看新运行的 `results/small/lanes16/wave.vcd`，并换用 `wave_start.gtkw`、`wave_mac.gtkw`、`wave_write.gtkw` 或 `wave_done.gtkw` 聚焦相应阶段。总线累加和输出采用有符号十进制显示，状态编码参见 RTL 接口说明。

快速实验默认只转储前 600 个周期及任务结束附近，控制信号计算与自校验始终持续；中间停录区不用于核遍历分析。0～5 ns 的 X 是首个时钟上升沿复位赋值前的初态，5 ns 后信号初始化。默认视图已设合理缩放，避免停留在只有数皮秒的窗口。

## 算子语义与配置范围

量化执行 `clip(acc >>> SHIFT, -128, 127)`，默认移位 8、填充 1、步长 1，无偏置，激活为恒等映射。采用深度学习互相关定义；输入/输出为 HWC，权重为输出通道、核行、核列、输入通道顺序，存储字最右 8 位为通道 0。

`H/W/CIN/KERNEL_H/KERNEL_W/KERNELS/COUT/PAD/STRIDE/SHIFT/LANES` 在编译时配置，三个基址和启动在运行时配置。输入由 Python 预补零，存储器为一拍同步读，输出无背压。通道数不要求整除并行度，核高宽独立。合法条件包括正输入/核/步长/并行度、非负填充、正输出尺寸、`1<=COUT<=KERNELS`、20 位地址范围、移位 0～31，且数学累加不溢出 int32。

课程原始工程在本地 `baseline/` 保存；实验代码由 `conv_sim/` 独立维护。Python 使用 4 空格缩进、snake_case 命名与中文代码注释，通过 Ruff 检查格式、导入顺序和常见错误。
