import argparse
import json
from pathlib import Path
import numpy as np
from config import get_config
from golden_conv import conv2d_int8


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    parser.add_argument("--data-root", default="data")
    args = parser.parse_args()
    cfg = get_config(args.config)
    data_dir = Path(args.data_root) / args.config
    x = np.fromfile(data_dir / "input.bin", dtype=np.int8).reshape(cfg["H"], cfg["W"], cfg["C"])
    w = np.fromfile(data_dir / "weight.bin", dtype=np.int8).reshape(cfg["KN"], cfg["KH"], cfg["KW"], cfg["KC"])
    out, acc = conv2d_int8(x, w, cfg["STRIDE"], cfg["PAD"], cfg["QUANT_MODE"], cfg["ACC_WIDTH"])
    out.tofile(data_dir / "expected.bin")
    acc.tofile(data_dir / "expected_int32.bin")
    print(f"{args.config}: output={out.shape}, min={out.min()}, max={out.max()}, mean={out.mean():.3f}")


if __name__ == "__main__":
    main()
