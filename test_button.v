`timescale 1ns/1ps
module tb;
    reg  clk, rst_n, btn_in;
    wire btn_out, btn_pressed, btn_released;

    localparam integer CLK_FREQ_KHZ = 100;

    debouncer #(
        .CLK_FREQ_KHZ(CLK_FREQ_KHZ)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .btn_in     (btn_in),
        .btn_out    (btn_out),
        .btn_pressed(btn_pressed),
        .btn_released(btn_released)
    );

    // Derive timing from the testbench clock frequency parameter.
    localparam real    HALF_NS  = 500_000.0 / CLK_FREQ_KHZ;  // half-period in ns
    localparam integer D_CYCLES = CLK_FREQ_KHZ * 5;           // 5 ms debounce window

    initial clk = 0;
    always #(HALF_NS) clk = ~clk;

    integer fail_count = 0;

    task automatic chk;
        input       exp_out, exp_pressed, exp_released;
        input [8*64-1:0] label;
        begin
            if (btn_out !== exp_out) begin
                $display("FAIL: %0s | btn_out exp=%0b got=%0b", label, exp_out, btn_out);
                fail_count = fail_count + 1;
            end
            if (btn_pressed !== exp_pressed) begin
                $display("FAIL: %0s | btn_pressed exp=%0b got=%0b", label, exp_pressed, btn_pressed);
                fail_count = fail_count + 1;
            end
            if (btn_released !== exp_released) begin
                $display("FAIL: %0s | btn_released exp=%0b got=%0b", label, exp_released, btn_released);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        // Validate declared frequency is within spec
        if (CLK_FREQ_KHZ < 100) begin
            $display("FAIL: CLK_FREQ_KHZ=%0d must be >= 100 kHz to sample bounce events", CLK_FREQ_KHZ);
            fail_count = fail_count + 1;
        end

        rst_n = 0; btn_in = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // T1: reset clears all outputs
        chk(0, 0, 0, "T1: all outputs 0 after reset");

        // T2: D_CYCLES-1 stable HIGH — must not debounce yet
        btn_in = 1;
        repeat(D_CYCLES - 1) @(posedge clk);
        chk(0, 0, 0, "T2: D_CYCLES-1 cycles not sufficient");

        // T3: D_CYCLES-th edge — btn_out and btn_pressed must assert
        @(posedge clk);
        chk(1, 1, 0, "T3: D_CYCLES stable -> btn_out=1 btn_pressed=1");

        // T4: btn_pressed must clear after exactly one cycle
        @(posedge clk);
        chk(1, 0, 0, "T4: btn_pressed clears after 1 cycle");

        // T5: glitch (1-cycle LOW) resets counter; re-debounce keeps btn_out=1, no new pulse
        btn_in = 0; @(posedge clk);   // counter reset: btn_in changed 1->0
        btn_in = 1;                    // restore immediately
        repeat(D_CYCLES - 1) @(posedge clk);  // first edge resets again (0->1 change); then counts up
        chk(1, 0, 0, "T5a: D_CYCLES-1 post-glitch not enough");
        @(posedge clk);
        chk(1, 0, 0, "T5b: no pulse when btn_out does not change");

        // T6: debounce LOW — btn_out goes 1->0, btn_released asserts
        btn_in = 0;
        repeat(D_CYCLES - 1) @(posedge clk);
        chk(1, 0, 0, "T6a: D_CYCLES-1 LOW not sufficient");
        @(posedge clk);
        chk(0, 0, 1, "T6b: D_CYCLES LOW -> btn_out=0 btn_released=1");

        // T7: btn_released must clear after exactly one cycle
        @(posedge clk);
        chk(0, 0, 0, "T7: btn_released clears after 1 cycle");

        // T8: rapid toggle (10-cycle bursts) must not change output
        repeat(20) begin
            btn_in = ~btn_in;
            repeat(10) @(posedge clk);
        end
        btn_in = 0;  // ensure deterministic state (20 toggles from 0 => back to 0)
        @(posedge clk);
        chk(0, 0, 0, "T8: rapid toggle cannot change output");

        // T9: synchronous reset mid-count clears all outputs
        btn_in = 1;
        repeat(D_CYCLES / 2) @(posedge clk);
        rst_n = 0; @(posedge clk);
        chk(0, 0, 0, "T9: mid-count reset clears btn_out");
        rst_n = 1;

        // T10: must re-debounce from scratch after reset
        repeat(D_CYCLES - 1) @(posedge clk);
        chk(0, 0, 0, "T10a: post-reset D_CYCLES-1 not enough");
        @(posedge clk);
        chk(1, 1, 0, "T10b: post-reset D_CYCLES -> btn_out=1 btn_pressed=1");

        if (fail_count == 0)
            $display("ALL_TESTS_PASSED");
        else
            $display("TESTS_FAILED %0d", fail_count);

        $finish;
    end

    // Timeout: 200 ms simulation time (covers ~20 000 cycles at 100 kHz)
    initial begin
        #200_000_000;
        $display("TIMEOUT");
        $finish;
    end
endmodule
