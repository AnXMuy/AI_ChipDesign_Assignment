# AI 芯片设计导论课程作业

本仓库用于完成一层 8-bit 量化卷积的 RTL 设计、ModelSim 仿真和 Python 结果校验。

## 仓库内容

- `python/`：配置、数据生成、Python 参考模型、结果比对和实验脚本。
- `rtl/`：SystemVerilog RTL 模块。
- `tb/`：ModelSim testbench。它负责读取输入和权重、驱动 RTL、保存输出结果。
- `scripts/`：ModelSim 批处理脚本。
- `data/`：运行 Python 脚本后生成实验数据。
- `MODELsim运行指南.md`：从生成数据到 ModelSim 仿真的完整操作说明。
- `报告撰写指南.md`：报告章节、截图清单和结果填写说明。
- `REPORT_TEMPLATE.md`：可直接复制使用的中文报告模板。

## 课程标准配置

本仓库默认使用课程要求的 `baseline` 配置：

- 输入特征图：`H=256, W=256, C=16`
- 输出通道：`KN=32`
- 卷积核：`KH=3, KW=3, KC=16`
- 步长：`STRIDE=1`
- 填充：`PAD=1`
- 输入、权重、输出：有符号 8-bit
- 中间累加：32-bit
- 输出量化：饱和到 `[-128, 127]`

## 完整运行流程

在仓库根目录依次执行：

```bash
python3 python/gen_data.py --config baseline
python3 python/run_golden.py --config baseline
vsim -c -do "do scripts/run_sim.tcl baseline"
python3 python/compare.py --cfg baseline --rtl results/baseline/rtl_output.bin
```

正确结果应满足：

```text
num_err: 0
err_rate: 0.0
max_abs_err: 0
```

如果需要一次执行完整流程：

```bash
./scripts/run_all.sh
```

## 报告和截图

请先阅读 `MODELsim运行指南.md`，按其中的 7 类截图清单保存截图；再阅读 `报告撰写指南.md`，根据实际日志填写 `REPORT_TEMPLATE.md`。

报告材料建议放在本地 `report/` 目录，包含仿真日志、结果比对文件、截图和最终报告。`report/` 不属于开源代码提交内容。

## 重要说明

RTL 使用 SystemVerilog 数组和参数化端口，ModelSim 编译时必须使用 `vlog -sv`。本仓库的最终 RTL 仿真需要在安装 ModelSim 或 QuestaSim 的电脑上执行。
