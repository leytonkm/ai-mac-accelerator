`timescale 1ns/1ps

module mac_cell (
    input logic clk,
    input logic rst,
    input logic [15:0] a,
    input logic [15:0] b,
    input logic [31:0] acc_in,
    output logic [31:0] acc_out
);

    logic [31:0] mult_result;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            mult_result <= 0;
            acc_out <= 0;
        end else begin
            mult_result <= a * b;
            acc_out <= mult_result + acc_in;
        end
    end

endmodule

