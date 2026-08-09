#!/bin/bash
# Generate vectors, build the systolic array testbench, run it.
#
#   ./run_sim.sh                      default K=8, 1000 random cases
#   ./run_sim.sh --k 4 --random 200   args pass through to gen_vectors.py
#   DUMP=1 ./run_sim.sh               also write sim/tb_systolic.vcd
#
# Exits nonzero if any case fails, so it works in CI or a git hook.

set -e
cd "$(dirname "$0")"

# Windows/MSYS installs usually expose `python`, Linux `python3`.
PY=$(command -v python3 || command -v python) || true
if [ -z "$PY" ]; then
    echo "run_sim.sh: no python found on PATH" >&2
    exit 1
fi

"$PY" model/gen_vectors.py "$@"

mkdir -p sim

iverilog -g2012 -I . -o sim/tb_systolic.vvp \
    src/pe.sv \
    src/skew_buffer.sv \
    src/systolic_array.sv \
    src/matmul_top.sv \
    tb/tb_systolic.sv

if [ -n "$DUMP" ]; then
    vvp sim/tb_systolic.vvp +dump
    echo "wrote sim/tb_systolic.vcd"
else
    vvp sim/tb_systolic.vvp
fi
