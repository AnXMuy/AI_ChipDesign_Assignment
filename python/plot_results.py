import argparse
import csv
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

def main() -> None:
    parser = argparse.ArgumentParser(); parser.add_argument("--summary", default="results/summary.csv"); parser.add_argument("--out", default="report/figs")
    args = parser.parse_args(); out = Path(args.out); out.mkdir(parents=True, exist_ok=True)
    with Path(args.summary).open(newline="") as handle: rows = list(csv.DictReader(handle))
    if not rows: return
    labels = [row["cfg"] for row in rows]
    def chart(filename, values, ylabel):
        plt.figure(); plt.bar(labels, values); plt.ylabel(ylabel); plt.xticks(rotation=30); plt.tight_layout(); plt.savefig(out / filename); plt.close()
    chart("parallel_cycles.png", [float(row["P_KN"]) for row in rows], "P_KN")
    chart("conv_params_output.png", [float(row["OH"]) * float(row["OW"]) for row in rows], "output pixels")
    chart("acc_width_compare.png", [float(row["ACC_WIDTH"]) for row in rows], "ACC_WIDTH")

if __name__ == "__main__": main()
