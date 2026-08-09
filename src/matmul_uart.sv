`timescale 1ns/1ps

module matmul_uart #(
    parameter int K      = 8,
    parameter int DATA_W = 16,
    parameter int ACC_W  = 2*DATA_W + $clog2(K)
) (
    input  logic       clk,
    input  logic       rst,

    input  logic [7:0] rx_data,
    input  logic       rx_valid,

    output logic [7:0] tx_data,
    output logic       tx_send,
    input  logic       tx_busy,

    output logic [1:0] status      // for LEDs: 0 rx, 1 compute, 2 tx
);

    localparam int ACC_BYTES = (ACC_W + 7) / 8;
    localparam int TX_BITS   = ACC_BYTES * 8;

    typedef enum logic [1:0] {S_RX, S_RUN, S_TX} state_t;
    state_t state;

    assign status = state;

    logic signed [DATA_W-1:0] a_mat [K][K];
    logic signed [DATA_W-1:0] b_mat [K][K];
    logic signed [ACC_W-1:0]  c_mat [K][K];

    logic signed [ACC_W-1:0] c_lat [K][K];

    logic start, done;

    matmul_top #(
        .K (K), .DATA_W (DATA_W), .ACC_W (ACC_W)
    ) u_matmul (
        .clk   (clk),
        .rst   (rst),
        .start (start),
        .a_mat (a_mat),
        .b_mat (b_mat),
        .c_mat (c_mat),
        .done  (done)
    );

    // rx side
    // Row/column counters rather than divide-by-K on a flat index, so K does
    // not have to be a power of two.
    logic [$clog2(K)-1:0] rx_row, rx_col;
    logic                 rx_half;   // 0 = expecting high byte
    logic                 rx_sel_b;  // 0 = filling A, 1 = filling B
    logic [7:0]           rx_hi;

    // tx
    logic [$clog2(K)-1:0] tx_row, tx_col;
    logic [3:0]           tx_byte;
    logic [TX_BITS-1:0]   tx_shift;
    logic                 tx_loaded;

    always_ff @(posedge clk) begin
        if (rst) begin
            state     <= S_RX;
            rx_row    <= '0;
            rx_col    <= '0;
            rx_half   <= 1'b0;
            rx_sel_b  <= 1'b0;
            start     <= 1'b0;
            tx_send   <= 1'b0;
            tx_row    <= '0;
            tx_col    <= '0;
            tx_byte   <= '0;
            tx_loaded <= 1'b0;
        end else begin
            start   <= 1'b0;
            tx_send <= 1'b0;

            case (state)

                S_RX: begin
                    if (rx_valid) begin
                        if (!rx_half) begin
                            rx_hi   <= rx_data;
                            rx_half <= 1'b1;
                        end else begin
                            rx_half <= 1'b0;

                            if (!rx_sel_b) a_mat[rx_row][rx_col] <= {rx_hi, rx_data};
                            else           b_mat[rx_row][rx_col] <= {rx_hi, rx_data};

                            if (rx_col == K - 1) begin
                                rx_col <= '0;
                                if (rx_row == K - 1) begin
                                    rx_row <= '0;
                                    if (!rx_sel_b) begin
                                        rx_sel_b <= 1'b1;
                                    end else begin
                                        // B complete: fire the array
                                        rx_sel_b <= 1'b0;
                                        start    <= 1'b1;
                                        state    <= S_RUN;
                                    end
                                end else begin
                                    rx_row <= rx_row + 1'b1;
                                end
                            end else begin
                                rx_col <= rx_col + 1'b1;
                            end
                        end
                    end
                end

                S_RUN: begin
                    if (done) begin
                        for (int i = 0; i < K; i++)
                            for (int j = 0; j < K; j++)
                                c_lat[i][j] <= c_mat[i][j];

                        state     <= S_TX;
                        tx_row    <= '0;
                        tx_col    <= '0;
                        tx_byte   <= '0;
                        tx_loaded <= 1'b0;
                    end
                end

                S_TX: begin
                    if (!tx_loaded) begin
                        // sext the accumulator up to a whole number of
                        // bytes, then shift out MSB first.
                        tx_shift  <= TX_BITS'(signed'(c_lat[tx_row][tx_col]));
                        tx_loaded <= 1'b1;
                        tx_byte   <= '0;
                    end else if (!tx_busy && !tx_send) begin
                        tx_data  <= tx_shift[TX_BITS-1 -: 8];
                        tx_send  <= 1'b1;
                        tx_shift <= {tx_shift[TX_BITS-9:0], 8'h00};

                        if (tx_byte == ACC_BYTES - 1) begin
                            tx_loaded <= 1'b0;
                            if (tx_col == K - 1) begin
                                tx_col <= '0;
                                if (tx_row == K - 1) begin
                                    tx_row <= '0;
                                    state  <= S_RX;
                                end else begin
                                    tx_row <= tx_row + 1'b1;
                                end
                            end else begin
                                tx_col <= tx_col + 1'b1;
                            end
                        end else begin
                            tx_byte <= tx_byte + 1'b1;
                        end
                    end
                end

                default: state <= S_RX;
            endcase
        end
    end

endmodule
