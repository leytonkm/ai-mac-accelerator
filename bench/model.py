"""Crossover model, fitted to and checked against the hardware measurements.

    python bench/model.py                    # numbers only
    python bench/model.py --plot             # also write bench/crossover.png

Reads bench/results_fpga.csv (hardware sweep) and bench/results_gpu.csv
(CUDA baseline) when present.

The model
---------
The GPU pays a fixed cost per kernel launch regardless of problem size. The
FPGA pays a cost proportional to the work. So below some size the array
finishes before the GPU has finished starting.

The FPGA's cost was derived from the RTL and confirmed exactly against both
simulation and silicon at T = 1, 2, 4, 8:

    cycles(T) = 66*T^2 + 34*T^3          T = N/K

    34 cycles per tile-multiply  (x T^3): 9 load, 24 array round trip, 1 accum
    66 cycles per output tile    (x T^2): 64 to stream the tile out, 2 control

An earlier version of this file used N^3/(K^2 f), which assumes back-to-back
tile streaming with no load or emit overhead. That underestimates by ~4.5x at
T=1 and put the crossover at N=38 instead of the measured ~19. The optimistic
form is kept below as `t_fpga_ideal` for the achieved-vs-attainable comparison,
but the crossover uses the real one.
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# Measured on the Urbana board, XC7S50, 2026-08-08.
K           = 8
F_HZ        = 100e6
FMAX_HZ     = 115.7e6       # 1/(10ns - 1.355ns WNS)
DSP_USED    = 64
FF_USED     = 6000
ARRAY_ONLY  = 220e-9        # bare 8x8 array, 22 cycles, no tiling overhead
UART_BAUD   = 1e6

# Measured empty-kernel launch + sync on the RTX 4070 Laptop GPU.
GPU_LAUNCH_S = 8.70e-6


def fpga_cycles(n: int, k: int = K) -> int:
    """Measured cost model. Exact at every size tested."""
    t = max(1, -(-n // k))          # ceil(n/k)
    return 66 * t * t + 34 * t * t * t


def t_fpga(n: int, k: int = K, f: float = F_HZ) -> float:
    return fpga_cycles(n, k) / f


def t_fpga_ideal(n: int, k: int = K, f: float = F_HZ) -> float:
    """Attainable if tile load were double-buffered and emit overlapped."""
    t = max(1, -(-n // k))
    return t**3 * k / f


def t_gpu(n: int, launch: float = GPU_LAUNCH_S) -> float:
    return launch


def crossover(launch: float = GPU_LAUNCH_S, k: int = K, f: float = F_HZ) -> float:
    """Largest N where the array still beats the GPU's launch floor."""
    budget = launch * f                      # in cycles
    lo, hi = 1.0, 1000.0
    for _ in range(200):
        mid = (lo + hi) / 2
        t = mid / k
        if 66 * t * t + 34 * t * t * t < budget:
            lo = mid
        else:
            hi = mid
    return lo


def array_for_crossover(target_n: int, f: float, launch: float = GPU_LAUNCH_S) -> float:
    """Array edge K needed to move the crossover out to target_n.

    Uses the ideal T^3*K/f form, since a device big enough to matter would be
    built with the pipelining this one lacks.
    """
    return ((target_n ** 3) / (launch * f)) ** 0.5


def load_csv(path: Path):
    if not path.is_file():
        return None
    with path.open() as fh:
        return list(csv.DictReader(fh))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--plot", action="store_true")
    args = ap.parse_args()

    fpga = load_csv(REPO / "bench" / "results_fpga.csv")
    gpu = load_csv(REPO / "bench" / "results_gpu.csv")

    launch = GPU_LAUNCH_S
    gpu_by_n = {}
    if gpu:
        for r in gpu:
            if r["variant"] == "tiled":
                gpu_by_n[int(r["n"])] = r
        if gpu_by_n:
            launch = min(float(r["launch_us"]) for r in gpu_by_n.values()) * 1e-6

    print("FPGA, measured on hardware")
    print(f"  {K}x{K} array, {DSP_USED} DSP48E1, ~{FF_USED} FF")
    print(f"  implemented {F_HZ/1e6:.0f} MHz, Fmax {FMAX_HZ/1e6:.1f} MHz")
    print(f"  bare array latency {ARRAY_ONLY*1e9:.0f} ns; with tiling "
          f"{t_fpga(8)*1e6:.2f} us at N=8")
    print(f"  peak {2*K*K*F_HZ/1e9:.1f} GOPS")
    print("")
    print(f"GPU launch floor: {launch*1e6:.2f} us "
          f"({'measured' if gpu_by_n else 'assumed'})")
    print("")

    nc = crossover(launch)
    print(f"crossover  N = {nc:.1f}")
    print("  below this the array finishes before the GPU finishes launching")
    print("")

    print(f"{'N':>6} {'cycles':>9} {'fpga_us':>10} {'gpu_us':>9} {'winner':>10}"
          f" {'measured':>10}")
    fpga_meas = {int(r["n"]): r for r in fpga} if fpga else {}

    sizes = sorted(set([8, 16, 24, 32, 40, 48, 56, 64] + list(fpga_meas)))
    for n in sizes:
        fc = t_fpga(n) * 1e6
        gm = launch * 1e6
        win = "FPGA" if fc < gm else "GPU"
        ratio = gm / fc if fc < gm else fc / gm
        meas = fpga_meas.get(n)
        tag = f"{float(meas['compute_us']):10.2f}" if meas else f"{'-':>10}"
        print(f"{n:6d} {fpga_cycles(n):9d} {fc:10.2f} {gm:9.2f}"
              f" {win:>6} {ratio:4.1f}x{tag}")

    if fpga_meas:
        bad = [n for n, r in fpga_meas.items()
               if abs(float(r["compute_us"]) - t_fpga(n)*1e6) > 0.01]
        if bad:
            print(f"\n  model disagrees with hardware at N={bad}")
        else:
            print("\n  model reproduces every hardware measurement exactly")

    print("")
    print("achieved vs attainable (tile load and inter-tile drain):")
    for n in (16, 32, 64):
        print(f"  N={n:3d}  {t_fpga(n)*1e6:8.2f} us achieved   "
              f"{t_fpga_ideal(n)*1e6:8.2f} us if fully pipelined   "
              f"({t_fpga(n)/t_fpga_ideal(n):.2f}x)")

    print("")
    print("scaling: hardware needed to move the crossover out")
    for target in (32, 64, 128):
        kk = array_for_crossover(target, 200e6, launch)
        print(f"  crossover at N={target:4d} @ 200 MHz -> K = {kk:.0f}, "
              f"{kk**2:.0f} DSPs ({kk**2/120:.0f}x this device)")

    if args.plot:
        make_plot(fpga_meas, gpu_by_n, launch, nc)


def make_plot(fpga_meas, gpu_by_n, launch, nc) -> None:
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("\nmatplotlib not installed: pip install matplotlib")
        return

    fig, ax = plt.subplots(figsize=(9, 5.5))

    model_n = list(range(8, 129, 4))
    ax.plot(model_n, [t_fpga(n)*1e6 for n in model_n], "-", color="0.6",
            lw=1.2, label="FPGA model  66T² + 34T³")

    if fpga_meas:
        ns = sorted(fpga_meas)
        ax.plot(ns, [float(fpga_meas[n]["compute_us"]) for n in ns], "o-",
                color="tab:blue", lw=2, ms=7,
                label="FPGA measured, compute")

    if gpu_by_n:
        gn = sorted(gpu_by_n)
        ax.plot(gn, [float(gpu_by_n[n]["launch_us"]) for n in gn], "^-",
                color="tab:red", lw=2, ms=7,
                label="RTX 4070 measured, launch to sync")
        ax.plot(gn, [float(gpu_by_n[n]["e2e_us"]) for n in gn], "d--",
                color="tab:purple", lw=1.4, ms=6, alpha=0.8,
                label="RTX 4070 measured, end to end")

    ax.axvline(nc, color="0.3", ls=":", lw=1.2)
    ax.annotate(f"crossover  N ≈ {nc:.0f}", xy=(nc, 2.2), rotation=90,
                fontsize=10, color="0.25", va="bottom", ha="right")

    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlabel("matrix dimension N")
    ax.set_ylabel("latency (microseconds)")
    ax.set_title("Systolic array vs RTX 4070: measured latency and the crossover")
    ax.grid(True, which="both", alpha=0.25)
    ax.legend(fontsize=9, loc="upper left")
    fig.tight_layout()

    out = REPO / "bench" / "crossover.png"
    fig.savefig(out, dpi=150)
    print(f"\nwrote {out}")


if __name__ == "__main__":
    main()
