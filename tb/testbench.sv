`timescale 1ns/1ps

module testbench;
    logic clk;
    logic rst;
    logic [15:0] a00, a01, a10, a11;
    logic [15:0] b00, b01, b10, b11;
    logic [31:0] c00, c01, c10, c11;

    matmult2x2 dut (
        .clk(clk), .rst(rst),
        .a00(a00), .a01(a01), .a10(a10), .a11(a11),
        .b00(b00), .b01(b01), .b10(b10), .b11(b11),
        .c00(c00), .c01(c01), .c10(c10), .c11(c11)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/waveform.vcd");
        $dumpvars(0, testbench);

        rst = 1;
        a00 = 0; a01 = 0; a10 = 0; a11 = 0;
        b00 = 0; b01 = 0; b10 = 0; b11 = 0;

        @(posedge clk);
        rst = 0;

        @(posedge clk);
        a00 = 1; a01 = 2; a10 = 3; a11 = 4;
        b00 = 5; b01 = 6; b10 = 7; b11 = 8;

        repeat (20) @(posedge clk);     // can change num of cycles

        $display("C = [[%0d, %0d], [%0d, %0d]]", c00, c01, c10, c11);

        if (c00 == 19 && c01 == 22 && c10 == 43 && c11 == 50)
            $display("Test PASSED!");
        else
            $display("Test FAILED!");

        #200;  // add delay, to extend test

        $finish;
    end
endmodule
