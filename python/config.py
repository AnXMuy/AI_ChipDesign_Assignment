from copy import deepcopy

BASE = {
    "H": 256, "W": 256, "C": 16, "KN": 32,
    "KH": 3, "KW": 3, "KC": 16,
    "STRIDE": 1, "PAD": 1,
    "P_KN": 8, "P_KH": 3, "P_KW": 3, "P_C": 4,
    "ACC_WIDTH": 32, "OUT_WIDTH": 8,
    "QUANT_MODE": "saturate", "SEED": 42,
}

EXPERIMENTS = {
    "baseline": {},
    "small_smoke": {"H": 8, "W": 8, "C": 4, "KN": 4, "KC": 4, "P_KN": 2, "P_C": 2},
    "parallel_low": {"H": 16, "W": 16, "C": 8, "KN": 16, "KC": 8, "P_KN": 4, "P_C": 2},
    "parallel_high": {"H": 16, "W": 16, "C": 8, "KN": 16, "KC": 8, "P_KN": 8, "P_C": 4},
    "stride2_pad0": {"H": 16, "W": 16, "C": 8, "KN": 8, "KC": 8, "STRIDE": 2, "PAD": 0, "P_KN": 4, "P_C": 2},
    "kernel5": {"H": 16, "W": 16, "C": 8, "KN": 8, "KC": 8, "KH": 5, "KW": 5, "P_KN": 4, "P_KH": 1, "P_KW": 1, "P_C": 2},
    "acc24": {"H": 16, "W": 16, "C": 8, "KN": 8, "KC": 8, "ACC_WIDTH": 24, "P_KN": 4, "P_C": 2},
}


def get_config(name: str) -> dict:
    if name not in EXPERIMENTS:
        raise KeyError(f"unknown config: {name}; choose from {list_experiments()}")
    cfg = deepcopy(BASE)
    cfg.update(EXPERIMENTS[name])
    validate_config(cfg)
    cfg["NAME"] = name
    return cfg


def list_experiments() -> list[str]:
    return list(EXPERIMENTS)


def derive_geometry(cfg: dict) -> dict:
    oh = (cfg["H"] + 2 * cfg["PAD"] - cfg["KH"]) // cfg["STRIDE"] + 1
    ow = (cfg["W"] + 2 * cfg["PAD"] - cfg["KW"]) // cfg["STRIDE"] + 1
    if oh <= 0 or ow <= 0:
        raise ValueError("kernel/padding/stride produce an empty output")
    return {"OH": oh, "OW": ow}


def meta_from_cfg(cfg: dict) -> dict:
    result = deepcopy(cfg)
    result.update(derive_geometry(cfg))
    result.update({"input_dtype": "int8", "weight_dtype": "int8", "output_dtype": "int8", "acc_dtype": "int32", "byte_order": "little-endian", "layout": {"input": "H,W,C", "weight": "KN,KH,KW,KC", "output": "OH,OW,KN"}})
    return result


def validate_config(cfg: dict) -> None:
    for key in ("H", "W", "C", "KN", "KH", "KW", "KC", "STRIDE", "P_KN", "P_KH", "P_KW", "P_C", "ACC_WIDTH"):
        if cfg[key] <= 0:
            raise ValueError(f"{key} must be positive")
    if cfg["KC"] != cfg["C"]:
        raise ValueError("KC must equal C for this assignment")
    if cfg["KH"] not in (1, 3, 5) or cfg["KW"] not in (1, 3, 5):
        raise ValueError("KH and KW must be 1, 3, or 5")
    if cfg["P_KN"] > cfg["KN"] or cfg["P_KH"] > cfg["KH"] or cfg["P_KW"] > cfg["KW"] or cfg["P_C"] > cfg["C"]:
        raise ValueError("parallelism cannot exceed the corresponding dimension")
    if cfg["QUANT_MODE"] not in ("saturate", "truncate"):
        raise ValueError("QUANT_MODE must be saturate or truncate")
