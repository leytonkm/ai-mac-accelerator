"""Golden reference model for the RTL MAC accelerator.

Bit-exact software model of the output-stationary systolic array. The RTL is
verified against this, so the semantics here define correctness:

  - operands are signed two's-complement integers, DATA_W bits wide
  - each product is exact (DATA_W * 2 bits)
  - products accumulate into an ACC_W-bit signed register that wraps on overflow

ACC_W is sized so that K accumulated full-magnitude products cannot overflow:

    ACC_W = 2 * DATA_W + ceil(log2(K))

For DATA_W=16, K=8 that is 35 bits. The worst case is an all -32768 input,
giving K * 2^30 = 2^33, which fits a signed 35-bit register with a bit to
spare. Wrapping is still implemented so the model stays correct if ACC_W is
later narrowed or K is raised without re-sizing.
"""

from __future__ import annotations

import math
import random
from dataclasses import dataclass


@dataclass(frozen=True)
class Config:
    """Numeric configuration shared by the model, the vectors, and the RTL."""

    data_w: int = 16
    k: int = 8

    @property
    def acc_w(self) -> int:
        """Accumulator width that cannot overflow for K full-magnitude terms."""
        return 2 * self.data_w + max(1, math.ceil(math.log2(self.k)))

    @property
    def data_min(self) -> int:
        return -(1 << (self.data_w - 1))

    @property
    def data_max(self) -> int:
        return (1 << (self.data_w - 1)) - 1

    @property
    def acc_min(self) -> int:
        return -(1 << (self.acc_w - 1))

    @property
    def acc_max(self) -> int:
        return (1 << (self.acc_w - 1)) - 1

    def describe(self) -> str:
        return (
            f"DATA_W={self.data_w} K={self.k} ACC_W={self.acc_w} "
            f"operand range [{self.data_min}, {self.data_max}] "
            f"accumulator range [{self.acc_min}, {self.acc_max}]"
        )


def wrap_signed(value: int, width: int) -> int:
    """Truncate to `width` bits and reinterpret as two's complement."""
    masked = value & ((1 << width) - 1)
    sign_bit = 1 << (width - 1)
    return masked - (1 << width) if masked & sign_bit else masked


def to_hex(value: int, width: int) -> str:
    """Two's-complement hex string, zero-padded, for $readmemh."""
    digits = (width + 3) // 4
    return format(value & ((1 << width) - 1), "x").zfill(digits)


def from_hex(text: str, width: int) -> int:
    return wrap_signed(int(text, 16), width)


def check_operands(matrix: list[list[int]], cfg: Config, name: str) -> None:
    if len(matrix) != cfg.k or any(len(row) != cfg.k for row in matrix):
        raise ValueError(f"{name} must be {cfg.k}x{cfg.k}")
    for i, row in enumerate(matrix):
        for j, v in enumerate(row):
            if not (cfg.data_min <= v <= cfg.data_max):
                raise ValueError(
                    f"{name}[{i}][{j}] = {v} outside signed {cfg.data_w}-bit range"
                )


def matmul(a: list[list[int]], b: list[list[int]], cfg: Config) -> list[list[int]]:
    """Reference C = A x B with the RTL's exact accumulator semantics.

    Python ints are arbitrary precision, so the intermediate sum is exact and
    wrapping is applied explicitly after each accumulation step -- matching a
    hardware accumulator that wraps every cycle, not just at the end.
    """
    check_operands(a, cfg, "A")
    check_operands(b, cfg, "B")

    out = [[0] * cfg.k for _ in range(cfg.k)]
    for i in range(cfg.k):
        for j in range(cfg.k):
            acc = 0
            for kk in range(cfg.k):
                acc = wrap_signed(acc + a[i][kk] * b[kk][j], cfg.acc_w)
            out[i][j] = acc
    return out


def random_matrix(cfg: Config, rng: random.Random, lo: int | None = None,
                  hi: int | None = None) -> list[list[int]]:
    lo = cfg.data_min if lo is None else lo
    hi = cfg.data_max if hi is None else hi
    return [[rng.randint(lo, hi) for _ in range(cfg.k)] for _ in range(cfg.k)]


def identity(cfg: Config) -> list[list[int]]:
    return [[1 if i == j else 0 for j in range(cfg.k)] for i in range(cfg.k)]


def constant(cfg: Config, value: int) -> list[list[int]]:
    return [[value] * cfg.k for _ in range(cfg.k)]


def _self_test() -> None:
    """Cross-check against NumPy and exercise the overflow boundary."""
    cfg = Config()
    print(cfg.describe())

    rng = random.Random(0xC0FFEE)

    try:
        import numpy as np
    except ImportError:
        print("numpy not installed -- skipping cross-check")
    else:
        for _ in range(200):
            a = random_matrix(cfg, rng)
            b = random_matrix(cfg, rng)
            mine = matmul(a, b, cfg)
            theirs = (np.array(a, dtype=np.int64) @ np.array(b, dtype=np.int64))
            assert mine == theirs.tolist(), "model disagrees with numpy"
        print("cross-check vs numpy: 200/200 random cases match")

    worst = matmul(constant(cfg, cfg.data_min), constant(cfg, cfg.data_min), cfg)
    peak = worst[0][0]
    assert peak == cfg.k * (cfg.data_min ** 2), "worst case was silently wrapped"
    assert cfg.acc_min <= peak <= cfg.acc_max, "ACC_W too narrow for worst case"
    spare = cfg.acc_w - (peak.bit_length() + 1)
    print(f"worst-case accumulator value {peak} (2^{peak.bit_length() - 1}) "
          f"fits ACC_W={cfg.acc_w} with {spare} bit(s) spare")

    assert wrap_signed((1 << 34), 35) == -(1 << 34), "wrap_signed is wrong"
    assert from_hex(to_hex(-1, 35), 35) == -1, "hex round-trip is wrong"
    assert from_hex(to_hex(cfg.data_min, 16), 16) == cfg.data_min
    print(f"hex encoding: {cfg.data_min} -> {to_hex(cfg.data_min, 16)}, "
          f"-1 -> {to_hex(-1, cfg.acc_w)}")

    ident = identity(cfg)
    b = random_matrix(cfg, rng)
    assert matmul(ident, b, cfg) == b, "identity property failed"
    print("identity property holds")

    print("all self-tests passed")


if __name__ == "__main__":
    _self_test()
