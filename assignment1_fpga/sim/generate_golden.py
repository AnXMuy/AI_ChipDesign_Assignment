import argparse
from pathlib import Path
import numpy as np

from common.python.conv_reference import conv2d_int8_nhwc


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--height', type=int, default=8)
    p.add_argument('--width', type=int, default=8)
    p.add_argument('--channels', type=int, default=4)
    p.add_argument('--outputs', type=int, default=4)
    p.add_argument('--out', type=Path, default=Path('golden'))
    args = p.parse_args()
    rng = np.random.default_rng(2026)
    x = rng.integers(-4, 5, size=(args.height, args.width, args.channels), dtype=np.int8)
    w = rng.integers(-3, 4, size=(3, 3, args.channels, args.outputs), dtype=np.int8)
    b = rng.integers(-32, 33, size=args.outputs, dtype=np.int32)
    y = conv2d_int8_nhwc(x, w, b)
    args.out.mkdir(parents=True, exist_ok=True)
    np.save(args.out / 'input.npy', x); np.save(args.out / 'weight.npy', w)
    np.save(args.out / 'bias.npy', b); np.save(args.out / 'golden.npy', y)
    def write_hex(path, values, bits):
        mask = (1 << bits) - 1
        with path.open('w') as f:
            for value in np.asarray(values).reshape(-1):
                f.write(f'{int(value) & mask:0{bits // 4}x}\n')
    write_hex(args.out / 'input.hex', x, 8)
    write_hex(args.out / 'weight.hex', w, 8)
    write_hex(args.out / 'bias.hex', b, 32)
    write_hex(args.out / 'golden.hex', y, 8)


if __name__ == '__main__':
    main()
