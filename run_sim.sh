#!/bin/bash
mkdir -p sim
# compile with SystemVerilog support
iverilog -g2012 mac_cell.v testbench.sv -o sim_out
# run the simulation, dump the VCD
vvp sim_out
# view the waveform
gtkwave sim/waveform.vcd &

