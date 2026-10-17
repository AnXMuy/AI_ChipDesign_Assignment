# 人工智能芯片导论：可配置 8-bit 卷积加速器

基于课程 `baseline` 的定点卷积语义、按空间位置打包通道的存储格式和同步读接口，使用 SystemVerilog 实现可综合卷积，使用 Python 驱动 **Icarus Verilog + GTKWave** 完成验证。主实验输入为 **256×256×16**，卷积核为 **32×3×3×16**，输出为 **256×256×32**，中间累加为有符号 32-bit。

完整中文报告见 [实验报告](report/实验报告.md)，实测记录见 [实验结果表](report/evidence/results_table.md) 和 [机器可读结果](report/evidence/summary.json)。

## 环境配置

所有 Python 依赖、Icarus 和 GTKWave 工具都安装在 conda 环境。macOS 首先安装 Xcode Command Line Tools，Linux 准备 C/C++ 编译器。项目目录建议使用不含空格的路径。

```bash
conda env create -f environment.yml
conda activate aichip
python conv_sim/scripts/install_tools.py
iverilog -V
gtkwave --version
```

`install_tools.py` 将 Icarus **12.0** 和 GTKWave **3.3.116** 从固定发布标签构建至 `$CONDA_PREFIX`；源码、编译日志位于被 Git 忽略的 `conv_sim/.build/`，源文件摘要保存在 `$CONDA_PREFIX/toolchain-sources.json`。GTKWave 使用 GTK3、关闭 Tcl 脚本接口和 VZT 的 XZ 压缩，支持本实验输出的 VCD 文件。macOS Quartz 后端构建单窗口查看器，安装脚本自动关闭 X11 窗口嵌入及 TwinWave 辅助程序。已运行平台的精确 conda 包清单见 `conda-osx-arm64.lock.txt`，Python 工具检查配置见 `pyproject.toml`。

本机使用项目内前缀，等价命令为：

```bash
conda env create --prefix ./.conda-env -f environment.yml
conda activate ./.conda-env
python conv_sim/scripts/install_tools.py
```

## 运行实验

在仓库根目录、激活 conda 环境后执行：

```bash
# 参数变化、1/4/16 路并行、量化边界，默认每个配置运行两次。
python conv_sim/python/experiment.py --suite quick

# 课程完整尺寸，16 路并行，核对全部 2,097,152 个输出及其累加值。
python conv_sim/python/experiment.py --suite full

# 综合、无复位重复启动与参考错误注入检查。
python conv_sim/scripts/validate.py

# 生成数值结果图、性能图与结果表，并汇集实际运行记录。
python conv_sim/python/figures.py

# Python 格式与静态检查。
ruff check conv_sim/python conv_sim/scripts
ruff format --check conv_sim/python conv_sim/scripts
```

可一次运行全部配置：

```bash
python conv_sim/python/experiment.py --suite all
```

单独选择参数场景、并行度、随机种子或启动次数：

```bash
python conv_sim/python/experiment.py --case rectangular --lanes 1 4 8
python conv_sim/python/experiment.py --case small --lanes 16 --runs 2 --reset-between-runs 0
python conv_sim/python/experiment.py --case small --seed 42
```

每次实验自动完成数据生成、独立标量参考交叉检查（小尺寸）、Icarus 编译、`vvp` 执行、TB 自校验、Python 文件逐元素比对及 JSON 汇总。终端显示 `通过`，仿真日志包含 `errors=0` 和 `PASS`。失败、超时、X/Z、地址异常、重复或丢失输出会让命令以非零状态退出。完整尺寸默认运行 16 路版本；串并行速度比较使用相同 `small` 配置的数据和输出规模。

运行产生的 `results/` 包括输入、权重、参考值、RTL 输出、VCD、编译日志、仿真日志和 JSON 指标，支持重复生成。`report/evidence/` 保留本次提交的指标、数据 SHA-256、日志和小规模波形证据。

## 波形查看

```bash
gtkwave report/evidence/screenshot_wave.vcd conv_sim/wave.gtkw
```

也可查看普通快速回归产生的波形：

```bash
gtkwave results/small/lanes16/wave.vcd conv_sim/wave.gtkw
```

保存视图包括 `clk/rst/start/done`、状态机、输入和权重读请求、读地址、核坐标、输出通道、累加器与输出有效信号。截图专用波形连续记录一次完整的 `small / LANES=16` 任务，包含全部 57,345 个周期和 2,048 个输出；普通快速回归默认仅记录前 600 个计算周期和结束附近，完整计算与检查持续运行。

报告中保留四幅真实 GTKWave 截图的纯文本占位，依次展示启动、核遍历与乘累加、连续写回和任务结束，等待截图后粘贴。截图时间窗口、信号选择及有符号显示方法见 [临时截图操作说明](report/截图操作说明_临时.md)。完整尺寸的完成日志、数值比较和性能结果已直接写入报告。

## 代码职责

| 路径 | 用途 |
|---|---|
| `conv_sim/rtl/conv.sv` | 可综合卷积状态机、地址生成、通道分组并行乘累加与饱和量化 |
| `conv_sim/rtl/README.md` | RTL 存储协议、参数、状态转换和精确周期定义 |
| `conv_sim/tb/tb_conv.sv` | 同步读内存、数据装载、32/8-bit 双重自校验、结果收集及 VCD 导出 |
| `conv_sim/python/experiment.py` | 固定种子数据、向量/标量参考、参数集、编译仿真和结果统计 |
| `conv_sim/python/figures.py` | 从数值输出和指标生成结果/性能图、汇总证据并复制真实 VCD |
| `conv_sim/scripts/install_tools.py` | 固定版本仿真工具在 conda 环境中的源码构建 |
| `conv_sim/scripts/validate.py` | 综合结构检查、重启与故障注入验证 |
| `environment.yml` | 跨平台 conda 环境及 Python 工具版本 |
| `conda-osx-arm64.lock.txt` | 本次实验平台的 conda 精确包清单 |
| `report/实验报告.md` | 实验内容、方法、结果分析、总结与心得 |

Python 使用 4 空格缩进、snake_case 命名、模块与函数说明，采用 Google Python 风格的基本约定，并由 Ruff 检查格式与常见错误。新代码注释使用中文。

## 算子与配置范围

输入和权重采用有符号 int8，输出执行 `clip(acc >>> SHIFT, -128, 127)`。默认 `SHIFT=8`、`PAD=1`、`STRIDE=1`，无 bias 和激活函数。卷积为深度学习常用互相关定义；核存储为 NHWC，输入与输出存储为 HWC，每行最右字段为通道 0。

`H/W/CIN/COUT/KERNEL_H/KERNEL_W/PAD/STRIDE/SHIFT/LANES` 在编译时配置；基址和启动在运行时配置。输入由 Python 预填充，存储接口为固定一拍同步读；输出无背压，TB 每拍接收。已实测：H/W 1～256、CIN 1～16、COUT 1～32、卷积核 1×1/2×3/3×3/5×5、步长 1/2、填充 0/1/2、SHIFT 1/4/8、LANES 1/4/8/16。合法配置须保证输出尺寸为正、地址可由 20 位表示，且 `KH*KW*CIN*16384 < 2^31`。

课程原始材料保留在本地 `baseline/`，使用其定点算法及存储协议作为设计起点；提交的实现和实验材料统一维护在 `conv_sim/` 与 `report/`。本次覆盖提交更新远端 `main` 的内容，并保留仓库已有提交历史。
