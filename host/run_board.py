"""Drive the FPGA accelerator over the USB-UART and check it against the model.

    pip install pyserial
    python host/run_board.py COM5              # Windows
    python host/run_board.py /dev/ttyUSB1      # Linux

    python host/run_board.py COM5 --cases 100  # more random matrices
    python host/run_board.py COM5 --latency    # timing histogram

Protocol matches src/matmul_uart.sv: send 4*K*K bytes (A then B, row-major,
16-bit signed, high byte first), read back K*K*ACC_BYTES bytes (C row-major,
sign-extended, high byte first).
"""

from __future__ import annotations

import argparse
import random
import statistics
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "model"))

from matmul_model import Config, identity, matmul, random_matrix  # noqa: E402

try:
    import serial
except ImportError:
    sys.exit("pyserial not installed:  pip install pyserial")


def pack_operands(a, b, cfg: Config) -> bytes:
    out = bytearray()
    for m in (a, b):
        for row in m:
            for v in row:
                out += (v & 0xFFFF).to_bytes(2, "big")
    return bytes(out)


def unpack_results(raw: bytes, cfg: Config):
    nbytes = (cfg.acc_w + 7) // 8
    bits = nbytes * 8
    out = []
    for i in range(cfg.k * cfg.k):
        v = int.from_bytes(raw[i*nbytes:(i+1)*nbytes], "big")
        if v & (1 << (bits - 1)):
            v -= 1 << bits
        out.append(v)
    return [out[r*cfg.k:(r+1)*cfg.k] for r in range(cfg.k)]


def one_run(port, a, b, cfg: Config):
    nbytes = (cfg.acc_w + 7) // 8
    expect = cfg.k * cfg.k * nbytes

    port.reset_input_buffer()
    t0 = time.perf_counter()
    port.write(pack_operands(a, b, cfg))
    raw = port.read(expect)
    elapsed = time.perf_counter() - t0

    if len(raw) != expect:
        raise TimeoutError(f"got {len(raw)} bytes, expected {expect}")
    return unpack_results(raw, cfg), elapsed


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("port")
    ap.add_argument("--baud", type=int, default=1_000_000)
    ap.add_argument("--k", type=int, default=8)
    ap.add_argument("--cases", type=int, default=20)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--latency", action="store_true",
                    help="report round-trip timing statistics")
    args = ap.parse_args()

    cfg = Config(k=args.k)
    rng = random.Random(args.seed)

    print(f"{cfg.describe()}")
    print(f"opening {args.port} at {args.baud} baud")

    with serial.Serial(args.port, args.baud, timeout=3.0) as port:
        time.sleep(0.2)
        port.reset_input_buffer()

        cases = [("identity", identity(cfg), random_matrix(cfg, rng))]
        for n in range(args.cases):
            cases.append((f"random_{n}", random_matrix(cfg, rng),
                          random_matrix(cfg, rng)))

        times, failures = [], 0

        for name, a, b in cases:
            got, elapsed = one_run(port, a, b, cfg)
            want = matmul(a, b, cfg)
            times.append(elapsed)

            if got != want:
                failures += 1
                print(f"  FAIL {name}")
                for i in range(cfg.k):
                    if got[i] != want[i]:
                        print(f"    row {i} got  {got[i]}")
                        print(f"          want {want[i]}")
                if failures >= 3:
                    break

        print("")
        if failures == 0:
            print(f"PASS: {len(cases)}/{len(cases)} matrices matched the model")
        else:
            print(f"FAIL: {failures}/{len(cases)} matrices wrong")

        if args.latency and times:
            ms = [t * 1e3 for t in times]
            print("")
            print(f"round trip over {len(ms)} runs (dominated by the UART, not"
                  f" the array):")
            print(f"  min    {min(ms):.3f} ms")
            print(f"  median {statistics.median(ms):.3f} ms")
            print(f"  max    {max(ms):.3f} ms")
            cycles = 3 * cfg.k - 2
            print(f"  array compute time is {cycles} cycles = "
                  f"{cycles * 10:.0f} ns of that")

    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
