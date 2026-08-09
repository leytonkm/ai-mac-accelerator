`timescale 1ns/1ps

// UART transmitter, 8N1, no flow control.
//
// Pulse `send` with `data` valid while `busy` is low. Line idles high.

module uart_tx #(
    parameter int CLK_HZ = 100_000_000,
    parameter int BAUD   = 1_000_000
) (
    input  logic       clk,
    input  logic       rst,
    input  logic [7:0] data,
    input  logic       send,
    output logic       tx,
    output logic       busy
);

    localparam int DIV = CLK_HZ / BAUD;

    typedef enum logic [1:0] {S_IDLE, S_START, S_DATA, S_STOP} state_t;

    state_t      state;
    logic [15:0] cnt;
    logic [2:0]  bit_idx;
    logic [7:0]  shifter;

    assign busy = (state != S_IDLE);

    always_ff @(posedge clk) begin
        if (rst) begin
            state   <= S_IDLE;
            cnt     <= '0;
            bit_idx <= '0;
            tx      <= 1'b1;
        end else begin
            case (state)
                S_IDLE: begin
                    tx  <= 1'b1;
                    cnt <= '0;
                    if (send) begin
                        shifter <= data;
                        state   <= S_START;
                    end
                end

                S_START: begin
                    tx <= 1'b0;
                    if (cnt == DIV - 1) begin
                        cnt     <= '0;
                        bit_idx <= '0;
                        state   <= S_DATA;
                    end else begin
                        cnt <= cnt + 1'b1;
                    end
                end

                S_DATA: begin
                    tx <= shifter[0];
                    if (cnt == DIV - 1) begin
                        cnt     <= '0;
                        shifter <= {1'b0, shifter[7:1]};
                        if (bit_idx == 3'd7) state <= S_STOP;
                        else                 bit_idx <= bit_idx + 1'b1;
                    end else begin
                        cnt <= cnt + 1'b1;
                    end
                end

                S_STOP: begin
                    tx <= 1'b1;
                    if (cnt == DIV - 1) begin
                        cnt   <= '0;
                        state <= S_IDLE;
                    end else begin
                        cnt <= cnt + 1'b1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
