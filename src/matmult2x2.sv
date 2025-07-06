`timescale 1ns/1ps

module matmult2x2 (
    input  logic clk,
    input  logic rst,
    input  logic [15:0] a00, a01, a10, a11,
    input  logic [15:0] b00, b01, b10, b11,
    output logic [31:0] c00, c01, c10, c11
);

    logic [31:0] temp_c00, temp_c01, temp_c10, temp_c11;

    mac_cell mac00a(.clk(clk), .rst(rst), .a(a00), .b(b00), .acc_in(0), .acc_out(temp_c00)); 
    mac_cell mac00b(.clk(clk), .rst(rst), .a(a01), .b(b10), .acc_in(temp_c00), .acc_out(c00));

    mac_cell mac01a(.clk(clk), .rst(rst), .a(a00), .b(b01), .acc_in(0), .acc_out(temp_c01));
    mac_cell mac01b(.clk(clk), .rst(rst), .a(a01), .b(b11), .acc_in(temp_c01), .acc_out(c01));

    mac_cell mac10a(.clk(clk), .rst(rst), .a(a10), .b(b00), .acc_in(0), .acc_out(temp_c10));      
    mac_cell mac10b(.clk(clk), .rst(rst), .a(a11), .b(b10), .acc_in(temp_c10), .acc_out(c10));     

    mac_cell mac11a(.clk(clk), .rst(rst), .a(a10), .b(b01), .acc_in(0), .acc_out(temp_c11));      
    mac_cell mac11b(.clk(clk), .rst(rst), .a(a11), .b(b11), .acc_in(temp_c11), .acc_out(c11));   

endmodule
