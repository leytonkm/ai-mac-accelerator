`timescale 1ns/1ps


module matmul_top #(
    parameter int K      = 8,
    parameter int DATA_W = 16,
    parameter int ACC_W  = 2*DATA_W + $clog2(K)
) (
    input  logic                     clk,
    input  logic                     rst,
    input  logic                     start,
    input  logic signed [DATA_W-1:0] a_mat [K][K],
    input  logic signed [DATA_W-1:0] b_mat [K][K],
    output logic signed [ACC_W-1:0]  c_mat [K][K],
    output logic                     done
);

    localparam int LAST = 3*K - 3;
    localparam int CW   = $clog2(3*K) + 1;

    typedef enum logic [1:0] {S_IDLE, S_RUN, S_DONE} state_t;

    state_t        state;
    logic [CW-1:0] cnt;
    logic          clr;

    // Idle clears both the accumulators and the skew pipeline, so each run
    // starts from a known state without needing a global reset.
    assign clr  = (state == S_IDLE);
    assign done = (state == S_DONE);

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            cnt   <= '0;
        end else begin
            case (state)
                S_IDLE: begin
                    cnt <= '0;
                    if (start) state <= S_RUN;
                end
                S_RUN: begin
                    if (cnt == CW'(LAST)) state <= S_DONE;
                    else                  cnt   <= cnt + 1'b1;
                end
                S_DONE:  state <= S_IDLE;
                default: state <= S_IDLE;
            endcase
        end
    end


    logic signed [DATA_W-1:0] a_feed [K];
    logic signed [DATA_W-1:0] b_feed [K];

    always_comb begin
        for (int i = 0; i < K; i++) begin
            a_feed[i] = '0;
            b_feed[i] = '0;
        end
        if (state == S_RUN && cnt < CW'(K)) begin
            for (int i = 0; i < K; i++) begin
                a_feed[i] = a_mat[i][cnt];
                b_feed[i] = b_mat[cnt][i];
            end
        end
    end

    logic signed [DATA_W-1:0] a_skew [K];
    logic signed [DATA_W-1:0] b_skew [K];

    skew_buffer #(.K(K), .W(DATA_W)) u_skew_a (
        .clk (clk), .clr (clr), .in (a_feed), .out (a_skew)
    );

    skew_buffer #(.K(K), .W(DATA_W)) u_skew_b (
        .clk (clk), .clr (clr), .in (b_feed), .out (b_skew)
    );

    systolic_array #(
        .K (K), .DATA_W (DATA_W), .ACC_W (ACC_W)
    ) u_array (
        .clk  (clk),
        .clr  (clr),
        .a_in (a_skew),
        .b_in (b_skew),
        .c    (c_mat)
    );

endmodule
