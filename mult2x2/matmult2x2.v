`timescale 1ns/1ps

module matmult2x2 (
    input logic clk,
    input logic rst,
    input logic [15:0] a00, a01, a10, a11,
    input logic [15:0] b00, b01, b10, b11,
    output logic [31:0] c00, c01, c10, c11
);


mac_cell mac00
mac_cell mac01
mac_cell mac10
mac_cell mac11