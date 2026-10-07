# 一层 8-bit 量化卷积 RTL 加速器设计报告

## 1. 设计任务与课程要求

## 2. 参数定义与数据格式

## 3. Python 参考数据生成

## 4. RTL 结构

## 5. Testbench 自检设计

说明 testbench 如何读取 `expected.bin`，如何逐项比较，如何输出 `TB_PASS/TB_FAIL`。

## 6. ModelSim 仿真过程

插入编译、复位启动、输入权重加载、输出完成截图。

## 7. 标准配置验证结果

填写 Transcript 中的实际 `TB_SUMMARY`，确认 `mismatches=0`、`errors=0`、`TB_PASS`。

## 8. 参数可调实验

填写 `stride2_pad0`、`kernel1`、`kernel5`、`height64`、`width64`、`input_channels8`、`output_channels16`、`acc24`、`truncate_quant` 的结果。

## 9. 并行度实验

填写 `parallel_2x`、`parallel_4x`、`parallel_8x`、`parallel_16x` 的周期、加速比和自检结果，插入四张并行波形截图。

## 10. 结果分析

## 11. 总结
