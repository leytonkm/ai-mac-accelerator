`timescale 1ns/1ps

module testbench;

    // Declare signals to connect to matmult2x2
    logic clk;
    logic rst;
    logic [15:0] a00, a01, a10, a11;
    logic [15:0] b00, b01, b10, b11;
    logic [31:0] c00, c01, c10, c11;

    // Instantiate the matmult2x2 module
    matmult2x2 dut (
        .clk(clk), .rst(rst),
        .a00(a00), .a01(a01), .a10(a10), .a11(a11),
        .b00(b00), .b01(b01), .b10(b10), .b11(b11),
        .c00(c00), .c01(c01), .c10(c10), .c11(c11)
    );

    // Generate a clock: toggles every 5ns
    initial clk = 0;
    always #5 clk = ~clk;

    // Test sequence
    initial begin
        // Dump waveforms for GTKWave
        $dumpfile("sim/waveform.vcd");
        $dumpvars(0, testbench);

        // Initial values
        rst = 1;
        a00 = 0; a01 = 0; a10 = 0; a11 = 0;
        b00 = 0; b01 = 0; b10 = 0; b11 = 0;

        @(posedge clk); // Wait a cycle

        rst = 0; // De-assert reset

        // Apply test inputs at next posedge
        @(posedge clk);
        a00 = 1; a01 = 2; a10 = 3; a11 = 4;
        b00 = 5; b01 = 6; b10 = 7; b11 = 8;

        // Wait a few cycles for the outputs to update (due to pipelined MACs, give it 2+ cycles)
        repeat (4) @(posedge clk);

        // Display results
        $display("C = [[%0d, %0d], [%0d, %0d]]", c00, c01, c10, c11);

        // Optionally, check correctness
        if (c00 == 19 && c01 == 22 && c10 == 43 && c11 == 50)
            $display("Test PASSED!");
        else
            $display("Test FAILED!");

        $finish;
    end

endmodule
