#!/bin/bash
set -e

mkdir -p sim

# Compile with correct paths
iverilog -g2012 \
    src/mac_cell.sv \
    src/matmult2x2.sv \
    tb/testbench.sv \
    -o sim_out

# Run the simulation (generates sim/waveform.vcd)
vvp sim_out

# Open the waveform viewer (optional)
gtkwave sim/waveform.vcd &
