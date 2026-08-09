"""Cycle-accurate model of the systolic RTL, used to check the timing math.

This mirrors the structure of src/*.sv register for register -- the skew
pipeline, the PE pass-through registers, and the FSM counter -- so it catches
off-by-one errors in the injection schedule and the LAST = 3K-3 derivation
without needing a Verilog simulator.

It is a design aid, not a substitute for tb/. The real testbench runs the
actual RTL against vectors from matmul_model.

    python model/sim_array.py
"""

from __future__ import annotations

import random

from matmul_model import Config, matmul, random_matrix, wrap_signed


class SkewBuffer:
    """Lane i delayed by i cycles. Lane 0 is combinational passthrough."""

    def __init__(self, k: int):
        self.k = k
        self.pipe = [[0] * k for _ in range(k)]

    def out(self, inp: list[int]) -> list[int]:
        return [inp[0] if lane == 0 else self.pipe[lane][lane - 1]
                for lane in range(self.k)]

    def tick(self, inp: list[int], clr: bool) -> None:
        for lane in range(self.k):
            if clr:
                self.pipe[lane] = [0] * self.k
            else:
                self.pipe[lane] = [inp[lane]] + self.pipe[lane][:-1]


class Array:
    """K x K mesh of PEs with registered operand pass-through."""

    def __init__(self, cfg: Config):
        k = cfg.k
        self.cfg = cfg
        self.a_h = [[0] * (k + 1) for _ in range(k)]
        self.b_v = [[0] * k for _ in range(k + 1)]
        self.acc = [[0] * k for _ in range(k)]

    def tick(self, a_in: list[int], b_in: list[int], clr: bool) -> None:
        k = self.cfg.k
        for i in range(k):
            self.a_h[i][0] = a_in[i]
        for j in range(k):
            self.b_v[0][j] = b_in[j]

        next_a = [row[:] for row in self.a_h]
        next_b = [row[:] for row in self.b_v]
        next_acc = [row[:] for row in self.acc]

        for i in range(k):
            for j in range(k):
                a, b = self.a_h[i][j], self.b_v[i][j]
                next_a[i][j + 1] = a
                next_b[i + 1][j] = b
                next_acc[i][j] = 0 if clr else wrap_signed(
                    self.acc[i][j] + a * b, self.cfg.acc_w)

        self.a_h, self.b_v, self.acc = next_a, next_b, next_acc


def run_case(a, b, cfg: Config):
    """Drive one matrix pair through the model, returning (C, cycles_in_run)."""
    k = cfg.k
    last = 3 * k - 3

    skew_a, skew_b = SkewBuffer(k), SkewBuffer(k)
    array = Array(cfg)

    for _ in range(3):
        skew_a.tick([0] * k, True)
        skew_b.tick([0] * k, True)
        array.tick([0] * k, [0] * k, True)

    for cnt in range(last + 1):
        if cnt < k:
            a_feed = [a[i][cnt] for i in range(k)]
            b_feed = [b[cnt][j] for j in range(k)]
        else:
            a_feed = [0] * k
            b_feed = [0] * k

        a_sk = skew_a.out(a_feed)
        b_sk = skew_b.out(b_feed)

        array.tick(a_sk, b_sk, False)
        skew_a.tick(a_feed, False)
        skew_b.tick(b_feed, False)

    return array.acc, last + 1


def main() -> None:
    rng = random.Random(0xBEEF)
    total = 0

    for k in (2, 4, 8):
        cfg = Config(k=k)
        for n in range(200):
            a = random_matrix(cfg, rng)
            b = random_matrix(cfg, rng)
            got, cycles = run_case(a, b, cfg)
            want = matmul(a, b, cfg)
            if got != want:
                print(f"MISMATCH K={k} case {n}")
                for i in range(k):
                    print(f"  row {i}: got {got[i]}")
                    print(f"         want {want[i]}")
                raise SystemExit(1)
            total += 1
        print(f"K={k:2d}  200/200 match   run length {cycles} cycles "
              f"(3K-3 = {3*k-3}, results stable the cycle after)")

    ident = [[1 if i == j else 0 for j in range(8)] for i in range(8)]
    cfg8 = Config(k=8)
    b = random_matrix(cfg8, rng)
    got, _ = run_case(ident, b, cfg8)
    assert got == b, "identity through the array did not reproduce B"
    print("identity case reproduces B exactly -- skew alignment confirmed")

    print(f"\n{total} cases matched the golden model")


if __name__ == "__main__":
    main()
