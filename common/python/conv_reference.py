"""Small, dependency-light NHWC int8 convolution reference model."""
from __future__ import annotations

import numpy as np


def conv2d_int8_nhwc(
    x: np.ndarray,
    w: np.ndarray,
    bias: np.ndarray | None = None,
    stride: int = 1,
    padding: int = 1,
) -> np.ndarray:
    """Compute NHWC x HWIO convolution with int32 accumulation and int8 output."""
    x = np.asarray(x, dtype=np.int8)
    w = np.asarray(w, dtype=np.int8)
    if x.ndim != 3 or w.ndim != 4:
        raise ValueError("x must be HWC and w must be HWIO")
    h, width, channels = x.shape
    kh, kw, wc, outputs = w.shape
    if channels != wc or stride <= 0 or padding < 0:
        raise ValueError("incompatible dimensions or convolution parameters")
    if bias is None:
        bias = np.zeros(outputs, dtype=np.int32)
    bias = np.asarray(bias, dtype=np.int32)
    if bias.shape != (outputs,):
        raise ValueError("bias must have shape (output_channels,)")
    padded = np.pad(x, ((padding, padding), (padding, padding), (0, 0)))
    oh = (h + 2 * padding - kh) // stride + 1
    ow = (width + 2 * padding - kw) // stride + 1
    acc = np.empty((oh, ow, outputs), dtype=np.int32)
    for oy in range(oh):
        for ox in range(ow):
            window = padded[oy * stride : oy * stride + kh, ox * stride : ox * stride + kw]
            acc[oy, ox] = np.sum(window.astype(np.int32)[..., None] * w.astype(np.int32), axis=(0, 1, 2)) + bias
    return np.clip(acc, -128, 127).astype(np.int8)

