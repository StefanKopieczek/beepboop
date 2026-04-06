`timescale 1ns / 1ps

module tb_comparator;
  logic [31:0] a;
  logic [31:0] b;
  logic        is_signed;
  logic        less_than;
  logic        greater_than;
  logic        equal;

  int          pass_count = 0;
  int          fail_count = 0;

  comparator uut (
      .a(a),
      .b(b),
      .is_signed(is_signed),
      .less_than(less_than),
      .greater_than(greater_than),
      .equal(equal)
  );

  task automatic check(input string label, input logic lt_expected, input logic lt_actual,
                       input logic gt_expected, input logic gt_actual, input logic eq_expected,
                       input logic eq_actual);
    if (lt_actual !== lt_expected || gt_actual !== gt_expected || eq_actual !== eq_expected) begin
      $display("FAIL [%s]: got lt=%0b gt=%0b eq=%0b, expected lt=%0b gt=%0b eq=%0b", label,
               lt_actual, gt_actual, eq_actual, lt_expected, gt_expected, eq_expected);
      fail_count++;
    end else begin
      pass_count++;
    end
  endtask

  initial begin
    $dumpfile("sim/tb_comparator.fst");
    $dumpvars(0, tb_comparator);

    a = 32'd0;
    b = 32'd0;
    is_signed = 0;

    // -----------------------------------------------------------------------
    // Unsigned comparisons
    // -----------------------------------------------------------------------

    // Test 1: 0 == 0
    a = 32'd0;
    b = 32'd0;
    is_signed = 0;
    #1;
    check("0 == 0 unsigned", 1'b0, less_than, 1'b0, greater_than, 1'b1, equal);

    // Test 2: 3 < 4
    a = 32'd3;
    b = 32'd4;
    is_signed = 0;
    #1;
    check("3 < 4 unsigned", 1'b1, less_than, 1'b0, greater_than, 1'b0, equal);

    // Test 3: 4 > 3
    a = 32'd4;
    b = 32'd3;
    is_signed = 0;
    #1;
    check("4 > 3 unsigned", 1'b0, less_than, 1'b1, greater_than, 1'b0, equal);

    // Test 4: 7 == 7
    a = 32'd7;
    b = 32'd7;
    is_signed = 0;
    #1;
    check("7 == 7 unsigned", 1'b0, less_than, 1'b0, greater_than, 1'b1, equal);

    // Test 5: 0 < MAX
    a = 32'h00000000;
    b = 32'hFFFFFFFF;
    is_signed = 0;
    #1;
    check("0 < MAX unsigned", 1'b1, less_than, 1'b0, greater_than, 1'b0, equal);

    // Test 6: MAX > 0
    a = 32'hFFFFFFFF;
    b = 32'h00000000;
    is_signed = 0;
    #1;
    check("MAX > 0 unsigned", 1'b0, less_than, 1'b1, greater_than, 1'b0, equal);

    // Test 7: MAX == MAX
    a = 32'hFFFFFFFF;
    b = 32'hFFFFFFFF;
    is_signed = 0;
    #1;
    check("MAX == MAX unsigned", 1'b0, less_than, 1'b0, greater_than, 1'b1, equal);

    // Test 8: 0x80000000 > 0x7FFFFFFF (unsigned: 2^31 > 2^31-1)
    a = 32'h80000000;
    b = 32'h7FFFFFFF;
    is_signed = 0;
    #1;
    check("0x80000000 > 0x7FFFFFFF unsigned", 1'b0, less_than, 1'b1, greater_than, 1'b0, equal);

    // -----------------------------------------------------------------------
    // Signed comparisons
    // -----------------------------------------------------------------------

    // Test 9: 0 == 0
    a = 32'd0;
    b = 32'd0;
    is_signed = 1;
    #1;
    check("0 == 0 signed", 1'b0, less_than, 1'b0, greater_than, 1'b1, equal);

    // Test 10: -1 < 0
    a = 32'hFFFFFFFF;
    b = 32'h00000000;
    is_signed = 1;
    #1;
    check("-1 < 0 signed", 1'b1, less_than, 1'b0, greater_than, 1'b0, equal);

    // Test 11: 0 > -1
    a = 32'h00000000;
    b = 32'hFFFFFFFF;
    is_signed = 1;
    #1;
    check("0 > -1 signed", 1'b0, less_than, 1'b1, greater_than, 1'b0, equal);

    // Test 12: -1 == -1
    a = 32'hFFFFFFFF;
    b = 32'hFFFFFFFF;
    is_signed = 1;
    #1;
    check("-1 == -1 signed", 1'b0, less_than, 1'b0, greater_than, 1'b1, equal);

    // Test 13: MIN_INT < MAX_INT
    a = 32'h80000000;
    b = 32'h7FFFFFFF;
    is_signed = 1;
    #1;
    check("MIN_INT < MAX_INT signed", 1'b1, less_than, 1'b0, greater_than, 1'b0, equal);

    // Test 14: MAX_INT > MIN_INT
    a = 32'h7FFFFFFF;
    b = 32'h80000000;
    is_signed = 1;
    #1;
    check("MAX_INT > MIN_INT signed", 1'b0, less_than, 1'b1, greater_than, 1'b0, equal);

    // Test 15: MIN_INT == MIN_INT
    a = 32'h80000000;
    b = 32'h80000000;
    is_signed = 1;
    #1;
    check("MIN_INT == MIN_INT signed", 1'b0, less_than, 1'b0, greater_than, 1'b1, equal);

    // Test 16: -2 < -1
    a = 32'hFFFFFFFE;
    b = 32'hFFFFFFFF;
    is_signed = 1;
    #1;
    check("-2 < -1 signed", 1'b1, less_than, 1'b0, greater_than, 1'b0, equal);

    // Test 17: 1 > -1
    a = 32'h00000001;
    b = 32'hFFFFFFFF;
    is_signed = 1;
    #1;
    check("1 > -1 signed", 1'b0, less_than, 1'b1, greater_than, 1'b0, equal);

    // -----------------------------------------------------------------------
    // Sign mode flips the result (same inputs, different interpretation)
    // -----------------------------------------------------------------------

    // Test 18: 0xFFFFFFFF vs 0x00000001 — unsigned: GT, signed: LT
    a = 32'hFFFFFFFF;
    b = 32'h00000001;

    is_signed = 0;
    #1;
    check("0xFFFFFFFF vs 1 unsigned (GT)", 1'b0, less_than, 1'b1, greater_than, 1'b0, equal);

    is_signed = 1;
    #1;
    check("0xFFFFFFFF vs 1 signed (LT)", 1'b1, less_than, 1'b0, greater_than, 1'b0, equal);

    // Test 19: 0x80000000 vs 0x7FFFFFFF — unsigned: GT, signed: LT
    a = 32'h80000000;
    b = 32'h7FFFFFFF;

    is_signed = 0;
    #1;
    check("0x80000000 vs 0x7FFFFFFF unsigned (GT)", 1'b0, less_than, 1'b1, greater_than, 1'b0,
          equal);

    is_signed = 1;
    #1;
    check("0x80000000 vs 0x7FFFFFFF signed (LT)", 1'b1, less_than, 1'b0, greater_than, 1'b0, equal);

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
