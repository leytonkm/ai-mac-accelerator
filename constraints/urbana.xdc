# Urbana board (Spartan-7 XC7S50-CSGA324) constraints for top_urbana.
# Pin assignments from the Real Digital master constraints file:
# https://www.realdigital.org/hardware/urbana
#
# Only pins the design actually uses appear here. Every port must have both a
# PACKAGE_PIN and an IOSTANDARD or write_bitstream fails DRC (NSTD-1/UCIO-1),
# so the port list in top_urbana.sv is kept to exactly this set.
#
# Note: C13, D16, A17, C18 and J1 did not take when assigned on this setup, so
# the status LEDs use board LEDs 1-4 rather than 0-3.

# 100 MHz oscillator
set_property -dict {PACKAGE_PIN N15 IOSTANDARD LVCMOS33} [get_ports {CLK_100MHZ}]
create_clock -period 10.000 -name sys_clk [get_ports {CLK_100MHZ}]

# USB-UART, shared with the programming cable.
#
# Real Digital names these from the *peripheral's* perspective, not the FPGA's
# -- the same file calls the Bluetooth pins BLE_UART_TXD/RXD, and a BLE
# module's TXD is what the FPGA listens to. So board pin B16 ("UART_TXD") is
# the USB bridge transmitting, which is the FPGA's input, and A16 is the FPGA's
# output. Wired accordingly:
set_property -dict {PACKAGE_PIN B16 IOSTANDARD LVCMOS33} [get_ports {UART_RXD}]
set_property -dict {PACKAGE_PIN A16 IOSTANDARD LVCMOS33} [get_ports {UART_TXD}]

# Reset button
set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS25} [get_ports {BTN0}]

# Status LEDs (board LEDs 1-4)
set_property -dict {PACKAGE_PIN C14 IOSTANDARD LVCMOS33} [get_ports {LED[0]}]
set_property -dict {PACKAGE_PIN D14 IOSTANDARD LVCMOS33} [get_ports {LED[1]}]
set_property -dict {PACKAGE_PIN D15 IOSTANDARD LVCMOS33} [get_ports {LED[2]}]
set_property -dict {PACKAGE_PIN F18 IOSTANDARD LVCMOS33} [get_ports {LED[3]}]

# Bank 0 configuration
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
