"""生成定点参考、驱动 Icarus Verilog 并保存可复核实验结果。"""

import argparse
import hashlib
import json
import os
import platform
import shutil
import subprocess
import time
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
RESULTS = ROOT / "results"
DEFAULT = dict(
    H=8,
    W=8,
    CIN=16,
    KERNEL_H=3,
    KERNEL_W=3,
    KERNELS=32,
    COUT=32,
    PAD=1,
    STRIDE=1,
    SHIFT=8,
)
CASES = {
    "small": dict(lanes=[1, 4, 16], runs=2),
    "rectangular": dict(
        H=7, W=11, CIN=5, COUT=7, KERNELS=7, lanes=[1, 4, 8], runs=2
    ),
    "pointwise": dict(
        H=5,
        W=9,
        CIN=3,
        COUT=5,
        KERNELS=5,
        KERNEL_H=1,
        KERNEL_W=1,
        PAD=0,
        lanes=[1, 4],
        runs=2,
    ),
    "stride2": dict(
        H=9, W=12, CIN=7, COUT=9, KERNELS=9, STRIDE=2, lanes=[1, 4], runs=2
    ),
    "kernel5": dict(
        H=6,
        W=8,
        CIN=3,
        COUT=4,
        KERNELS=4,
        KERNEL_H=5,
        KERNEL_W=5,
        PAD=2,
        lanes=[1, 4],
        runs=2,
    ),
    "valid": dict(
        H=7,
        W=10,
        CIN=5,
        COUT=3,
        KERNELS=3,
        KERNEL_H=2,
        KERNEL_W=3,
        PAD=0,
        SHIFT=4,
        lanes=[1, 4],
        runs=2,
    ),
    "quantization": dict(
        H=1,
        W=8,
        CIN=1,
        COUT=1,
        KERNELS=1,
        KERNEL_H=1,
        KERNEL_W=1,
        PAD=0,
        SHIFT=1,
        lanes=[1, 4],
        runs=2,
    ),
    "negative_saturation": dict(
        H=1,
        W=8,
        CIN=1,
        COUT=1,
        KERNELS=1,
        KERNEL_H=1,
        KERNEL_W=1,
        PAD=0,
        SHIFT=1,
        lanes=[1],
        runs=2,
    ),
    "full": dict(H=256, W=256, lanes=[16], runs=1),
}


def configuration(name):
    """返回明确尺寸并检查地址、累加范围。

    Args:
        name: CASES 中的实验场景名称。

    Returns:
        包含尺寸、步长、填充和定点参数的字典。
    """
    config = DEFAULT | {k: v for k, v in CASES[name].items() if k.isupper()}
    config["OH"] = (
        config["H"] + 2 * config["PAD"] - config["KERNEL_H"]
    ) // config["STRIDE"] + 1
    config["OW"] = (
        config["W"] + 2 * config["PAD"] - config["KERNEL_W"]
    ) // config["STRIDE"] + 1
    assert config["COUT"] <= config["KERNELS"]
    assert min(config["OH"], config["OW"]) > 0
    assert (
        config["CIN"] * config["KERNEL_H"] * config["KERNEL_W"] * 16384 < 2**31
    )
    assert (config["H"] + 2 * config["PAD"]) * (
        config["W"] + 2 * config["PAD"]
    ) + 17 < 2**20
    return config


def reference(image, kernel, config):
    """逐核位置做整数通道收缩，使用 int64 校验 int32 的精确值。

    Args:
        image: HWC 格式的有符号 int8 输入。
        kernel: 输出通道、核行、核列、输入通道格式的权重。
        config: 包含输入输出尺寸与定点参数的配置字典。

    Returns:
        补零输入、int32 原始累加和 int8 量化输出。
    """
    c = config
    p = c["PAD"]
    padded = np.pad(image, ((p, p), (p, p), (0, 0)))
    acc = np.zeros((c["OH"], c["OW"], c["COUT"]), dtype=np.int64)
    for kh in range(c["KERNEL_H"]):
        for kw in range(c["KERNEL_W"]):
            window = padded[
                kh : kh + c["OH"] * c["STRIDE"] : c["STRIDE"],
                kw : kw + c["OW"] * c["STRIDE"] : c["STRIDE"],
            ]
            acc += np.einsum(
                "hwc,nc->hwn",
                window.astype(np.int64),
                kernel[: c["COUT"], kh, kw].astype(np.int64),
                optimize=False,
            )
    assert np.max(np.abs(acc)) < 2**31
    quantized = np.clip(acc >> c["SHIFT"], -128, 127).astype(np.int8)
    return padded, acc.astype(np.int32), quantized


def scalar_reference(image, kernel, c):
    """独立标量循环核对向量参考的填充和步长索引。

    Args:
        image: 原始 HWC 输入数组。
        kernel: 按输出通道与核坐标排列的权重数组。
        c: 卷积尺寸与步长配置。

    Returns:
        HWC 格式的 int32 原始累加数组。
    """
    output = np.zeros((c["OH"], c["OW"], c["COUT"]), dtype=np.int32)
    for y, x, n in np.ndindex(output.shape):
        total = 0
        for kh, kw, ch in np.ndindex(kernel.shape[1:]):
            iy = y * c["STRIDE"] + kh - c["PAD"]
            ix = x * c["STRIDE"] + kw - c["PAD"]
            if 0 <= iy < c["H"] and 0 <= ix < c["W"]:
                total += int(image[iy, ix, ch]) * int(kernel[n, kh, kw, ch])
        output[y, x, n] = total
    return output


def write_hex(path, array, bits=8):
    """空间位置逐行，最低有效字段对应通道零。

    Args:
        path: 目标十六进制文件路径。
        array: 最后一维为通道的整数数组。
        bits: 每个通道的补码位宽，取 8 或 32。
    """
    values = array.reshape(-1, array.shape[-1])
    mask = (1 << bits) - 1
    with path.open("w", encoding="ascii") as stream:
        for row in values:
            stream.write(
                "".join(f"{int(v) & mask:0{bits // 4}x}" for v in row[::-1])
                + "\n"
            )


def read_hex(path, shape):
    """读取 RTL 写出的通道打包结果。

    Args:
        path: 每行一个空间位置的通道打包文件。
        shape: 输出的高、宽、通道数。

    Returns:
        指定形状的有符号 int8 数组。
    """
    lines = path.read_text(encoding="ascii").splitlines()
    assert len(lines) == shape[0] * shape[1], "输出空间位置数量异常"
    raw = bytes.fromhex("".join(lines))
    values = np.frombuffer(raw, dtype=np.int8).reshape(-1, shape[-1])[:, ::-1]
    return values.reshape(shape)


def generate(name, seed):
    """固定随机种子生成输入、权重、8 位与 32 位参考。

    Args:
        name: 实验场景名称。
        seed: 输入与权重生成器的随机种子。

    Returns:
        配置字典、数据目录和 int8 参考数组。
    """
    c = configuration(name)
    data = RESULTS / name / "data"
    data.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(seed)
    image = rng.integers(
        -128, 128, (c["H"], c["W"], c["CIN"]), dtype=np.int16
    ).astype(np.int8)
    kernel = rng.integers(
        -128,
        128,
        (c["KERNELS"], c["KERNEL_H"], c["KERNEL_W"], c["CIN"]),
        dtype=np.int16,
    ).astype(np.int8)
    if name in ("quantization", "negative_saturation"):
        image[0, :, 0] = [-128, -127, -3, -1, 0, 1, 126, 127]
        kernel.fill(3 if name == "quantization" else -3)
    padded, acc, golden = reference(image, kernel, c)
    if name != "full":
        np.testing.assert_array_equal(acc, scalar_reference(image, kernel, c))
    write_hex(data / "ifm.hex", padded)
    write_hex(data / "kernel.hex", kernel)
    write_hex(data / "golden.hex", golden)
    write_hex(data / "golden_acc.hex", acc, 32)
    np.save(data / "golden.npy", golden)
    metadata = dict(
        config=c,
        seed=seed,
        input_min=int(image.min()),
        input_max=int(image.max()),
        accumulator_min=int(acc.min()),
        accumulator_max=int(acc.max()),
        negative_saturated=int(np.count_nonzero((acc >> c["SHIFT"]) < -128)),
        positive_saturated=int(np.count_nonzero((acc >> c["SHIFT"]) > 127)),
        sha256={
            p.name: hashlib.sha256(p.read_bytes()).hexdigest()
            for p in data.glob("*.hex")
        },
    )
    (data / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
    return c, data, golden


def execute(command, log, timeout=7200):
    """保存完整命令日志，子进程异常直接终止实验。

    Args:
        command: 子进程参数序列。
        log: 命令与标准输出的保存路径。
        timeout: 子进程允许执行的最长秒数。

    Returns:
        子进程的主机墙钟耗时，单位为秒。
    """
    start = time.perf_counter()
    with log.open("w") as stream:
        stream.write("COMMAND: " + " ".join(map(str, command)) + "\n")
        stream.flush()
        subprocess.run(
            list(map(str, command)),
            cwd=ROOT,
            stdout=stream,
            stderr=subprocess.STDOUT,
            check=True,
            timeout=timeout,
        )
    return time.perf_counter() - start


def run(name, c, data, golden, lanes, runs, trace, reset):
    """编译参数化 RTL，通过 TB 与 Python 两层进行结果核对。

    Args:
        name: 实验场景名称。
        c: 卷积配置字典。
        data: 输入、权重与参考文件所在目录。
        golden: int8 参考输出数组。
        lanes: 并行乘法器数量。
        runs: 完整任务的执行次数。
        trace: 是否导出控制信号波形。
        reset: 是否在重复任务之间复位。

    Returns:
        包含周期、精度、耗时与配置的实测指标字典。
    """
    directory = RESULTS / name / f"lanes{lanes}"
    directory.mkdir(parents=True, exist_ok=True)
    binary = directory / "sim.vvp"
    params = c | dict(LANES=lanes, RUNS=runs, RESET_BETWEEN_RUNS=reset)
    command = ["iverilog", "-g2012", "-Wall", "-s", "tb_conv", "-o", binary]
    command += [f"-Ptb_conv.{k}={v}" for k, v in params.items()]
    command += [ROOT / "conv_sim/rtl/conv.sv", ROOT / "conv_sim/tb/tb_conv.sv"]
    compile_s = execute(command, directory / "compile.log")
    command = [
        "vvp",
        binary,
        f"+IFM={data / 'ifm.hex'}",
        f"+KERNEL={data / 'kernel.hex'}",
        f"+GOLDEN={data / 'golden.hex'}",
        f"+GOLDEN_ACC={data / 'golden_acc.hex'}",
        f"+OUTPUT={directory / 'output.hex'}",
        f"+METRICS={directory / 'tb_metrics.json'}",
    ]
    if trace:
        command += [f"+VCD={directory / 'wave.vcd'}", "+TRACE_CYCLES=600"]
    print(
        f"运行 {name}: LANES={lanes}, 输出={golden.size}, RUNS={runs}",
        flush=True,
    )
    wall_s = execute(command, directory / "simulation.log")
    metrics = json.loads((directory / "tb_metrics.json").read_text())
    output = read_hex(directory / "output.hex", golden.shape)
    diff = np.abs(output.astype(np.int16) - golden.astype(np.int16))
    assert metrics["errors"] == 0 and not np.any(diff)
    metrics.update(
        case=name,
        config=c,
        compile_seconds=compile_s,
        simulation_seconds=wall_s,
        max_abs_error=int(diff.max()),
        mismatches=int(np.count_nonzero(diff)),
        output_sha256=hashlib.sha256(output.tobytes()).hexdigest(),
        macs=int(golden.size * c["KERNEL_H"] * c["KERNEL_W"] * c["CIN"]),
        reset_between_runs=reset,
    )
    metrics["simulated_ms"] = (
        metrics["cycles"] * metrics["clock_period_ns"] / 1e6
    )
    (directory / "metrics.json").write_text(
        json.dumps(metrics, indent=2) + "\n"
    )
    print(
        f"通过 {name}/lanes{lanes}: {metrics['cycles']:,} cycles, {wall_s:.2f} s",
        flush=True,
    )
    return metrics


def summarize():
    """收集已完成实验，使单独重跑的结果也能汇总。"""
    rows = [
        json.loads(p.read_text())
        for p in sorted(RESULTS.glob("*/lanes*/metrics.json"))
    ]
    rows.sort(key=lambda row: (row["case"], row["lanes"]))
    for row in rows:
        baseline = next(
            (r for r in rows if r["case"] == row["case"] and r["lanes"] == 1),
            None,
        )
        row["cycle_speedup"] = (
            baseline["cycles"] / row["cycles"] if baseline else None
        )
    (RESULTS / "summary.json").write_text(json.dumps(rows, indent=2) + "\n")
    versions = dict(
        python=platform.python_version(),
        numpy=np.__version__,
        platform=platform.platform(),
    )
    for executable, args in [("iverilog", ["-V"]), ("gtkwave", ["--version"])]:
        if shutil.which(executable):
            completed = subprocess.run(
                [executable] + args, capture_output=True, text=True
            )
            versions[executable] = (
                completed.stdout + completed.stderr
            ).splitlines()[:4]
    (RESULTS / "environment.json").write_text(
        json.dumps(versions, indent=2) + "\n"
    )


def main():
    """选择快速回归或课程完整尺寸实验。"""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--suite", choices=["quick", "full", "all"], default="quick"
    )
    parser.add_argument("--case", choices=CASES)
    parser.add_argument("--lanes", type=int, nargs="+")
    parser.add_argument("--seed", type=int, default=20261017)
    parser.add_argument("--runs", type=int)
    parser.add_argument("--no-trace", action="store_true")
    parser.add_argument(
        "--reset-between-runs", type=int, choices=[0, 1], default=1
    )
    args = parser.parse_args()
    os.environ.setdefault("MPLCONFIGDIR", str(ROOT / ".cache/matplotlib"))
    names = (
        [args.case]
        if args.case
        else [
            n
            for n in CASES
            if args.suite == "all" or (n == "full") == (args.suite == "full")
        ]
    )
    for name in names:
        c, data, golden = generate(name, args.seed)
        for lanes in args.lanes or CASES[name]["lanes"]:
            if lanes < 1:
                parser.error("LANES 必须为正整数")
            run(
                name,
                c,
                data,
                golden,
                lanes,
                args.runs or CASES[name]["runs"],
                not args.no_trace,
                args.reset_between_runs,
            )
            summarize()


if __name__ == "__main__":
    main()
