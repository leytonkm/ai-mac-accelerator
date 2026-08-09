`timescale 1ns/1ps

// Testbench for tile_ctrl: full N x N multiply on the K x K array.


`include "tile_vectors.svh"

module tb_tile_ctrl;

    localparam int K      = 8;
    localparam int DATA_W = 16;
    localparam int MAX_T  = 16;
    localparam int ACC_W  = 48;
    localparam int DEPTH  = K * MAX_T * MAX_T;
    localparam int ADDR_W = $clog2(DEPTH);

    logic clk = 1'b0;
    logic rst = 1'b1;

    logic                    wr_en   = 1'b0;
    logic                    wr_sel  = 1'b0;
    logic [ADDR_W-1:0]       wr_addr = '0;
    logic [K*DATA_W-1:0]     wr_data = '0;

    logic                    start = 1'b0;
    logic [$clog2(MAX_T+1)-1:0] t_tiles = '0;
    logic                    busy, done;
    logic [31:0]             compute_cycles;

    logic signed [ACC_W-1:0] out_data;
    logic                    out_valid;
    logic                    out_ready = 1'b1;

    tile_ctrl #(
        .K (K), .DATA_W (DATA_W), .MAX_T (MAX_T), .ACC_W (ACC_W)
    ) dut (
        .clk (clk), .rst (rst),
        .wr_en (wr_en), .wr_sel (wr_sel), .wr_addr (wr_addr), .wr_data (wr_data),
        .start (start), .t_tiles (t_tiles),
        .busy (busy), .done (done), .compute_cycles (compute_cycles),
        .out_data (out_data), .out_valid (out_valid), .out_ready (out_ready)
    );

    always #5 clk = ~clk;

    localparam int MAXW = 2048;
    localparam int MAXR = 16384;

    logic [K*DATA_W-1:0] a_words [0:MAXW-1];
    logic [K*DATA_W-1:0] b_words [0:MAXW-1];
    logic [ACC_W-1:0]    c_exp   [0:MAXR-1];

    int errors_total = 0;

    task automatic load_operands(input int words);
        begin
            for (int i = 0; i < words; i++) begin
                @(negedge clk);
                wr_en = 1'b1; wr_sel = 1'b0;
                wr_addr = ADDR_W'(i); wr_data = a_words[i];
                @(negedge clk);
                wr_sel = 1'b1; wr_data = b_words[i];
            end
            @(negedge clk);
            wr_en = 1'b0;
        end
    endtask

    // Backpressure pattern so the emit handshake is exercised and the cycle
    // counter is shown to exclude stalls.
    int stall_mod = 0;
    int beat = 0;
    always_ff @(posedge clk) begin
        beat <= beat + 1;
        out_ready <= (stall_mod == 0) ? 1'b1 : ((beat % stall_mod) != 0);
    end

    task automatic run_one(input int t, input int words, input int nres,
                           input string aname, input string bname,
                           input string cname, input int stall);
        int idx;
        int errs;
        int cyc;
        begin
            $readmemh(aname, a_words);
            $readmemh(bname, b_words);
            $readmemh(cname, c_exp);

            // $readmemh only warns on a missing file, leaving the arrays X.
            // Comparing against X then reports zero errors, which looks like a
            // pass. Fail loudly instead.
            if ((^a_words[0] === 1'bx) || (^b_words[0] === 1'bx) ||
                (^c_exp[0]   === 1'bx)) begin
                $display("FATAL: vectors did not load from %s", `TV_DIR);
                $display("       regenerate on this machine: python model/gen_tiles.py");
                $finish;
            end

            stall_mod = stall;
            load_operands(words);

            @(negedge clk);
            t_tiles = t[$clog2(MAX_T+1)-1:0];
            start   = 1'b1;
            @(negedge clk);
            start = 1'b0;

            idx  = 0;
            errs = 0;
            while (idx < nres) begin
                @(posedge clk);
                if (out_valid && out_ready) begin
                    if (out_data !== $signed(c_exp[idx])) begin
                        errs = errs + 1;
                        if (errs < 6)
                            $display("    result %0d: got %0d want %0d",
                                     idx, out_data, $signed(c_exp[idx]));
                    end
                    idx = idx + 1;
                end
            end

            while (!done) @(posedge clk);
            cyc = compute_cycles;

            errors_total = errors_total + errs;
            $display("  T=%0d N=%0d  %0d results  %0d errors  %0d cycles (%.2f us)%s",
                     t, t*K, nres, errs, cyc, cyc / 100.0,
                     stall ? "  [with backpressure]" : "");
            @(negedge clk);
        end
    endtask

    initial begin
        rst = 1'b1;
        repeat (8) @(negedge clk);
        rst = 1'b0;
        repeat (2) @(negedge clk);

        $display("tb_tile_ctrl: K=%0d ACC_W=%0d", K, ACC_W);
        $display("  cycle counts exclude stalls waiting on out_ready");
        $display("");

        `ifdef TV0_T
        run_one(`TV0_T, `TV0_WORDS, `TV0_RES,
                {`TV_DIR, "/a_t1.hex"}, {`TV_DIR, "/b_t1.hex"},
                {`TV_DIR, "/c_t1.hex"}, 0);
        `endif
        `ifdef TV1_T
        run_one(`TV1_T, `TV1_WORDS, `TV1_RES,
                {`TV_DIR, "/a_t2.hex"}, {`TV_DIR, "/b_t2.hex"},
                {`TV_DIR, "/c_t2.hex"}, 0);
        `endif
        `ifdef TV2_T
        run_one(`TV2_T, `TV2_WORDS, `TV2_RES,
                {`TV_DIR, "/a_t4.hex"}, {`TV_DIR, "/b_t4.hex"},
                {`TV_DIR, "/c_t4.hex"}, 0);
        `endif
        `ifdef TV3_T
        run_one(`TV3_T, `TV3_WORDS, `TV3_RES,
                {`TV_DIR, "/a_t8.hex"}, {`TV_DIR, "/b_t8.hex"},
                {`TV_DIR, "/c_t8.hex"}, 0);
        // same case again with a stalling consumer, to prove the cycle
        // counter is measuring the design and not the link
        run_one(`TV3_T, `TV3_WORDS, `TV3_RES,
                {`TV_DIR, "/a_t8.hex"}, {`TV_DIR, "/b_t8.hex"},
                {`TV_DIR, "/c_t8.hex"}, 4);
        `endif

        $display("");
        if (errors_total == 0) $display("PASS: tiling matches the model at every size");
        else                   $display("FAIL: %0d mismatched results", errors_total);
        $finish;
    end

endmodule
