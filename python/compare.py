import argparse
import csv
from pathlib import Path
import numpy as np
from config import get_config, derive_geometry


def compare(expected_path, rtl_path, out_dir, tag, shape):
    expected = np.fromfile(expected_path, dtype=np.int8)
    actual = np.fromfile(rtl_path, dtype=np.int8)
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    if expected.size != actual.size:
        result = {"tag": tag, "expected_size": expected.size, "rtl_size": actual.size, "num_err": -1, "err_rate": 1.0, "max_abs_err": -1, "first_error": "size mismatch"}
    else:
        diff = actual.astype(np.int16) - expected.astype(np.int16)
        errors = np.flatnonzero(diff)
        first = tuple(np.unravel_index(errors[0], shape)) if errors.size else "none"
        result = {"tag": tag, "expected_size": expected.size, "rtl_size": actual.size, "num_err": int(errors.size), "err_rate": float(errors.size / expected.size), "max_abs_err": int(np.max(np.abs(diff))) if diff.size else 0, "first_error": str(first)}
        np.savetxt(out_dir / "err_hist.csv", diff, delimiter=",", fmt="%d")
    with (out_dir / "compare.csv").open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=result)
        writer.writeheader(); writer.writerow(result)
    (out_dir / "compare.txt").write_text("\n".join(f"{key}: {value}" for key, value in result.items()) + "\n", encoding="utf-8")
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cfg", required=True)
    parser.add_argument("--rtl", required=True)
    parser.add_argument("--data-root", default="data")
    parser.add_argument("--out-root", default="results")
    args = parser.parse_args()
    cfg = get_config(args.cfg); geometry = derive_geometry(cfg)
    result = compare(Path(args.data_root) / args.cfg / "expected.bin", args.rtl, Path(args.out_root) / args.cfg, args.cfg, (geometry["OH"], geometry["OW"], cfg["KN"]))
    raise SystemExit(0 if result["num_err"] == 0 else 1)


if __name__ == "__main__":
    main()
