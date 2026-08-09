`timescale 1ns/1ps

// Tiling controller: N x N matrix multiply on a K x K systolic array.
//
// Operands live in BRAM, written a word at a time from the host interface.


module tile_ctrl #(
    parameter int K      = 8,
    parameter int DATA_W = 16,
    parameter int MAX_T  = 16,                  // N up to K*MAX_T = 128
    parameter int TILE_W = 2*DATA_W + $clog2(K),// 35, one tile's accumulator
    parameter int ACC_W  = 48                   // full accumulation across tiles
) (
    input  logic clk,
    input  logic rst,

    // operand load: one K-element word per write
    input  logic                      wr_en,
    input  logic                      wr_sel,    // 0 = A, 1 = B
    input  logic [$clog2(K*MAX_T*MAX_T)-1:0] wr_addr,
    input  logic [K*DATA_W-1:0]       wr_data,

    // control
    input  logic                      start,
    input  logic [$clog2(MAX_T+1)-1:0] t_tiles,  // T = N/K
    output logic                      busy,
    output logic                      done,
    output logic [31:0]               compute_cycles,
    output logic [2:0]                dbg_state,     // bring-up visibility

    // result stream, tile order, row-major within a tile
    output logic signed [ACC_W-1:0]   out_data,
    output logic                      out_valid,
    input  logic                      out_ready
);

    localparam int DEPTH  = K * MAX_T * MAX_T;
    localparam int ADDR_W = $clog2(DEPTH);
    localparam int TW     = $clog2(MAX_T + 1);

    // ---------------- operand memory ----------------
    // Word w of row r sits at r*T + w, so a tile row is a single read.
    (* ram_style = "block" *) logic [K*DATA_W-1:0] a_mem [0:DEPTH-1];
    (* ram_style = "block" *) logic [K*DATA_W-1:0] b_mem [0:DEPTH-1];

    logic [ADDR_W-1:0]   a_addr, b_addr;
    logic [K*DATA_W-1:0] a_rd, b_rd;

    always_ff @(posedge clk) begin
        if (wr_en && !wr_sel) a_mem[wr_addr] <= wr_data;
        if (wr_en &&  wr_sel) b_mem[wr_addr] <= wr_data;
        a_rd <= a_mem[a_addr];
        b_rd <= b_mem[b_addr];
    end

    // ---------------- array ----------------
    logic signed [DATA_W-1:0] a_tile [K][K];
    logic signed [DATA_W-1:0] b_tile [K][K];
    logic signed [TILE_W-1:0] c_tile [K][K];
    logic                     arr_start, arr_done;

    matmul_top #(
        .K (K), .DATA_W (DATA_W), .ACC_W (TILE_W)
    ) u_array (
        .clk   (clk),
        .rst   (rst),
        .start (arr_start),
        .a_mat (a_tile),
        .b_mat (b_tile),
        .c_mat (c_tile),
        .done  (arr_done)
    );

    // ---------------- state ----------------
    typedef enum logic [2:0] {
        S_IDLE, S_KINIT, S_LOAD, S_RUN, S_ACC, S_EMIT, S_NEXT, S_DONE
    } state_t;

    state_t state;

    logic [TW-1:0]  ti, tj, tk, T;
    logic [$clog2(K+2)-1:0] ld_cnt;
    logic [$clog2(K)-1:0]   em_r, em_c;

    logic signed [ACC_W-1:0] acc [K][K];

    assign busy      = (state != S_IDLE);
    assign done      = (state == S_DONE);
    assign dbg_state = state;

    // Address generation. A tile (ti,tk) row r is at (ti*K + r)*T + tk;
    // B tile (tk,tj) row r is at (tk*K + r)*T + tj.
    always_comb begin
        a_addr = ADDR_W'((ti * K + ld_cnt) * T + tk);
        b_addr = ADDR_W'((tk * K + ld_cnt) * T + tj);
    end

    assign out_data  = acc[em_r][em_c];
    assign out_valid = (state == S_EMIT);

    always_ff @(posedge clk) begin
        if (rst) begin
            state          <= S_IDLE;
            arr_start      <= 1'b0;
            compute_cycles <= '0;
            ti <= '0; tj <= '0; tk <= '0;
            ld_cnt <= '0; em_r <= '0; em_c <= '0;
        end else begin
            arr_start <= 1'b0;

            // Count every working cycle except stalls on the output handshake.
            if (state != S_IDLE && state != S_DONE &&
                !(state == S_EMIT && !out_ready))
                compute_cycles <= compute_cycles + 1'b1;

            case (state)

                S_IDLE: begin
                    if (start) begin
                        T              <= t_tiles;
                        ti             <= '0;
                        tj             <= '0;
                        compute_cycles <= '0;
                        state          <= S_KINIT;
                    end
                end

                S_KINIT: begin
                    for (int r = 0; r < K; r++)
                        for (int c = 0; c < K; c++)
                            acc[r][c] <= '0;
                    tk     <= '0;
                    ld_cnt <= '0;
                    state  <= S_LOAD;
                end

                // Read one tile row per cycle. BRAM output is registered, so
                // the data for row r arrives the cycle after its address.
                S_LOAD: begin
                    if (ld_cnt >= 1) begin
                        for (int c = 0; c < K; c++) begin
                            a_tile[ld_cnt-1][c] <= a_rd[c*DATA_W +: DATA_W];
                            b_tile[ld_cnt-1][c] <= b_rd[c*DATA_W +: DATA_W];
                        end
                    end

                    if (ld_cnt == K) begin
                        arr_start <= 1'b1;
                        state     <= S_RUN;
                    end else begin
                        ld_cnt <= ld_cnt + 1'b1;
                    end
                end

                S_RUN: begin
                    if (arr_done) state <= S_ACC;
                end

                S_ACC: begin
                    for (int r = 0; r < K; r++)
                        for (int c = 0; c < K; c++)
                            acc[r][c] <= acc[r][c] + ACC_W'(signed'(c_tile[r][c]));

                    if (tk == T - 1) begin
                        em_r  <= '0;
                        em_c  <= '0;
                        state <= S_EMIT;
                    end else begin
                        tk     <= tk + 1'b1;
                        ld_cnt <= '0;
                        state  <= S_LOAD;
                    end
                end

                S_EMIT: begin
                    if (out_ready) begin
                        if (em_c == K - 1) begin
                            em_c <= '0;
                            if (em_r == K - 1) state <= S_NEXT;
                            else               em_r <= em_r + 1'b1;
                        end else begin
                            em_c <= em_c + 1'b1;
                        end
                    end
                end

                S_NEXT: begin
                    if (tj == T - 1) begin
                        tj <= '0;
                        if (ti == T - 1) state <= S_DONE;
                        else begin
                            ti    <= ti + 1'b1;
                            state <= S_KINIT;
                        end
                    end else begin
                        tj    <= tj + 1'b1;
                        state <= S_KINIT;
                    end
                end

                S_DONE: state <= S_IDLE;

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
