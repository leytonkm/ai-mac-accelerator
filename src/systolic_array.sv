`timescale 1ns/1ps

// K x K output-stationary systolic array.

//
//   a_in[i] --> PE(i,0) --> PE(i,1) --> ... --> PE(i,K-1)
//   b_in[j] --> PE(0,j) --> PE(1,j) --> ... --> PE(K-1,j)

module systolic_array #(
    parameter int K      = 8,
    parameter int DATA_W = 16,
    parameter int ACC_W  = 35
) (
    input  logic                     clk,
    input  logic                     clr,
    input  logic signed [DATA_W-1:0] a_in [K],       // left edge, one per row
    input  logic signed [DATA_W-1:0] b_in [K],       // top edge, one per column
    output logic signed [ACC_W-1:0]  c    [K][K]
);

    // Interconnect carries one extra column/row so the last PE has somewhere
    logic signed [DATA_W-1:0] a_h [K][K+1];
    logic signed [DATA_W-1:0] b_v [K+1][K];

    generate
    for (genvar i = 0; i < K; i++) begin : g_a_edge
        assign a_h[i][0] = a_in[i];
    end

    for (genvar j = 0; j < K; j++) begin : g_b_edge
        assign b_v[0][j] = b_in[j];
    end

    for (genvar i = 0; i < K; i++) begin : g_row
        for (genvar j = 0; j < K; j++) begin : g_col
            pe #(
                .DATA_W (DATA_W),
                .ACC_W  (ACC_W)
            ) u_pe (
                .clk   (clk),
                .clr   (clr),
                .a_in  (a_h[i][j]),
                .b_in  (b_v[i][j]),
                .a_out (a_h[i][j+1]),
                .b_out (b_v[i+1][j]),
                .acc   (c[i][j])
            );
        end
    end
    endgenerate

endmodule
