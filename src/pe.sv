`timescale 1ns/1ps

// Processing element for the output-stationary systolic array.

module pe #(
    parameter int DATA_W = 16,
    parameter int ACC_W  = 35
) (
    input  logic                     clk,
    input  logic                     clr,    // synchronous acc clear
    input  logic signed [DATA_W-1:0] a_in,
    input  logic signed [DATA_W-1:0] b_in,
    output logic signed [DATA_W-1:0] a_out,  // to the cell on the right
    output logic signed [DATA_W-1:0] b_out,  // to the cell below
    output logic signed [ACC_W-1:0]  acc
);

    // Both operands are signed, so the product is signed and gets
    logic signed [2*DATA_W-1:0] prod;
    assign prod = a_in * b_in;

    always_ff @(posedge clk) begin
        if (clr) begin
            a_out <= '0;
            b_out <= '0;
            acc   <= '0;
        end else begin
            a_out <= a_in;
            b_out <= b_in;
            acc   <= acc + prod;
        end
    end

endmodule
