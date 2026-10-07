import argparse
import csv
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description="生成并行度实验对比表")
    parser.add_argument("--summary", default="results/summary.csv")
    parser.add_argument("--out", default="results/parallel_summary.md")
    args = parser.parse_args()
    with Path(args.summary).open(newline="") as handle:
        rows = list(csv.DictReader(handle))
    rows = [row for row in rows if row["cfg"] in {"parallel_2x", "parallel_4x", "parallel_8x", "parallel_16x"}]
    rows.sort(key=lambda row: int(row["P_KN"]))
    lines = ["# 并行度实验结果", "", "| 配置 | 输出通道并行度 | 输入通道并行度 | 仿真周期数 | 误码数 |", "|---|---:|---:|---:|---:|"]
    for row in rows:
        lines.append(f"| {row['cfg']} | {row['P_KN']} | {row['P_C']} | {row['cycles']} | {row['num_err']} |")
    Path(args.out).write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
