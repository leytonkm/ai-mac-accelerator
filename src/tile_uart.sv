`timescale 1ns/1ps

// UART front end for tile_ctrl: variable-size matrix multiply over serial.
//

module tile_uart #(
    parameter int K      = 8,
    parameter int DATA_W = 16,
    parameter int MAX_T  = 8,
    parameter int ACC_W  = 48
) (
    input  logic       clk,
    input  logic       rst,

    input  logic [7:0] rx_data,
    input  logic       rx_valid,

    output logic [7:0] tx_data,
    output logic       tx_send,
    input  logic       tx_busy,

    output logic [1:0] status,
    output logic [2:0] dbg_ctrl_state
);

    localparam int DEPTH     = K * MAX_T * MAX_T;
    localparam int ADDR_W    = $clog2(DEPTH);
    localparam int TW        = $clog2(MAX_T + 1);
    localparam int ACC_BYTES = ACC_W / 8;

    typedef enum logic [1:0] {
        S_HDR, S_RX, S_TXDAT, S_TXCYC
    } state_t;

    state_t state;
    assign status = state;

    logic [TW-1:0]   t_tiles;
    logic [31:0]     words_per_mat;   // K*T*T
    logic [31:0]     results_total;   // K*K*T*T

    // ---- operand assembly ----
    logic [K*DATA_W-1:0] word_sr;
    logic [7:0]          hi_byte;
    logic                half;         // 0 = expecting high byte
    logic [2:0]          elem;         // element within the word
    logic [ADDR_W-1:0]   word_addr;
    logic                sel_b;

    logic                    wr_en;
    logic                    wr_sel;
    logic [ADDR_W-1:0]       wr_addr;
    logic [K*DATA_W-1:0]     wr_data;

    // ---- tile controller ----
    logic                    ctrl_start, ctrl_busy, ctrl_done;
    logic [31:0]             compute_cycles;
    logic signed [ACC_W-1:0] out_data;
    logic                    out_valid, out_ready;

    tile_ctrl #(
        .K (K), .DATA_W (DATA_W), .MAX_T (MAX_T), .ACC_W (ACC_W)
    ) u_ctrl (
        .clk (clk), .rst (rst),
        .wr_en (wr_en), .wr_sel (wr_sel), .wr_addr (wr_addr), .wr_data (wr_data),
        .start (ctrl_start), .t_tiles (t_tiles),
        .busy (ctrl_busy), .done (ctrl_done),
        .compute_cycles (compute_cycles),
        .dbg_state (dbg_ctrl_state),
        .out_data (out_data), .out_valid (out_valid), .out_ready (out_ready)
    );

    // ---- transmit ----
    logic [ACC_W-1:0] tx_sr;
    logic [2:0]       tx_byte;
    logic             tx_loaded;
    logic [31:0]      res_sent;
    logic [31:0]      cyc_latched;   // captured whenever tile_ctrl finishes
    logic [31:0]      cyc_shift;     // shifted out after the results
    logic [1:0]       cyc_byte;

    // Consume one result the cycle we latch it.
    assign out_ready = (state == S_TXDAT) && !tx_loaded && out_valid;

    always_ff @(posedge clk) begin
        if (rst) begin
            state      <= S_HDR;
            wr_en      <= 1'b0;
            ctrl_start <= 1'b0;
            tx_send    <= 1'b0;
            half       <= 1'b0;
            elem       <= '0;
            sel_b      <= 1'b0;
            word_addr  <= '0;
            tx_loaded  <= 1'b0;
            res_sent   <= '0;
            cyc_byte   <= '0;
        end else begin
            wr_en      <= 1'b0;
            ctrl_start <= 1'b0;
            tx_send    <= 1'b0;

            // done pulses once, right after the final tile is emitted, which
            // is before the last bytes have been shifted out. Latch it here
            // rather than in a state that has not been reached yet.
            if (ctrl_done) cyc_latched <= compute_cycles;

            case (state)

                S_HDR: begin
                    if (rx_valid) begin
                        t_tiles       <= rx_data[TW-1:0];
                        words_per_mat <= K * rx_data * rx_data;
                        results_total <= K * K * rx_data * rx_data;
                        half          <= 1'b0;
                        elem          <= '0;
                        sel_b         <= 1'b0;
                        word_addr     <= '0;
                        state         <= S_RX;
                    end
                end

                S_RX: begin
                    if (rx_valid) begin
                        if (!half) begin
                            hi_byte <= rx_data;
                            half    <= 1'b1;
                        end else begin
                            half    <= 1'b0;
                            // Shift right, inserting at the top, so after K
                            // elements element j sits at bits [j*DATA_W +: W].
                            word_sr <= {{hi_byte, rx_data},
                                        word_sr[K*DATA_W-1:DATA_W]};

                            if (elem == K - 1) begin
                                elem    <= '0;
                                wr_en   <= 1'b1;
                                wr_sel  <= sel_b;
                                wr_addr <= word_addr;
                                wr_data <= {{hi_byte, rx_data},
                                            word_sr[K*DATA_W-1:DATA_W]};

                                if (word_addr == ADDR_W'(words_per_mat - 1)) begin
                                    word_addr <= '0;
                                    if (!sel_b) begin
                                        sel_b <= 1'b1;
                                    end else begin
                                        sel_b      <= 1'b0;
                                        ctrl_start <= 1'b1;
                                        res_sent   <= '0;
                                        tx_loaded  <= 1'b0;
                                        state      <= S_TXDAT;
                                    end
                                end else begin
                                    word_addr <= word_addr + 1'b1;
                                end
                            end else begin
                                elem <= elem + 1'b1;
                            end
                        end
                    end
                end

                S_TXCYC: begin
                    if (!tx_busy && !tx_send) begin
                        tx_data   <= cyc_shift[31:24];
                        tx_send   <= 1'b1;
                        cyc_shift <= {cyc_shift[23:0], 8'h00};
                        if (cyc_byte == 2'd3) state <= S_HDR;
                        else                  cyc_byte <= cyc_byte + 1'b1;
                    end
                end

                S_TXDAT: begin
                    if (!tx_loaded) begin
                        if (out_valid) begin
                            tx_sr     <= out_data;
                            tx_loaded <= 1'b1;
                            tx_byte   <= '0;
                        end
                    end else if (!tx_busy && !tx_send) begin
                        tx_data <= tx_sr[ACC_W-1 -: 8];
                        tx_send <= 1'b1;
                        tx_sr   <= {tx_sr[ACC_W-9:0], 8'h00};

                        if (tx_byte == ACC_BYTES - 1) begin
                            tx_loaded <= 1'b0;
                            if (res_sent == results_total - 1) begin
                                res_sent  <= '0;
                                cyc_shift <= cyc_latched;
                                cyc_byte  <= '0;
                                state     <= S_TXCYC;
                            end else begin
                                res_sent <= res_sent + 1'b1;
                            end
                        end else begin
                            tx_byte <= tx_byte + 1'b1;
                        end
                    end
                end

                default: state <= S_HDR;
            endcase
        end
    end

endmodule
