`timescale 1ns/1ps

// Self-checking testbench for matmul_top.
//     python model/gen_vectors.py
`include "vector_params.svh"

module tb_systolic;

    localparam int K       = `VEC_K;
    localparam int DATA_W  = `VEC_DATA_W;
    localparam int ACC_W   = `VEC_ACC_W;
    localparam int NCASES  = `VEC_NUM_CASES;
    localparam int ELEMS   = K * K;
    localparam int TIMEOUT = 10 * K + 50;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic start = 1'b0;
    logic done;

    logic signed [DATA_W-1:0] a_mat [K][K];
    logic signed [DATA_W-1:0] b_mat [K][K];
    logic signed [ACC_W-1:0]  c_mat [K][K];

    matmul_top #(
        .K      (K),
        .DATA_W (DATA_W),
        .ACC_W  (ACC_W)
    ) dut (
        .clk   (clk),
        .rst   (rst),
        .start (start),
        .a_mat (a_mat),
        .b_mat (b_mat),
        .c_mat (c_mat),
        .done  (done)
    );

    always #5 clk = ~clk;

    // Flat storage for every case, exactly as $readmemh wants it.
    logic [DATA_W-1:0] a_all [0:NCASES*ELEMS-1];
    logic [DATA_W-1:0] b_all [0:NCASES*ELEMS-1];
    logic [ACC_W-1:0]  c_all [0:NCASES*ELEMS-1];

    int errors      = 0;
    int bad_cases   = 0;
    int reported    = 0;
    int cycle_count = 0;

    // Operands are driven on the negative edge so the DUT always samples
    // settled values on the positive edge. No races, no #delays sprinkled
    // through the test.
    task automatic run_case(input int cs);
        int base;
        int case_errors;
        begin
            base        = cs * ELEMS;
            case_errors = 0;

            @(negedge clk);
            for (int i = 0; i < K; i++) begin
                for (int j = 0; j < K; j++) begin
                    a_mat[i][j] = a_all[base + i*K + j];
                    b_mat[i][j] = b_all[base + i*K + j];
                end
            end

            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            cycle_count = 0;
            while (done !== 1'b1) begin
                @(negedge clk);
                cycle_count = cycle_count + 1;
                if (cycle_count > TIMEOUT) begin
                    $display("FATAL: case %0d never asserted done (>%0d cycles)",
                             cs, TIMEOUT);
                    $fatal(1);
                end
            end

            for (int i = 0; i < K; i++) begin
                for (int j = 0; j < K; j++) begin
                    if (c_mat[i][j] !== c_all[base + i*K + j]) begin
                        errors      = errors + 1;
                        case_errors = case_errors + 1;
                        if (reported < 20) begin
                            reported = reported + 1;
                            $display("  case %0d  C[%0d][%0d]  got %0d (%h)  want %0d (%h)",
                                     cs, i, j,
                                     $signed(c_mat[i][j]), c_mat[i][j],
                                     $signed(c_all[base + i*K + j]),
                                     c_all[base + i*K + j]);
                        end
                    end
                end
            end

            if (case_errors != 0) begin
                bad_cases = bad_cases + 1;
                if (reported <= 20)
                    $display("  ^ case %0d failed, %0d elements, named on line %0d of names.txt", cs, case_errors, cs + 1);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("dump")) begin
            $dumpfile("sim/tb_systolic.vcd");
            $dumpvars(0, tb_systolic);
        end

        $readmemh(`VEC_A_HEX, a_all);
        $readmemh(`VEC_B_HEX, b_all);
        $readmemh(`VEC_C_HEX, c_all);

        $display("tb_systolic: K=%0d DATA_W=%0d ACC_W=%0d cases=%0d",
                 K, DATA_W, ACC_W, NCASES);

        rst = 1'b1;
        repeat (4) @(negedge clk);
        rst = 1'b0;
        @(negedge clk);

        for (int cs = 0; cs < NCASES; cs++) begin
            run_case(cs);
            if ((cs + 1) % 250 == 0)
                $display("  ... %0d/%0d cases", cs + 1, NCASES);
        end

        $display("");
        if (errors == 0) begin
            $display("PASS: %0d/%0d cases, %0d elements checked",
                     NCASES, NCASES, NCASES * ELEMS);
            $finish;
        end else begin
            $display("FAIL: %0d/%0d cases bad, %0d mismatched elements",
                     bad_cases, NCASES, errors);
            $fatal(1);
        end
        $finish;
    end

endmodule
