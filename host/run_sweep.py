"""Sweep matrix size on the FPGA and record the cycle counts it reports.

    pip install pyserial
    python host/run_sweep.py COM4
    python host/run_sweep.py COM4 --reps 20 --csv bench/results_fpga.csv

Each run sends T, then A and B, and reads back the FPGA's own cycle count
followed by C in tile order. Results are checked against the golden model, so a
timing number is only recorded if the hardware got the answer right.

The cycle count is the number worth having: it is measured on the FPGA, exact
to one clock, and excludes the UART entirely -- the honest counterpart to the
GPU's kernel time. Wall-clock round trip is recorded too, and the gap between
them is the whole I/O-bound story.
"""

from __future__ import annotations

import argparse
import csv
import random
import statistics
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "model"))

from matmul_model import wrap_signed  # noqa: E402

try:
    import serial
except ImportError:
    sys.exit("pyserial not installed:  pip install pyserial")

K = 8
ACC_W = 48
ACC_BYTES = ACC_W // 8
CLK_HZ = 100e6


def pack(mat, n):
    out = bytearray()
    for row in mat:
        for v in row:
            out += (v & 0xFFFF).to_bytes(2, "big")
    return bytes(out)


def reference(a, b, n):
    c = [[0] * n for _ in range(n)]
    for i in range(n):
        for j in range(n):
            acc = 0
            for k in range(n):
                acc += a[i][k] * b[k][j]
            c[i][j] = wrap_signed(acc, ACC_W)
    return c


def unpack_tiles(raw, n, t):
    """Undo the tile-order stream back into a row-major matrix."""
    c = [[0] * n for _ in range(n)]
    idx = 0
    for ti in range(t):
        for tj in range(t):
            for r in range(K):
                for col in range(K):
                    v = int.from_bytes(raw[idx*ACC_BYTES:(idx+1)*ACC_BYTES], "big")
                    if v & (1 << (ACC_W - 1)):
                        v -= 1 << ACC_W
                    c[ti*K + r][tj*K + col] = v
                    idx += 1
    return c


def one_run(port, t, rng):
    n = K * t
    a = [[rng.randint(-1000, 1000) for _ in range(n)] for _ in range(n)]
    b = [[rng.randint(-1000, 1000) for _ in range(n)] for _ in range(n)]

    port.reset_input_buffer()
    payload = bytes([t]) + pack(a, n) + pack(b, n)
    expect = n * n * ACC_BYTES + 4

    t0 = time.perf_counter()
    port.write(payload)
    raw = port.read(expect)
    wall = time.perf_counter() - t0

    if len(raw) != expect:
        raise TimeoutError(f"T={t}: got {len(raw)} bytes, expected {expect}")

    # Results stream out while the multiply is still running, so the cycle
    # count can only be sent once everything else has gone.
    cycles = int.from_bytes(raw[-4:], "big")
    got = unpack_tiles(raw[:-4], n, t)
    ok = (got == reference(a, b, n))
    return cycles, wall, ok


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("port")
    ap.add_argument("--baud", type=int, default=1_000_000)
    ap.add_argument("--tiles", type=int, nargs="+", default=[1, 2, 4, 8])
    ap.add_argument("--reps", type=int, default=10)
    ap.add_argument("--seed", type=int, default=3)
    ap.add_argument("--csv", default="bench/results_fpga.csv")
    args = ap.parse_args()

    rng = random.Random(args.seed)
    rows = []

    print(f"opening {args.port} at {args.baud} baud")
    print(f"{'T':>3} {'N':>5} {'cycles':>9} {'compute_us':>11} "
          f"{'wall_ms':>9} {'idle%':>8}  check")

    with serial.Serial(args.port, args.baud, timeout=15.0) as port:
        time.sleep(0.2)
        port.reset_input_buffer()

        for t in args.tiles:
            n = K * t
            cyc_list, wall_list, all_ok = [], [], True
            for _ in range(args.reps):
                cycles, wall, ok = one_run(port, t, rng)
                cyc_list.append(cycles)
                wall_list.append(wall)
                all_ok &= ok

            cyc = statistics.median(cyc_list)
            wall = statistics.median(wall_list)
            compute_us = cyc / CLK_HZ * 1e6
            idle = 100.0 * (1.0 - (compute_us * 1e-6) / wall)

            spread = max(cyc_list) - min(cyc_list)
            print(f"{t:3d} {n:5d} {int(cyc):9d} {compute_us:11.2f} "
                  f"{wall*1e3:9.2f} {idle:7.3f}%  "
                  f"{'ok' if all_ok else 'WRONG'}"
                  f"{'' if spread == 0 else f'  (cycle spread {spread})'}")

            rows.append({
                "t": t, "n": n, "cycles": int(cyc),
                "compute_us": round(compute_us, 3),
                "wall_ms": round(wall * 1e3, 3),
                "cycle_spread": spread,
                "correct": int(all_ok),
            })

    out = Path(args.csv)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print(f"\nwrote {out}")

    if all(r["cycle_spread"] == 0 for r in rows):
        print("cycle counts identical across every repetition -- zero jitter")


if __name__ == "__main__":
    main()
