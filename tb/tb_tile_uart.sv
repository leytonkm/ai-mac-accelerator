`timescale 1ns/1ps

// Byte-level testbench for tile_uart.


`include "tile_vectors.svh"

module tb_tile_uart;

    localparam int K         = 8;
    localparam int DATA_W    = 16;
    localparam int MAX_T     = 8;
    localparam int ACC_W     = 48;
    localparam int ACC_BYTES = ACC_W / 8;

    logic clk = 1'b0;
    logic rst = 1'b1;

    logic [7:0] rx_data  = '0;
    logic       rx_valid = 1'b0;
    logic [7:0] tx_data;
    logic       tx_send;
    logic       tx_busy;
    logic [1:0] status;

    tile_uart #(.K (K), .DATA_W (DATA_W), .MAX_T (MAX_T), .ACC_W (ACC_W)) dut (
        .clk (clk), .rst (rst),
        .rx_data (rx_data), .rx_valid (rx_valid),
        .tx_data (tx_data), .tx_send (tx_send), .tx_busy (tx_busy),
        .status (status)
    );

    always #5 clk = ~clk;

    logic [3:0] busy_cnt = '0;
    always_ff @(posedge clk) begin
        if (tx_send)            busy_cnt <= 4'd5;
        else if (busy_cnt != 0) busy_cnt <= busy_cnt - 1'b1;
    end
    assign tx_busy = (busy_cnt != 0);

    localparam int MAXBYTES = 4 + 4096 * ACC_BYTES;
    logic       clear_cap = 1'b0;
    logic [7:0] captured [0:MAXBYTES-1];
    int         cap_idx = 0;

    always_ff @(posedge clk) begin
        if (clear_cap)      cap_idx <= 0;
        else if (tx_send) begin
            captured[cap_idx] <= tx_data;
            cap_idx           <= cap_idx + 1;
        end
    end

    int rx_bytes = 0;
    always_ff @(posedge clk) if (!rst && rx_valid) rx_bytes <= rx_bytes + 1;

    logic [K*DATA_W-1:0] a_words [0:511];
    logic [K*DATA_W-1:0] b_words [0:511];
    logic [ACC_W-1:0]    c_exp   [0:4095];

    int errors_total = 0;

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

    task automatic send_words(input int words, input bit use_b);
        logic [K*DATA_W-1:0] w;
        logic [DATA_W-1:0]   e;
        begin
            for (int i = 0; i < words; i++) begin
                w = use_b ? b_words[i] : a_words[i];
                for (int j = 0; j < K; j++) begin
                    e = w[j*DATA_W +: DATA_W];
                    send_byte(e[15:8]);
                    send_byte(e[7:0]);
                end
            end
        end
    endtask

    task automatic run_one(input int t,
                           input string aname, input string bname,
                           input string cname);
        int words, nres, expect_bytes, timeout, errs;
        logic [31:0] cyc;
        logic signed [ACC_W-1:0] got;
        begin
            words        = K * t * t;
            nres         = K * K * t * t;
            expect_bytes = 4 + nres * ACC_BYTES;

            $readmemh(aname, a_words);
            $readmemh(bname, b_words);
            $readmemh(cname, c_exp);

            if ((^a_words[0] === 1'bx) || (^c_exp[0] === 1'bx)) begin
                $display("FATAL: vectors did not load from %s", `TV_DIR);
                $display("       run: python model/gen_tiles.py");
                $finish;
            end

            @(negedge clk);
            clear_cap = 1'b1;
            @(negedge clk);
            clear_cap = 1'b0;

            send_byte(t[7:0]);
            send_words(words, 1'b0);
            send_words(words, 1'b1);

            timeout = 0;
            while (cap_idx < expect_bytes && timeout < 2000000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (cap_idx < expect_bytes) begin
                $display("  STALL T=%0d: %0d of %0d bytes out",
                         t, cap_idx, expect_bytes);
                $display("    dut.state=%0d rx_bytes=%0d (sent %0d)",
                         dut.state, rx_bytes, 1 + 2*words*K*2);
                $display("    word_addr=%0d sel_b=%0b elem=%0d half=%0b",
                         dut.word_addr, dut.sel_b, dut.elem, dut.half);
                $display("    ctrl busy=%0b done=%0b res_sent=%0d",
                         dut.ctrl_busy, dut.ctrl_done, dut.res_sent);
                errors_total = errors_total + 1;
                $finish;
            end

            cyc = {captured[0], captured[1], captured[2], captured[3]};

            errs = 0;
            for (int r = 0; r < nres; r++) begin
                got = '0;
                for (int nb = 0; nb < ACC_BYTES; nb++)
                    got = {got[ACC_W-9:0], captured[4 + r*ACC_BYTES + nb]};
                if (got !== $signed(c_exp[r])) begin
                    errs = errs + 1;
                    if (errs < 5)
                        $display("    result %0d: got %0d want %0d",
                                 r, got, $signed(c_exp[r]));
                end
            end

            errors_total = errors_total + errs;
            $display("  T=%0d N=%0d  %0d results  %0d errors  %0d cycles (%.2f us)",
                     t, t*K, nres, errs, cyc, cyc / 100.0);
        end
    endtask

    initial begin
        rst = 1'b1;
        repeat (8) @(negedge clk);
        rst = 1'b0;
        repeat (2) @(negedge clk);

        $display("tb_tile_uart: K=%0d MAX_T=%0d ACC_BYTES=%0d",
                 K, MAX_T, ACC_BYTES);

        run_one(1, {`TV_DIR, "/a_t1.hex"}, {`TV_DIR, "/b_t1.hex"},
                   {`TV_DIR, "/c_t1.hex"});
        run_one(2, {`TV_DIR, "/a_t2.hex"}, {`TV_DIR, "/b_t2.hex"},
                   {`TV_DIR, "/c_t2.hex"});
        run_one(4, {`TV_DIR, "/a_t4.hex"}, {`TV_DIR, "/b_t4.hex"},
                   {`TV_DIR, "/c_t4.hex"});

        $display("");
        if (errors_total == 0)
            $display("PASS: byte protocol correct at every size");
        else
            $display("FAIL: %0d errors", errors_total);
        $finish;
    end

endmodule
