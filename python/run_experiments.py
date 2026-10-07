import argparse
import csv
import re
import subprocess
import sys
from pathlib import Path
from config import get_config, list_experiments, derive_geometry

ROOT = Path(__file__).resolve().parents[1]
FIELDS = ["cfg", "H", "W", "C", "KN", "KH", "KW", "KC", "STRIDE", "PAD", "P_KN", "P_KH", "P_KW", "P_C", "ACC_WIDTH", "OUT_WIDTH", "QUANT_MODE", "OH", "OW", "cycles", "num_err", "err_rate", "max_abs_err", "tb_errors"]


def sim_summary(log_path: Path):
    if not log_path.exists():
        return "not_run", "not_run"
    text = log_path.read_text(encoding="utf-8", errors="replace")
    match = re.search(r"TB_SUMMARY .*? cycles=([0-9]+) errors=([0-9]+)", text)
    if not match:
        return "not_found", "not_found"
    return int(match.group(1)), int(match.group(2))


def main() -> None:
    parser = argparse.ArgumentParser(description="运行全部配置实验")
    parser.add_argument("--only")
    parser.add_argument("--skip-sim", action="store_true")
    args = parser.parse_args()
    names = args.only.split(",") if args.only else list_experiments()
    rows = []
    for name in names:
        cfg = get_config(name); geometry = derive_geometry(cfg)
        subprocess.run([sys.executable, str(ROOT / "python/gen_data.py"), "--config", name], check=True)
        subprocess.run([sys.executable, str(ROOT / "python/run_golden.py"), "--config", name], check=True)
        result_dir = ROOT / "results" / name; result_dir.mkdir(parents=True, exist_ok=True)
        rtl_path = result_dir / "rtl_output.bin"
        if not args.skip_sim:
            subprocess.run(["vsim", "-c", "-do", f"do scripts/run_sim.tcl {name}"], cwd=ROOT, check=True)
        if rtl_path.exists():
            result = subprocess.run([sys.executable, str(ROOT / "python/compare.py"), "--cfg", name, "--rtl", str(rtl_path)], cwd=ROOT)
            compare = {"num_err": 0 if result.returncode == 0 else "nonzero", "err_rate": 0 if result.returncode == 0 else "unknown", "max_abs_err": 0 if result.returncode == 0 else "unknown"}
        else:
            compare = {"num_err": "not_run", "err_rate": "not_run", "max_abs_err": "not_run"}
        cycles, tb_errors = sim_summary(result_dir / "sim.log")
        rows.append({"cfg": name, **{key: cfg[key] for key in FIELDS[1:17]}, "OH": geometry["OH"], "OW": geometry["OW"], "cycles": cycles, "tb_errors": tb_errors, **compare})
    summary = ROOT / "results" / "summary.csv"; summary.parent.mkdir(exist_ok=True)
    with summary.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS); writer.writeheader(); writer.writerows(rows)
    print(f"已写入 {summary}")


if __name__ == "__main__": main()
