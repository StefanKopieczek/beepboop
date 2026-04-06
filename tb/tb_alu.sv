`timescale 1ns / 1ps

module tb_alu;
  import alu_types::*;

  logic           clk;
  logic    [31:0] a;
  logic    [31:0] b;
  alu_op_t        op;
  logic           enable;
  logic    [31:0] out;
  logic           ready;

  int             pass_count = 0;
  int             fail_count = 0;

  alu uut (
      .clk(clk),
      .a(a),
      .b(b),
      .op(op),
      .enable(enable),
      .out(out),
      .ready(ready)
  );

  // Clock generation: 10ns period
  initial clk = 0;
  always #5 clk = ~clk;

  task automatic check(input string label, input logic [31:0] expected, input logic [31:0] actual);
    if (actual !== expected) begin
      $display("FAIL [%s]: got 0x%08x, expected 0x%08x", label, actual, expected);
      fail_count++;
    end else begin
      pass_count++;
    end
  endtask

  // Submit an operation and wait for the result.
  // The divider receives a and b directly (not via the ALU latches),
  // so inputs and enable can be asserted on the same cycle.
  task automatic run_op(input logic [31:0] in_a, input logic [31:0] in_b, input alu_op_t in_op);
    @(posedge clk);
    a      = in_a;
    b      = in_b;
    op     = in_op;
    enable = 1;
    @(posedge clk);
    enable = 0;
    // Wait for completion
    wait (ready);
    @(posedge clk);  // Let outputs settle
  endtask

  initial begin
    $dumpfile("sim/tb_alu.fst");
    $dumpvars(0, tb_alu);

    a = 0;
    b = 0;
    op = ADD;
    enable = 0;

    // Wait for initial state to settle
    @(posedge clk);
    @(posedge clk);

    // -----------------------------------------------------------------------
    // ADD
    // -----------------------------------------------------------------------

    // Test: basic addition
    run_op(32'd10, 32'd20, ADD);
    check("10 + 20", 32'd30, out);

    // Test: overflow wraps
    run_op(32'hFFFFFFFF, 32'd1, ADD);
    check("0xFFFFFFFF + 1 (wrap)", 32'd0, out);

    // Test: identity
    run_op(32'd0, 32'd0, ADD);
    check("0 + 0", 32'd0, out);

    // -----------------------------------------------------------------------
    // SUBTRACT
    // -----------------------------------------------------------------------

    // Test: basic subtraction
    run_op(32'd20, 32'd10, SUBTRACT);
    check("20 - 10", 32'd10, out);

    // Test: underflow wraps
    run_op(32'd0, 32'd1, SUBTRACT);
    check("0 - 1 (wrap)", 32'hFFFFFFFF, out);

    // Test: self-subtract
    run_op(32'd5, 32'd5, SUBTRACT);
    check("5 - 5", 32'd0, out);

    // -----------------------------------------------------------------------
    // MULTIPLY_LOWER
    // -----------------------------------------------------------------------

    // Test: basic multiply
    run_op(32'd6, 32'd7, MULTIPLY_LOWER);
    check("6 * 7 lower", 32'd42, out);

    // Test: lower word discards upper bits
    run_op(32'h10000, 32'h10000, MULTIPLY_LOWER);
    check("0x10000 * 0x10000 lower (overflow)", 32'd0, out);

    // Test: multiply by zero
    run_op(32'd0, 32'd12345, MULTIPLY_LOWER);
    check("0 * 12345 lower", 32'd0, out);

    // -----------------------------------------------------------------------
    // MULTIPLY_UPPER_UNSIGNED
    // -----------------------------------------------------------------------

    // Test: upper word carries the overflow
    run_op(32'h10000, 32'h10000, MULTIPLY_UPPER_UNSIGNED);
    check("0x10000 * 0x10000 upper unsigned", 32'd1, out);

    // Test: small product fits in lower word, upper is zero
    run_op(32'd6, 32'd7, MULTIPLY_UPPER_UNSIGNED);
    check("6 * 7 upper unsigned (zero)", 32'd0, out);

    // Test: max * max unsigned
    // 0xFFFFFFFF * 0xFFFFFFFF = 0xFFFFFFFE_00000001
    run_op(32'hFFFFFFFF, 32'hFFFFFFFF, MULTIPLY_UPPER_UNSIGNED);
    check("MAX * MAX upper unsigned", 32'hFFFFFFFE, out);

    // -----------------------------------------------------------------------
    // MULTIPLY_UPPER_SIGNED (both operands signed)
    // -----------------------------------------------------------------------

    // Test: -1 * -1 = 1, upper = 0
    run_op(32'hFFFFFFFF, 32'hFFFFFFFF, MULTIPLY_UPPER_SIGNED);
    check("-1 * -1 upper signed", 32'd0, out);

    // Test: -1 * 2 = -2, 64-bit = 0xFFFFFFFF_FFFFFFFE
    run_op(32'hFFFFFFFF, 32'd2, MULTIPLY_UPPER_SIGNED);
    check("-1 * 2 upper signed", 32'hFFFFFFFF, out);

    // Test: MIN_INT * 2 = -4294967296 = 0xFFFFFFFF_00000000
    run_op(32'h80000000, 32'd2, MULTIPLY_UPPER_SIGNED);
    check("MIN_INT * 2 upper signed", 32'hFFFFFFFF, out);

    // -----------------------------------------------------------------------
    // MULTIPLY_UPPER_SIGNED_UNSIGNED (a signed, b unsigned)
    // -----------------------------------------------------------------------

    // Test: -1(s) * 2(u) = -2, upper = 0xFFFFFFFF
    run_op(32'hFFFFFFFF, 32'd2, MULTIPLY_UPPER_SIGNED_UNSIGNED);
    check("-1(s) * 2(u) upper", 32'hFFFFFFFF, out);

    // Test: 1(s) * 0xFFFFFFFF(u) = 0x00000000_FFFFFFFF, upper = 0
    run_op(32'd1, 32'hFFFFFFFF, MULTIPLY_UPPER_SIGNED_UNSIGNED);
    check("1(s) * 0xFFFFFFFF(u) upper", 32'd0, out);

    // -----------------------------------------------------------------------
    // DIVIDE_UNSIGNED
    // -----------------------------------------------------------------------

    // Test: exact division
    run_op(32'd12, 32'd4, DIVIDE_UNSIGNED);
    check("12 / 4 unsigned", 32'd3, out);

    // Test: truncating division
    run_op(32'd11, 32'd3, DIVIDE_UNSIGNED);
    check("11 / 3 unsigned", 32'd3, out);

    // Test: divide by zero (RISC-V spec: quotient = 0xFFFFFFFF)
    run_op(32'd7, 32'd0, DIVIDE_UNSIGNED);
    check("7 / 0 unsigned (div by zero)", 32'hFFFFFFFF, out);

    // -----------------------------------------------------------------------
    // DIVIDE_SIGNED
    // -----------------------------------------------------------------------

    // Test: negative dividend
    run_op(-32'sd11, 32'd3, DIVIDE_SIGNED);
    check("-11 / 3 signed", -32'sd3, out);

    // Test: negative divisor
    run_op(32'd11, -32'sd3, DIVIDE_SIGNED);
    check("11 / -3 signed", -32'sd3, out);

    // Test: both negative
    run_op(-32'sd11, -32'sd3, DIVIDE_SIGNED);
    check("-11 / -3 signed", 32'd3, out);

    // Test: signed overflow MIN_INT / -1 (RISC-V spec: quotient = MIN_INT)
    run_op(32'h80000000, 32'hFFFFFFFF, DIVIDE_SIGNED);
    check("MIN_INT / -1 signed (overflow)", 32'h80000000, out);

    // Test: signed divide by zero (RISC-V spec: quotient = 0xFFFFFFFF)
    run_op(-32'sd5, 32'd0, DIVIDE_SIGNED);
    check("-5 / 0 signed (div by zero)", 32'hFFFFFFFF, out);

    // -----------------------------------------------------------------------
    // REMAINDER_UNSIGNED
    // -----------------------------------------------------------------------

    // Test: basic remainder
    run_op(32'd11, 32'd3, REMAINDER_UNSIGNED);
    check("11 %% 3 unsigned", 32'd2, out);

    // Test: remainder by zero (RISC-V spec: remainder = dividend)
    run_op(32'd7, 32'd0, REMAINDER_UNSIGNED);
    check("7 %% 0 unsigned (div by zero)", 32'd7, out);

    // -----------------------------------------------------------------------
    // REMAINDER_SIGNED
    // -----------------------------------------------------------------------

    // Test: remainder takes sign of dividend
    run_op(-32'sd11, 32'd3, REMAINDER_SIGNED);
    check("-11 %% 3 signed", -32'sd2, out);

    run_op(32'd11, -32'sd3, REMAINDER_SIGNED);
    check("11 %% -3 signed", 32'd2, out);

    // Test: signed overflow remainder MIN_INT % -1 (RISC-V spec: remainder = 0)
    run_op(32'h80000000, 32'hFFFFFFFF, REMAINDER_SIGNED);
    check("MIN_INT %% -1 signed (overflow)", 32'd0, out);

    // -----------------------------------------------------------------------
    // AND / OR / XOR
    // -----------------------------------------------------------------------

    run_op(32'hFF00FF00, 32'h0F0F0F0F, AND);
    check("AND", 32'h0F000F00, out);

    run_op(32'hFF00FF00, 32'h0F0F0F0F, OR);
    check("OR", 32'hFF0FFF0F, out);

    run_op(32'hFF00FF00, 32'h0F0F0F0F, XOR);
    check("XOR", 32'hF00FF00F, out);

    // Test: XOR with self gives zero
    run_op(32'hDEADBEEF, 32'hDEADBEEF, XOR);
    check("XOR self (zero)", 32'd0, out);

    // -----------------------------------------------------------------------
    // SHIFT_LEFT
    // -----------------------------------------------------------------------

    run_op(32'd1, 32'd4, SHIFT_LEFT);
    check("1 << 4", 32'd16, out);

    run_op(32'hDEADBEEF, 32'd0, SHIFT_LEFT);
    check("DEADBEEF << 0 (no shift)", 32'hDEADBEEF, out);

    run_op(32'd1, 32'd31, SHIFT_LEFT);
    check("1 << 31", 32'h80000000, out);

    // Test: bits shifted out are lost
    run_op(32'hFFFFFFFF, 32'd16, SHIFT_LEFT);
    check("0xFFFFFFFF << 16", 32'hFFFF0000, out);

    // Test: only lower 5 bits of shift amount used (RISC-V spec)
    run_op(32'd1, 32'd32, SHIFT_LEFT);
    check("1 << 32 (uses amt[4:0]=0)", 32'd1, out);

    // -----------------------------------------------------------------------
    // SHIFT_RIGHT_LOGICAL
    // -----------------------------------------------------------------------

    run_op(32'h80000000, 32'd4, SHIFT_RIGHT_LOGICAL);
    check("0x80000000 >>> 4 logical", 32'h08000000, out);

    run_op(32'hDEADBEEF, 32'd0, SHIFT_RIGHT_LOGICAL);
    check("DEADBEEF >>> 0 logical (no shift)", 32'hDEADBEEF, out);

    run_op(32'h80000000, 32'd31, SHIFT_RIGHT_LOGICAL);
    check("0x80000000 >>> 31 logical", 32'd1, out);

    // Test: zero-fills from the left
    run_op(32'hFFFFFFFF, 32'd16, SHIFT_RIGHT_LOGICAL);
    check("0xFFFFFFFF >>> 16 logical", 32'h0000FFFF, out);

    // Test: only lower 5 bits of shift amount used
    run_op(32'hDEADBEEF, 32'd32, SHIFT_RIGHT_LOGICAL);
    check("DEADBEEF >>> 32 logical (uses amt[4:0]=0)", 32'hDEADBEEF, out);

    // -----------------------------------------------------------------------
    // SHIFT_RIGHT_ARITHMETIC
    // -----------------------------------------------------------------------

    // Test: positive value (MSB=0) behaves like logical shift
    run_op(32'h7FFFFFFF, 32'd4, SHIFT_RIGHT_ARITHMETIC);
    check("0x7FFFFFFF >> 4 arith (positive)", 32'h07FFFFFF, out);

    // Test: negative value (MSB=1) sign-extends
    run_op(32'h80000000, 32'd4, SHIFT_RIGHT_ARITHMETIC);
    check("0x80000000 >> 4 arith (sign ext)", 32'hF8000000, out);

    run_op(32'hFFFFFFFF, 32'd16, SHIFT_RIGHT_ARITHMETIC);
    check("0xFFFFFFFF >> 16 arith (all ones)", 32'hFFFFFFFF, out);

    run_op(32'h80000000, 32'd31, SHIFT_RIGHT_ARITHMETIC);
    check("0x80000000 >> 31 arith", 32'hFFFFFFFF, out);

    // Test: no shift preserves value
    run_op(32'h80000000, 32'd0, SHIFT_RIGHT_ARITHMETIC);
    check("0x80000000 >> 0 arith (no shift)", 32'h80000000, out);

    // Test: only lower 5 bits of shift amount used
    run_op(32'h80000000, 32'd32, SHIFT_RIGHT_ARITHMETIC);
    check("0x80000000 >> 32 arith (uses amt[4:0]=0)", 32'h80000000, out);

    // -----------------------------------------------------------------------
    // EQ
    // -----------------------------------------------------------------------

    run_op(32'd5, 32'd5, EQ);
    check("5 == 5", 32'd1, out);

    run_op(32'd5, 32'd6, EQ);
    check("5 == 6", 32'd0, out);

    run_op(32'd0, 32'd0, EQ);
    check("0 == 0", 32'd1, out);

    // -----------------------------------------------------------------------
    // GT / GTE / LT / LTE (unsigned)
    // -----------------------------------------------------------------------

    run_op(32'd10, 32'd5, GT_UNSIGNED);
    check("10 > 5 unsigned", 32'd1, out);

    run_op(32'd5, 32'd10, GT_UNSIGNED);
    check("5 > 10 unsigned", 32'd0, out);

    run_op(32'd5, 32'd5, GT_UNSIGNED);
    check("5 > 5 unsigned (false)", 32'd0, out);

    run_op(32'd5, 32'd5, GTE_UNSIGNED);
    check("5 >= 5 unsigned", 32'd1, out);

    run_op(32'd4, 32'd5, GTE_UNSIGNED);
    check("4 >= 5 unsigned", 32'd0, out);

    run_op(32'd5, 32'd10, LT_UNSIGNED);
    check("5 < 10 unsigned", 32'd1, out);

    run_op(32'd10, 32'd5, LT_UNSIGNED);
    check("10 < 5 unsigned", 32'd0, out);

    run_op(32'd5, 32'd5, LTE_UNSIGNED);
    check("5 <= 5 unsigned", 32'd1, out);

    run_op(32'd6, 32'd5, LTE_UNSIGNED);
    check("6 <= 5 unsigned", 32'd0, out);

    // -----------------------------------------------------------------------
    // GT / GTE / LT / LTE (signed)
    // -----------------------------------------------------------------------

    // Test: signedness changes comparison outcome
    run_op(32'hFFFFFFFF, 32'd1, LT_SIGNED);
    check("-1 < 1 signed", 32'd1, out);

    run_op(32'hFFFFFFFF, 32'd1, GT_SIGNED);
    check("-1 > 1 signed", 32'd0, out);

    // Contrast: same bit patterns, unsigned comparison
    run_op(32'hFFFFFFFF, 32'd1, GT_UNSIGNED);
    check("0xFFFFFFFF > 1 unsigned", 32'd1, out);

    // Test: extremes
    run_op(32'h80000000, 32'h7FFFFFFF, LT_SIGNED);
    check("MIN_INT < MAX_INT signed", 32'd1, out);

    run_op(32'h7FFFFFFF, 32'h80000000, GT_SIGNED);
    check("MAX_INT > MIN_INT signed", 32'd1, out);

    run_op(32'h80000000, 32'h80000000, GTE_SIGNED);
    check("MIN_INT >= MIN_INT signed", 32'd1, out);

    run_op(32'hFFFFFFFE, 32'hFFFFFFFF, LTE_SIGNED);
    check("-2 <= -1 signed", 32'd1, out);

    run_op(32'hFFFFFFFF, 32'hFFFFFFFE, LTE_SIGNED);
    check("-1 <= -2 signed", 32'd0, out);

    // -----------------------------------------------------------------------
    // Enable / ready timing: single-cycle operations
    // -----------------------------------------------------------------------
    // For single-cycle ops, ready should be high once the latched inputs
    // have propagated through the combinatorial logic (i.e. one settle
    // cycle after the enable edge).

    @(posedge clk);
    a = 32'd3;
    b = 32'd4;
    op = ADD;
    enable = 1;
    @(posedge clk);
    enable = 0;
    @(posedge clk);  // Let outputs settle (same as run_op's wait+settle)
    if (ready !== 1'b1) begin
      $display("FAIL [timing: ADD ready after 1 cycle]: ready=%b, expected 1", ready);
      fail_count++;
    end else begin
      pass_count++;
    end
    check("timing: ADD result", 32'd7, out);

    // Repeat for a different single-cycle op family (comparator)
    @(posedge clk);
    a = 32'd1;
    b = 32'd2;
    op = LT_UNSIGNED;
    enable = 1;
    @(posedge clk);
    enable = 0;
    @(posedge clk);  // Let outputs settle
    if (ready !== 1'b1) begin
      $display("FAIL [timing: LT_UNSIGNED ready after 1 cycle]: ready=%b, expected 1", ready);
      fail_count++;
    end else begin
      pass_count++;
    end
    check("timing: LT_UNSIGNED result", 32'd1, out);

    // -----------------------------------------------------------------------
    // Enable / ready timing: multi-cycle division
    // -----------------------------------------------------------------------
    // Division should take more than one cycle; ready must not be asserted
    // one settle cycle after enable.

    @(posedge clk);
    a = 32'd100;
    b = 32'd7;
    op = DIVIDE_UNSIGNED;
    enable = 1;
    @(posedge clk);
    enable = 0;
    @(posedge clk);  // Same settle window as the single-cycle tests above
    if (ready !== 1'b0) begin
      $display("FAIL [timing: DIVIDE ready too early]: ready asserted on first cycle");
      fail_count++;
    end else begin
      pass_count++;
    end
    // Now wait for the divider to finish.
    wait (ready);
    @(posedge clk);
    check("100 / 7 unsigned (timing)", 32'd14, out);

    // -----------------------------------------------------------------------
    // Back-to-back operations
    // -----------------------------------------------------------------------
    // Ensure the ALU correctly handles consecutive operations without stale
    // results bleeding through.

    run_op(32'd1, 32'd1, ADD);
    check("back-to-back: 1 + 1", 32'd2, out);

    run_op(32'd2, 32'd3, MULTIPLY_LOWER);
    check("back-to-back: 2 * 3", 32'd6, out);

    run_op(32'd10, 32'd3, REMAINDER_UNSIGNED);
    check("back-to-back: 10 %% 3", 32'd1, out);

    run_op(32'd99, 32'd99, EQ);
    check("back-to-back: 99 == 99", 32'd1, out);

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
