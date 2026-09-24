# AI Chip Design Assignment

西安交通大学《人工智能芯片设计导论》课程作业仓库。仓库按三个作业拆分，所有脚本和报告源文件均可在命令行环境中复现。

## 作业目录

| 目录 | 内容 |
| --- | --- |
| `assignment1_fpga/` | Ultra96 FPGA：Python 仿真、PS/PYNQ 数据通路、PL 加速器接口和报告 |
| `assignment2_rtl/` | 可综合 Verilog 卷积模块、testbench、仿真脚本和报告 |
| `assignment3_survey/` | 人工智能芯片调研综述 LaTeX 模板（正文未写） |
| `common/python/` | 共享的 8-bit 输入/输出、32-bit 累加卷积参考模型 |

## 快速开始

```bash
CONDA_PKGS_DIRS="$PWD/.conda-pkgs" conda env create --prefix ./.conda -f environment.yml
conda activate ./.conda
make test       # Python 参考模型测试
make sim        # Verilator RTL smoke simulation
make lint
```

Conda 环境和包缓存分别安装在当前仓库的 `.conda/` 和 `.conda-pkgs/`。Vivado 是 Xilinx 专有工具，不能通过 conda 部署；Ultra96 板端需要匹配硬件版本的 PYNQ 镜像。`assignment1_fpga/README.md` 标明未完成的板端步骤。

## 统一数据约定

默认课程规模为输入 `(H,W,C)=(256,256,16)`、输出 `(H,W,C)=(256,256,32)`、卷积核 `(K_N,K_H,K_W,K_C)=(32,3,3,16)`。参考实现使用 NHWC 布局、stride=1、padding=1，乘加在 `int32` 中完成，最后饱和到 int8。仿真 smoke test 使用更小的尺寸以便在普通电脑上快速运行；参数接口与课程规模一致。

## 报告

报告统一使用 Tectonic（XeTeX 引擎）+ `ctex` 编译，PDF 位于 `build/reports/`：

```bash
make report
```

作业一、二是待填实测数据的报告骨架；作业三仅提供模板，不含综述正文。请在提交前补齐实验数据、截图和可核验文献。

## 许可证

代码采用 MIT License；课程报告和实验数据仅供课程学习使用。
