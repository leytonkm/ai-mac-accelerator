`timescale 1ns/1ps

module testbench;

    logic clk;
    logic rst;
    logic [15:0] a, b;
    logic [31:0] acc_in, acc_out;

    mac_cell dut (
        .clk(clk),
        .rst(rst),
        .a(a),
        .b(b),
        .acc_in(acc_in),
        .acc_out(acc_out)
    );

    // Clock generator: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/waveform.vcd");
        $dumpvars(0, testbench);

        rst = 1; a = 0; b = 0; acc_in = 0;
        @(posedge clk);   // wait one clock
        rst = 0;

        // Test 1
        @(posedge clk);
        a = 3; b = 4; acc_in = 10;

        @(posedge clk);   // Output is ready here
        $display("Test 1: acc_out = %d (should be 22)", acc_out);

        // Test 2
        a = 2; b = 5; acc_in = acc_out;

        @(posedge clk);   // Output is ready here
        $display("Test 2: acc_out = %d (should be 32)", acc_out);

        $finish;
    end

endmodule

