`timescale 1ns / 1ps

module tb_divider;
  logic        clk;
  logic [31:0] a;
  logic [31:0] b;
  logic        is_signed;
  logic        enable;
  logic [31:0] quotient;
  logic [31:0] remainder;
  logic        ready;

  int          pass_count = 0;
  int          fail_count = 0;

  divider uut (
      .clk(clk),
      .a(a),
      .b(b),
      .is_signed(is_signed),
      .enable(enable),
      .quotient(quotient),
      .remainder(remainder),
      .ready(ready)
  );

  // Clock generation: 10ns period
  initial clk = 0;
  always #5 clk = ~clk;

  task automatic check(input string label, input logic [31:0] q_expected,
                       input logic [31:0] q_actual, input logic [31:0] r_expected,
                       input logic [31:0] r_actual);
    if (q_actual !== q_expected || r_actual !== r_expected) begin
      $display("FAIL [%s]: got q=0x%08x r=0x%08x, expected q=0x%08x r=0x%08x", label, q_actual,
               r_actual, q_expected, r_expected);
      fail_count++;
    end else begin
      pass_count++;
    end
  endtask

  // Submit a division and wait for the result
  task automatic run_div(input logic [31:0] in_a, input logic [31:0] in_b, input logic in_signed);
    @(posedge clk);
    a         = in_a;
    b         = in_b;
    is_signed = in_signed;
    enable    = 1;
    @(posedge clk);
    enable = 0;
    // Wait for completion
    wait (ready);
    @(posedge clk);  // Let outputs settle
  endtask

  initial begin
    $dumpfile("sim/tb_divider.vcd");
    $dumpvars(0, tb_divider);

    a = 0;
    b = 0;
    is_signed = 0;
    enable = 0;

    // Wait for initial state to settle
    @(posedge clk);
    @(posedge clk);

    // -----------------------------------------------------------------------
    // Unsigned division (DIVU / REMU)
    // -----------------------------------------------------------------------

    // Test 1: 12 / 4 = 3 remainder 0
    run_div(32'd12, 32'd4, 0);
    check("12 / 4 unsigned", 32'd3, quotient, 32'd0, remainder);

    // Test 2: 11 / 3 = 3 remainder 2
    run_div(32'd11, 32'd3, 0);
    check("11 / 3 unsigned", 32'd3, quotient, 32'd2, remainder);

    // Test 3: 7 / 1 = 7 remainder 0
    run_div(32'd7, 32'd1, 0);
    check("7 / 1 unsigned", 32'd7, quotient, 32'd0, remainder);

    // Test 4: 5 / 5 = 1 remainder 0
    run_div(32'd5, 32'd5, 0);
    check("5 / 5 unsigned", 32'd1, quotient, 32'd0, remainder);

    // Test 5: 3 / 7 = 0 remainder 3
    run_div(32'd3, 32'd7, 0);
    check("3 / 7 unsigned", 32'd0, quotient, 32'd3, remainder);

    // Test 6: 0 / 5 = 0 remainder 0
    run_div(32'd0, 32'd5, 0);
    check("0 / 5 unsigned", 32'd0, quotient, 32'd0, remainder);

    // Test 7: 0xFFFFFFFF / 2 = 0x7FFFFFFF remainder 1
    run_div(32'hFFFFFFFF, 32'd2, 0);
    check("0xFFFFFFFF / 2 unsigned", 32'h7FFFFFFF, quotient, 32'd1, remainder);

    // Test 8: Large / large, no remainder
    run_div(32'h80000000, 32'h40000000, 0);
    check("0x80000000 / 0x40000000 unsigned", 32'd2, quotient, 32'd0, remainder);

    // -----------------------------------------------------------------------
    // Signed division (DIV / REM)
    // -----------------------------------------------------------------------

    // Test 9: 11 / 3 = 3 remainder 2 (both positive)
    run_div(32'd11, 32'd3, 1);
    check("11 / 3 signed", 32'd3, quotient, 32'd2, remainder);

    // Test 10: -11 / 3 = -3 remainder -2
    // (remainder takes sign of dividend per RISC-V spec)
    run_div(-32'sd11, 32'd3, 1);
    check("-11 / 3 signed", -32'sd3, quotient, -32'sd2, remainder);

    // Test 11: 11 / -3 = -3 remainder 2
    run_div(32'd11, -32'sd3, 1);
    check("11 / -3 signed", -32'sd3, quotient, 32'd2, remainder);

    // Test 12: -11 / -3 = 3 remainder -2
    run_div(-32'sd11, -32'sd3, 1);
    check("-11 / -3 signed", 32'd3, quotient, -32'sd2, remainder);

    // Test 13: -1 / 1 = -1 remainder 0
    run_div(32'hFFFFFFFF, 32'd1, 1);
    check("-1 / 1 signed", 32'hFFFFFFFF, quotient, 32'd0, remainder);

    // Test 14: 1 / -1 = -1 remainder 0
    run_div(32'd1, 32'hFFFFFFFF, 1);
    check("1 / -1 signed", 32'hFFFFFFFF, quotient, 32'd0, remainder);

    // -----------------------------------------------------------------------
    // RISC-V spec edge cases
    // -----------------------------------------------------------------------

    // Test 15: Unsigned divide by zero
    // Spec: quotient = 0xFFFFFFFF, remainder = dividend
    run_div(32'd7, 32'd0, 0);
    check("7 / 0 unsigned (div by zero)", 32'hFFFFFFFF, quotient, 32'd7, remainder);

    // Test 16: Signed divide by zero
    // Spec: quotient = 0xFFFFFFFF (-1), remainder = dividend
    run_div(-32'sd5, 32'd0, 1);
    check("-5 / 0 signed (div by zero)", 32'hFFFFFFFF, quotient, -32'sd5, remainder);

    // Test 17: Zero divided by zero
    // Spec: quotient = 0xFFFFFFFF, remainder = 0
    run_div(32'd0, 32'd0, 0);
    check("0 / 0 unsigned (div by zero)", 32'hFFFFFFFF, quotient, 32'd0, remainder);

    // Test 18: Signed overflow: MIN_INT / -1
    // Spec: quotient = MIN_INT (0x80000000), remainder = 0
    run_div(32'h80000000, 32'hFFFFFFFF, 1);
    check("MIN_INT / -1 signed (overflow)", 32'h80000000, quotient, 32'd0, remainder);

    // Test 19: MIN_INT / 1 = MIN_INT remainder 0 (no overflow, just a normal case)
    run_div(32'h80000000, 32'd1, 1);
    check("MIN_INT / 1 signed", 32'h80000000, quotient, 32'd0, remainder);

    // Test 20: MIN_INT / -2 = 0x40000000 remainder 0 (no overflow)
    run_div(32'h80000000, 32'hFFFFFFFE, 1);
    check("MIN_INT / -2 signed", 32'h40000000, quotient, 32'd0, remainder);

    // -----------------------------------------------------------------------
    // Summarise results
    // -----------------------------------------------------------------------
    #10;
    $display("-----------------------------------------------------------------------");
    $display("   %0d passed, %0d failed", pass_count, fail_count);
    $display("-----------------------------------------------------------------------");
    if (fail_count > 0) begin
      $display("*** TEST FAILURES REPORTED ***");
    end else begin
      $display("All tests passed.");
    end

    $finish;
  end

endmodule
