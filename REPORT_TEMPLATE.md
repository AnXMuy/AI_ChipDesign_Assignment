# 一层 8-bit 量化卷积 RTL 加速器设计报告

## 摘要

## 1. 任务与指标

## 2. 数据格式与数值规则

## 3. RTL 架构

## 4. Testbench 与验证方法

通过标准：`mismatches=0`、`errors=0`、`TB_PASS`。

## 5. ModelSim 实验环境与步骤

## 6. 参数可调实验

| 配置 | 参数改动 | 预期变化 | 实测输出尺寸 | 周期 | mismatch | 状态 |
|---|---|---|---:|---:|---:|---|
| baseline | 标准配置 | 基线 |  |  |  |  |
| stride2_pad0 | stride=2,pad=0 | 输出空间缩小 |  |  |  |  |
| kernel1 | 核 1×1 | 输出空间扩大 |  |  |  |  |
| kernel5 | 核 5×5 | 输出空间缩小 |  |  |  |  |
| height64 | H=64 | 输出高度改变 |  |  |  |  |
| width64 | W=64 | 输出宽度改变 |  |  |  |  |
| input_channels8 | C=KC=8 | 数据规模改变 |  |  |  |  |
| output_channels16 | KN=16 | 输出通道改变 |  |  |  |  |
| acc24 | ACC_WIDTH=24 | 累加范围改变 |  |  |  |  |
| truncate_quant | 截断量化 | 量化规则改变 |  |  |  |  |

## 7. 并行度实验

| 配置 | P_KN | P_KH/P_KW/P_C | cycles | 加速比 | mismatch | 状态 |
|---|---:|---|---:|---:|---:|---|
| parallel_2x | 2 | 1/1/1 |  |  |  |  |
| parallel_4x | 4 | 1/1/1 |  |  |  |  |
| parallel_8x | 8 | 1/1/1 |  |  |  |  |
| parallel_16x | 16 | 1/1/1 |  |  |  |  |

## 8. 结果讨论

## 9. 结论

## 附件

列出 ModelSim 截图、Transcript 日志和实验记录表文件名。
