import argparse
import csv
import subprocess
import sys
from pathlib import Path
from config import get_config, list_experiments, derive_geometry

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only")
    parser.add_argument("--skip-sim", action="store_true")
    args = parser.parse_args()
    names = args.only.split(",") if args.only else list_experiments()
    rows = []
    for name in names:
        cfg = get_config(name); geometry = derive_geometry(cfg)
        subprocess.run([sys.executable, str(ROOT / "python/gen_data.py"), "--config", name], check=True)
        subprocess.run([sys.executable, str(ROOT / "python/run_golden.py"), "--config", name], check=True)
        rtl_path = ROOT / "results" / name / "rtl_output.bin"
        if not args.skip_sim:
            subprocess.run(["vsim", "-c", "-do", f"do scripts/run_sim.tcl {name}"], cwd=ROOT, check=True)
        if rtl_path.exists():
            comparison = subprocess.run([sys.executable, str(ROOT / "python/compare.py"), "--cfg", name, "--rtl", str(rtl_path)], cwd=ROOT)
            compare_values = {"num_err": "0" if comparison.returncode == 0 else "nonzero", "err_rate": "0" if comparison.returncode == 0 else "unknown", "max_abs_err": "0" if comparison.returncode == 0 else "unknown"}
        else:
            compare_values = {"num_err": "not_run", "err_rate": "not_run", "max_abs_err": "not_run"}
        row = {**{key: cfg[key] for key in ("H","W","C","KN","KH","KW","KC","STRIDE","PAD","P_KN","P_KH","P_KW","P_C","ACC_WIDTH")}, "cfg": name, "OH": geometry["OH"], "OW": geometry["OW"], **compare_values, "cycles": "see sim.log", "sim_time_s": "see sim.log"}
        rows.append(row)
    Path(ROOT / "results").mkdir(exist_ok=True)
    fields = list(rows[0]) if rows else ["cfg"]
    with (ROOT / "results/summary.csv").open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields); writer.writeheader(); writer.writerows(rows)


if __name__ == "__main__":
    main()
