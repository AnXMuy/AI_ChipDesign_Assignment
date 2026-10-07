import argparse
import json
from pathlib import Path
import numpy as np
from config import get_config, meta_from_cfg


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    parser.add_argument("--out-root", default="data")
    args = parser.parse_args()
    cfg = get_config(args.config)
    out_dir = Path(args.out_root) / args.config
    out_dir.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(cfg["SEED"])
    x = rng.integers(-8, 8, size=(cfg["H"], cfg["W"], cfg["C"]), dtype=np.int8)
    w = rng.integers(-8, 8, size=(cfg["KN"], cfg["KH"], cfg["KW"], cfg["KC"]), dtype=np.int8)
    x.tofile(out_dir / "input.bin")
    w.tofile(out_dir / "weight.bin")
    (out_dir / "meta.json").write_text(json.dumps(meta_from_cfg(cfg), indent=2), encoding="utf-8")
    print(f"generated {out_dir}: input={x.shape}, weight={w.shape}")


if __name__ == "__main__":
    main()
