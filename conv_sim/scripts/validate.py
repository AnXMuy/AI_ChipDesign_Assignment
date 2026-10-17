#!/usr/bin/env python3
"""复现无复位重启、参考故障注入及可综合资源计数。"""

import json
import os
import random
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "results/validation"
os.environ["PATH"] = (
    str(ROOT / ".conda-env/bin") + os.pathsep + os.environ.get("PATH", "")
)
os.environ.setdefault("YOWASP_CACHE_DIR", str(ROOT / ".cache/yowasp"))
os.environ.setdefault("XDG_CACHE_HOME", str(ROOT / ".cache"))


def execute(command, *, expected_success=True):
    """保留完整输出并要求成功/失败结果符合预期。"""
    result = subprocess.run(
        list(map(str, command)),
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=180,
    )
    if (result.returncode == 0) != expected_success:
        raise RuntimeError(result.stdout + result.stderr)
    return result


def packed(path, rows, bits):
    """通道零占最低位，每行一个空间字。"""
    path.write_text(
        "".join(
            f"{sum((v & ((1 << bits) - 1)) << (c * bits) for c, v in enumerate(row)):0{len(row) * bits // 4}x}\n"
            for row in rows
        )
    )


def simulation_checks(work):
    """纯 Python 整数循环独立生成非整除通道与步幅二的参考。"""
    config = dict(
        H=3,
        W=4,
        CIN=5,
        KERNEL_H=3,
        KERNEL_W=3,
        KERNELS=3,
        COUT=2,
        PAD=1,
        STRIDE=2,
        SHIFT=8,
    )
    rng = random.Random(101)
    x = [[[0] * 5 for _ in range(6)] for _ in range(5)]
    for y in range(3):
        for xx in range(4):
            x[y + 1][xx + 1] = [rng.randint(-128, 127) for _ in range(5)]
    weights = [
        [
            [[rng.randint(-128, 127) for _ in range(5)] for _ in range(3)]
            for _ in range(3)
        ]
        for _ in range(3)
    ]
    accumulators = []
    for y in range(2):
        for xx in range(2):
            accumulators.append(
                [
                    sum(
                        x[y * 2 + ky][xx * 2 + kx][ch] * weights[oc][ky][kx][ch]
                        for ky in range(3)
                        for kx in range(3)
                        for ch in range(5)
                    )
                    for oc in range(2)
                ]
            )
    quantized = [
        [min(127, max(-128, value >> 8)) for value in row]
        for row in accumulators
    ]
    packed(work / "ifm.hex", [word for row in x for word in row], 8)
    packed(
        work / "kernel.hex",
        [word for oc in weights for row in oc for word in row],
        8,
    )
    packed(work / "golden.hex", quantized, 8)
    packed(work / "golden_acc.hex", accumulators, 32)
    records, restart_text = [], []
    for lane in (1, 4, 16):
        binary = work / f"lanes{lane}.vvp"
        command = ["iverilog", "-g2012", "-Wall", "-s", "tb_conv", "-o", binary]
        command += [
            f"-Ptb_conv.{k}={v}"
            for k, v in (
                config | dict(LANES=lane, RUNS=2, RESET_BETWEEN_RUNS=0)
            ).items()
        ]
        command += ["conv_sim/rtl/conv.sv", "conv_sim/tb/tb_conv.sv"]
        compiled = execute(command)
        (EVIDENCE / f"restart_compile_lanes{lane}.log").write_text(
            compiled.stdout + compiled.stderr
        )
        command = ["vvp", binary] + [
            f"+{flag}={work / name}"
            for flag, name in (
                ("IFM", "ifm.hex"),
                ("KERNEL", "kernel.hex"),
                ("GOLDEN", "golden.hex"),
                ("GOLDEN_ACC", "golden_acc.hex"),
                ("OUTPUT", "output.hex"),
                ("METRICS", "metrics.json"),
            )
        ]
        simulated = execute(command)
        metrics = json.loads((work / "metrics.json").read_text())
        assert metrics["runs"] == 2 and metrics["errors"] == 0
        assert (work / "output.hex").read_text() == (
            work / "golden.hex"
        ).read_text()
        records.append(dict(config=config, **metrics))
        restart_text += [
            f"LANES={lane}, RUNS=2, RESET_BETWEEN_RUNS=0",
            simulated.stdout,
            json.dumps(metrics),
        ]
        if lane == 4:
            words = (work / "golden.hex").read_text().splitlines()
            words[0] = f"{int(words[0], 16) ^ 1:04x}"
            (work / "bad_golden.hex").write_text("\n".join(words) + "\n")
            bad_command = [
                str(arg).replace(
                    "+GOLDEN=" + str(work / "golden.hex"),
                    "+GOLDEN=" + str(work / "bad_golden.hex"),
                )
                for arg in command
            ]
            failed = execute(bad_command, expected_success=False)
            assert "int8 mismatch" in failed.stdout and "FAIL:" in failed.stdout
            record = dict(
                fault="flip first golden output bit",
                returncode=failed.returncode,
                detected=True,
                scope="int8 mismatch and fatal after both repeated runs",
            )
            (EVIDENCE / "fault_injection.log").write_text(
                failed.stdout + failed.stderr
            )
            (EVIDENCE / "fault_injection.json").write_text(
                json.dumps(record, indent=2) + "\n"
            )
    (EVIDENCE / "restart.log").write_text("\n".join(restart_text) + "\n")
    (EVIDENCE / "restart.json").write_text(json.dumps(records, indent=2) + "\n")


def synthesis_checks(work):
    """先参数化再展开，按运算宽度区分数据乘法器与地址乘法器。"""
    summary = []
    for lane in (1, 4, 16):
        netlist = work / f"synthesis_lanes{lane}.json"
        command = (
            f"read_verilog -sv conv_sim/rtl/conv.sv; chparam -set LANES {lane} conv; "
            f"hierarchy -top conv; proc; opt; check; stat; write_json {netlist}"
        )
        result = execute(["yowasp-yosys", "-p", command])
        log = result.stdout + result.stderr
        assert "Found and reported 0 problems." in log
        (EVIDENCE / f"synthesis_lanes{lane}.log").write_text(
            "\n".join(line.rstrip() for line in log.splitlines()) + "\n"
        )
        cells = json.loads(netlist.read_text())["modules"]["conv"]["cells"]
        counts = {}
        for cell in cells.values():
            counts[cell["type"]] = counts.get(cell["type"], 0) + 1
        multipliers = [
            dict(
                name=name,
                **{
                    key: int(value, 2)
                    for key, value in cell["parameters"].items()
                    if key
                    in ("A_WIDTH", "B_WIDTH", "Y_WIDTH", "A_SIGNED", "B_SIGNED")
                },
            )
            for name, cell in cells.items()
            if cell["type"] == "$mul"
        ]
        data_mul = [m for m in multipliers if m["A_WIDTH"] == m["B_WIDTH"] == 8]
        assert len(data_mul) == lane and all(
            m["A_SIGNED"] == m["B_SIGNED"] == 1 for m in data_mul
        )
        flops = [cell for cell in cells.values() if "dff" in cell["type"]]
        summary.append(
            dict(
                lanes=lane,
                datapath_8x8_multipliers=len(data_mul),
                total_mul_cells=counts.get("$mul", 0),
                adder_cells=counts.get("$add", 0),
                ff_cells=len(flops),
                ff_bits=sum(int(c["parameters"]["WIDTH"], 2) for c in flops),
                total_cells=len(cells),
                check_problems=0,
                all_cells_by_type=counts,
                multipliers=multipliers,
            )
        )
    (EVIDENCE / "synthesis_summary.json").write_text(
        json.dumps(summary, indent=2) + "\n"
    )


def main():
    """完整验证一次；大型临时网表自动清理，仅提交日志和资源汇总。"""
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    versions = {}
    for name, args in (
        ("iverilog", ["-V"]),
        ("vvp", ["-V"]),
        ("yowasp-yosys", ["-V"]),
    ):
        if not shutil.which(name):
            raise RuntimeError(f"缺少工具 {name}，请先配置项目环境")
        result = execute([name] + args)
        versions[name] = result.stdout + result.stderr
    (EVIDENCE / "validation_versions.json").write_text(
        json.dumps(versions, indent=2) + "\n"
    )
    with tempfile.TemporaryDirectory(prefix="aichip_validate_") as directory:
        simulation_checks(Path(directory))
        synthesis_checks(Path(directory))
    print("PASS: 无复位重启、损坏参考故障注入、LANES=1/4/16 综合与乘法器计数")


if __name__ == "__main__":
    main()
