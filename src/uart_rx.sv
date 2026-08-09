`timescale 1ns/1ps

// UART receiver, 8N1, no flow control.
//
// Samples the middle of each bit: waits half a bit after the falling start
// edge, re-checks that the line is still low (rejects glitches), then samples
// every DIV cycles from there.
//
// BAUD is a parameter so the testbench can run at a silly-fast rate and finish
// in a reasonable number of cycles.

module uart_rx #(
    parameter int CLK_HZ = 100_000_000,
    parameter int BAUD   = 1_000_000
) (
    input  logic       clk,
    input  logic       rst,
    input  logic       rx,
    output logic [7:0] data,
    output logic       valid   // one-cycle pulse when data is good
);

    localparam int DIV  = CLK_HZ / BAUD;
    localparam int HALF = DIV / 2;

    // Two-stage synchronizer: rx is asynchronous to clk.
    logic rx_meta, rx_sync;
    always_ff @(posedge clk) begin
        rx_meta <= rx;
        rx_sync <= rx_meta;
    end

    typedef enum logic [1:0] {S_IDLE, S_START, S_DATA, S_STOP} state_t;

    state_t      state;
    logic [15:0] cnt;
    logic [2:0]  bit_idx;
    logic [7:0]  shifter;

    always_ff @(posedge clk) begin
        if (rst) begin
            state   <= S_IDLE;
            cnt     <= '0;
            bit_idx <= '0;
            valid   <= 1'b0;
            data    <= '0;
        end else begin
            valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    cnt <= '0;
                    if (!rx_sync) state <= S_START;
                end

                S_START: begin
                    if (cnt == HALF - 1) begin
                        cnt <= '0;
                        if (!rx_sync) begin
                            state   <= S_DATA;
                            bit_idx <= '0;
                        end else begin
                            state <= S_IDLE;
                        end
                    end else begin
                        cnt <= cnt + 1'b1;
                    end
                end

                S_DATA: begin
                    if (cnt == DIV - 1) begin
                        cnt     <= '0;
                        shifter <= {rx_sync, shifter[7:1]};   // LSB first
                        if (bit_idx == 3'd7) state <= S_STOP;
                        else                 bit_idx <= bit_idx + 1'b1;
                    end else begin
                        cnt <= cnt + 1'b1;
                    end
                end

                S_STOP: begin
                    if (cnt == DIV - 1) begin
                        cnt   <= '0;
                        state <= S_IDLE;
                        data  <= shifter;
                        valid <= 1'b1;
                    end else begin
                        cnt <= cnt + 1'b1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
