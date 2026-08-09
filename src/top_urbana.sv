`timescale 1ns/1ps


module top_urbana (
    input  logic       CLK_100MHZ,
    input  logic       BTN0,       // reset
    output logic [3:0] LED,
    input  logic       UART_RXD,  
    output logic       UART_TXD   
);

    localparam int K      = 8;
    localparam int DATA_W = 16;
    localparam int MAX_T  = 8;           // N up to K*MAX_T = 64
    localparam int BAUD   = 1_000_000;   //         100 MHz / 1 Mbaud = 100 cycles/bit

    logic clk;
    assign clk = CLK_100MHZ;


    logic [7:0] rst_cnt = '0;
    logic       rst;

    always_ff @(posedge clk) begin
        if (rst_cnt != 8'hFF) rst_cnt <= rst_cnt + 1'b1;
    end

    assign rst = (rst_cnt != 8'hFF) | BTN0;

    logic [7:0] rx_data, tx_data;
    logic       rx_valid, tx_send, tx_busy;
    logic [1:0] status;

    uart_rx #(.CLK_HZ (100_000_000), .BAUD (BAUD)) u_rx (
        .clk (clk), .rst (rst), .rx (UART_RXD),
        .data (rx_data), .valid (rx_valid)
    );

    uart_tx #(.CLK_HZ (100_000_000), .BAUD (BAUD)) u_tx (
        .clk (clk), .rst (rst), .data (tx_data), .send (tx_send),
        .tx (UART_TXD), .busy (tx_busy)
    );

    tile_uart #(.K (K), .DATA_W (DATA_W), .MAX_T (MAX_T)) u_ctrl (
        .clk      (clk),
        .rst      (rst),
        .rx_data  (rx_data),
        .rx_valid (rx_valid),
        .tx_data  (tx_data),
        .tx_send  (tx_send),
        .tx_busy  (tx_busy),
        .status   (status),
        .dbg_ctrl_state (dbg_ctrl_state)
    );

    logic [2:0] dbg_ctrl_state;

    logic [25:0] beat = '0;
    always_ff @(posedge clk) beat <= beat + 1'b1;


    logic seen_byte = 1'b0;   // uart_rx decoded at least one byte
    logic seen_tx   = 1'b0;   // controller reached the transmit state

    always_ff @(posedge clk) begin
        if (rst) begin
            seen_byte <= 1'b0;
            seen_tx   <= 1'b0;
        end else begin
            if (rx_valid)        seen_byte <= 1'b1;
            if (status == 2'd2)  seen_tx   <= 1'b1;
        end
    end


        //   0 idle    1 kinit    2 load    3 run
        //   4 accum  5 emit    6 next     7 done
    always_comb begin
        LED[2:0] = dbg_ctrl_state;
        LED[3]   = beat[25];  
    end

endmodule
