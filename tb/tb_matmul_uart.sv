`timescale 1ns/1ps

// Protocol-level testbench for matmul_uart.

`include "vector_params.svh"

module tb_matmul_uart;

    localparam int K         = `VEC_K;
    localparam int DATA_W    = `VEC_DATA_W;
    localparam int ACC_W     = `VEC_ACC_W;
    localparam int ELEMS     = K * K;
    localparam int ACC_BYTES = (ACC_W + 7) / 8;
    localparam int TX_BITS   = ACC_BYTES * 8;
    localparam int IN_BYTES  = 4 * ELEMS;
    localparam int OUT_BYTES = ELEMS * ACC_BYTES;
    localparam int NCASES    = 25;
    localparam int TIMEOUT   = 20000;

    logic clk = 1'b0;
    logic rst = 1'b1;

    logic [7:0] rx_data;
    logic       rx_valid;
    logic [7:0] tx_data;
    logic       tx_send;
    logic       tx_busy;
    logic [1:0] status;

    matmul_uart #(.K (K), .DATA_W (DATA_W), .ACC_W (ACC_W)) dut (
        .clk      (clk),
        .rst      (rst),
        .rx_data  (rx_data),
        .rx_valid (rx_valid),
        .tx_data  (tx_data),
        .tx_send  (tx_send),
        .tx_busy  (tx_busy),
        .status   (status)
    );

    always #5 clk = ~clk;

    // Stand-in transmitter: busy for a few cycles after each byte so the
    // handshake in matmul_uart is actually exercised.
    logic [3:0] busy_cnt = '0;
    always_ff @(posedge clk) begin
        if (tx_send)            busy_cnt <= 4'd6;
        else if (busy_cnt != 0) busy_cnt <= busy_cnt - 1'b1;
    end
    assign tx_busy = (busy_cnt != 0);

    // Capture. cap_idx has exactly one procedural driver -- the previous
    // version cleared it from the test task as well, which is a race.
    logic       clear_cap = 1'b0;
    logic [7:0] captured [0:OUT_BYTES-1];
    int         cap_idx = 0;

    always_ff @(posedge clk) begin
        if (clear_cap) begin
            cap_idx <= 0;
        end else if (tx_send) begin
            captured[cap_idx] <= tx_data;
            cap_idx           <= cap_idx + 1;
        end
    end

    // Handshake counters, for diagnosing a stall.
    int rx_bytes = 0;
    int starts   = 0;
    int dones    = 0;

    always_ff @(posedge clk) begin
        if (!rst) begin
            if (rx_valid)  rx_bytes <= rx_bytes + 1;
            if (dut.start) starts   <= starts + 1;
            if (dut.done)  dones    <= dones + 1;
        end
    end

    logic [DATA_W-1:0] a_all [0:`VEC_NUM_CASES*ELEMS-1];
    logic [DATA_W-1:0] b_all [0:`VEC_NUM_CASES*ELEMS-1];
    logic [ACC_W-1:0]  c_all [0:`VEC_NUM_CASES*ELEMS-1];

    int errors = 0;

    task automatic send_byte(input logic [7:0] b);
        begin
            @(negedge clk);
            rx_data  = b;
            rx_valid = 1'b1;
            @(negedge clk);
            rx_valid = 1'b0;
            @(negedge clk);
        end
    endtask

    task automatic dump_state;
        begin
            $display("    dut.state=%0d  rx_bytes=%0d (want %0d)  starts=%0d  dones=%0d  cap_idx=%0d",
                     dut.state, rx_bytes, IN_BYTES, starts, dones, cap_idx);
            $display("    rx_row=%0d rx_col=%0d rx_half=%0b rx_sel_b=%0b",
                     dut.rx_row, dut.rx_col, dut.rx_half, dut.rx_sel_b);
            $display("    tx_row=%0d tx_col=%0d tx_byte=%0d tx_loaded=%0b tx_busy=%0b tx_send=%0b",
                     dut.tx_row, dut.tx_col, dut.tx_byte, dut.tx_loaded,
                     tx_busy, tx_send);
        end
    endtask

    task automatic run_case(input int cs, output bit ok);
        int base;
        logic signed [TX_BITS-1:0] got;
        logic signed [TX_BITS-1:0] want;
        int timeout;
        begin
            ok   = 1'b1;
            base = cs * ELEMS;

            @(negedge clk);
            clear_cap = 1'b1;
            @(negedge clk);
            clear_cap = 1'b0;

            for (int e = 0; e < ELEMS; e++) begin
                send_byte(a_all[base+e][15:8]);
                send_byte(a_all[base+e][7:0]);
            end
            for (int e = 0; e < ELEMS; e++) begin
                send_byte(b_all[base+e][15:8]);
                send_byte(b_all[base+e][7:0]);
            end

            timeout = 0;
            while (cap_idx < OUT_BYTES && timeout < TIMEOUT) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (cap_idx < OUT_BYTES) begin
                $display("");
                $display("  STALL on case %0d: %0d of %0d bytes out after %0d cycles",
                         cs, cap_idx, OUT_BYTES, TIMEOUT);
                dump_state;
                ok = 1'b0;
            end else begin
                for (int e = 0; e < ELEMS; e++) begin
                    got = '0;
                    for (int nb = 0; nb < ACC_BYTES; nb++)
                        got = {got[TX_BITS-9:0], captured[e*ACC_BYTES + nb]};
                    want = TX_BITS'(signed'(c_all[base+e]));

                    if (got !== want) begin
                        errors = errors + 1;
                        if (errors < 10)
                            $display("  case %0d elem %0d (r%0d c%0d): got %0d want %0d",
                                     cs, e, e/K, e%K, got, want);
                    end
                end
            end
        end
    endtask

    bit case_ok;

    initial begin
        $readmemh(`VEC_A_HEX, a_all);
        $readmemh(`VEC_B_HEX, b_all);
        $readmemh(`VEC_C_HEX, c_all);

        $display("tb_matmul_uart: K=%0d ACC_BYTES=%0d", K, ACC_BYTES);
        $display("  expecting %0d bytes in, %0d bytes out per matrix",
                 IN_BYTES, OUT_BYTES);

        rx_data  = '0;
        rx_valid = 1'b0;
        rst      = 1'b1;
        repeat (6) @(negedge clk);
        rst = 1'b0;
        repeat (2) @(negedge clk);

        for (int cs = 0; cs < NCASES; cs++) begin
            run_case(cs, case_ok);
            if (!case_ok) begin
                $display("");
                $display("FAIL: stalled, see state dump above");
                $finish;
            end
            $display("  case %0d ok", cs);
        end

        $display("");
        if (errors == 0)
            $display("PASS: %0d matrices through the full byte protocol", NCASES);
        else
            $display("FAIL: %0d mismatched elements", errors);

        $finish;
    end

endmodule
