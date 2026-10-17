"""从实测指标和 RTL 输出生成数值图表，汇集日志与真实 VCD。"""

import json
import os
import shutil
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
os.environ.setdefault("MPLCONFIGDIR", str(ROOT / ".cache/matplotlib"))
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from experiment import read_hex


def main():
    """汇集机器结果与波形，输出可提交的证据目录。"""
    evidence = ROOT / "results/evidence"
    figures = ROOT / "report/figures"
    evidence.mkdir(parents=True, exist_ok=True)
    figures.mkdir(parents=True, exist_ok=True)
    rows = json.loads((ROOT / "results/summary.json").read_text())
    for name in ["summary.json", "environment.json"]:
        shutil.copy2(ROOT / "results" / name, evidence / name)
    for path in (ROOT / "results").glob("*/data/metadata.json"):
        shutil.copy2(path, evidence / (path.parent.parent.name + "_data.json"))
    for path in (ROOT / "results").glob("*/lanes*/simulation.log"):
        shutil.copy2(
            path,
            evidence
            / (path.parent.parent.name + "_" + path.parent.name + ".log"),
        )
    wave = ROOT / "results/small/lanes16/wave.vcd"
    if wave.exists():
        shutil.copy2(wave, evidence / "wave.vcd")
    parallel = sorted(
        [r for r in rows if r["case"] == "small"], key=lambda r: r["lanes"]
    )
    if parallel:
        fig, axes = plt.subplots(1, 2, figsize=(10, 4))
        labels = [str(r["lanes"]) for r in parallel]
        axes[0].bar(labels, [r["cycles"] for r in parallel], color="#176b87")
        axes[0].set_ylabel("Measured cycles")
        axes[1].bar(
            labels, [r["cycle_speedup"] or 1 for r in parallel], color="#dd8452"
        )
        axes[1].set_ylabel("Measured cycle speedup")
        for axis in axes:
            axis.set_xlabel("Parallel input-channel multipliers (LANES)")
            axis.spines[["top", "right"]].set_visible(False)
        fig.suptitle("8 x 8 x 16 input, 32 output channels, 3 x 3 convolution")
        fig.tight_layout()
        fig.savefig(figures / "parallel_speedup.png", dpi=180)
        plt.close(fig)
    full = sorted(
        [r for r in rows if r["case"] == "full"], key=lambda r: r["lanes"]
    )
    if full:
        data = ROOT / "results/full/data"
        golden = np.load(data / "golden.npy")
        output = read_hex(
            ROOT / f"results/full/lanes{full[-1]['lanes']}/output.hex",
            golden.shape,
        )
        fig, axes = plt.subplots(1, 3, figsize=(11, 3.5))
        for axis, array, title in zip(
            axes,
            [
                golden[:, :, 0],
                output[:, :, 0],
                np.abs(
                    output[:, :, 0].astype(int) - golden[:, :, 0].astype(int)
                ),
            ],
            [
                "Python reference, channel 0",
                "RTL output, channel 0",
                "Absolute error",
            ],
        ):
            image = axis.imshow(
                array,
                cmap="coolwarm" if title != "Absolute error" else "viridis",
                vmin=-128 if title != "Absolute error" else 0,
                vmax=127 if title != "Absolute error" else 1,
            )
            axis.set_title(title, fontsize=10)
            fig.colorbar(image, ax=axis, fraction=0.046)
        fig.tight_layout()
        fig.savefig(figures / "output_comparison.png", dpi=180)
        plt.close(fig)
    table = [
        "| 配置 | LANES | 输出值数 | 周期数 | 周期加速比 | 错误数 | 仿真墙钟/s |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for row in rows:
        speedup = row["cycle_speedup"]
        speedup_text = f"{speedup:.3f}" if speedup else "—"
        table.append(
            f"| {row['case']} | {row['lanes']} | {row['output_count']:,} | {row['cycles']:,} | {speedup_text} | {row['mismatches']} | {row['simulation_seconds']:.3f} |"
        )
    (evidence / "results_table.md").write_text("\n".join(table) + "\n")


if __name__ == "__main__":
    main()
