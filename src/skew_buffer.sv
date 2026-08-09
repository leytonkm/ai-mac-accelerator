`timescale 1ns/1ps

// Input staircase for the systolic array.

module skew_buffer #(
    parameter int K = 8,
    parameter int W = 16
) (
    input  logic                clk,
    input  logic                clr,
    input  logic signed [W-1:0] in  [K],
    output logic signed [W-1:0] out [K]
);

    logic signed [W-1:0] pipe [K][K];

    always_ff @(posedge clk) begin
        for (int lane = 0; lane < K; lane++) begin
            if (clr) begin
                for (int s = 0; s < K; s++) pipe[lane][s] <= '0;
            end else begin
                pipe[lane][0] <= in[lane];
                for (int s = 1; s < K; s++) pipe[lane][s] <= pipe[lane][s-1];
            end
        end
    end

    generate
        for (genvar lane = 0; lane < K; lane++) begin : g_tap
            if (lane == 0) begin : g_passthrough
                // Lane 0 needs no delay, so it bypasses the pipeline entirely.
                assign out[lane] = in[0];
            end else begin : g_delayed
                // Lane i taps stage i-1, giving i cycles of delay.
                assign out[lane] = pipe[lane][lane-1];
            end
        end
    endgenerate

endmodule
