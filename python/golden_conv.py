from __future__ import annotations

import numpy as np


def _wrap_signed(value: np.ndarray, width: int) -> np.ndarray:
    mask = (1 << width) - 1
    return ((value.astype(np.int64) & mask) ^ (1 << (width - 1))) - (1 << (width - 1))


def conv2d_int8(x: np.ndarray, w: np.ndarray, stride: int, pad: int, quant_mode: str, acc_width: int):
    h, width, channels = x.shape
    kn, kh, kw, kc = w.shape
    if channels != kc:
        raise ValueError("input and weight channel dimensions differ")
    oh = (h + 2 * pad - kh) // stride + 1
    ow = (width + 2 * pad - kw) // stride + 1
    padded = np.pad(x.astype(np.int64), ((pad, pad), (pad, pad), (0, 0)))
    windows = np.lib.stride_tricks.sliding_window_view(padded, (kh, kw), axis=(0, 1))
    windows = windows[::stride, ::stride]
    windows = np.transpose(windows, (0, 1, 3, 4, 2))
    acc = np.einsum("oykxc,nkxc->oyn", windows, w.astype(np.int64), optimize=True)
    acc = _wrap_signed(acc, acc_width)
    if quant_mode == "saturate":
        out = np.clip(acc, -128, 127)
    elif quant_mode == "truncate":
        out = _wrap_signed(acc, 8)
    else:
        raise ValueError(f"unsupported quant mode: {quant_mode}")
    return out.astype(np.int8), acc.astype(np.int32)


if __name__ == "__main__":
    x = np.arange(16, dtype=np.int8).reshape(4, 4, 1)
    w = np.ones((1, 3, 3, 1), dtype=np.int8)
    out, acc = conv2d_int8(x, w, stride=1, pad=1, quant_mode="saturate", acc_width=32)
    assert out.shape == (4, 4, 1)
    assert int(acc[1, 1, 0]) == 45
    print("golden_conv self-test passed")
