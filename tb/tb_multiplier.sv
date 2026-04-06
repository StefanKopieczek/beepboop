`timescale 1ns / 1ps

module tb_multiplier;
  logic [31:0] a;
  logic [31:0] b;
  logic        a_is_signed;
  logic        b_is_signed;
  logic [31:0] out_upper;
  logic [31:0] out_lower;

  int          pass_count = 0;
  int          fail_count = 0;

  multiplier uut (
      .a(a),
      .b(b),
      .a_is_signed(a_is_signed),
      .b_is_signed(b_is_signed),
      .out_upper(out_upper),
      .out_lower(out_lower)
  );

  task automatic check(input string label, input logic [31:0] upper_expected,
                       input logic [31:0] upper_actual, input logic [31:0] lower_expected,
                       input logic [31:0] lower_actual);
    if (upper_actual !== upper_expected || lower_actual !== lower_expected) begin
      $display("FAIL [%s]: got 0x%08x_%08x, expected 0x%08x_%08x", label, upper_actual,
               lower_actual, upper_expected, lower_expected);
      fail_count++;
    end else begin
      pass_count++;
    end
  endtask

  initial begin
    $dumpfile("sim/tb_multiplier.fst");
    $dumpvars(0, tb_multiplier);

    a = 32'd0;
    b = 32'd0;
    a_is_signed = 0;
    b_is_signed = 0;

    // -----------------------------------------------------------------------
    // Unsigned (MULHU / MUL)
    // -----------------------------------------------------------------------

    // Test 1: 3 * 4 = 12
    a = 32'd3;
    b = 32'd4;
    a_is_signed = 0;
    b_is_signed = 0;
    #1;
    check("3 * 4 unsigned", 32'h0, out_upper, 32'd12, out_lower);

    // Test 2: 0 * 5 = 0
    a = 32'd0;
    b = 32'd5;
    a_is_signed = 0;
    b_is_signed = 0;
    #1;
    check("0 * 5 unsigned", 32'h0, out_upper, 32'h0, out_lower);

    // Test 3: 7 * 0 = 0
    a = 32'd7;
    b = 32'd0;
    a_is_signed = 0;
    b_is_signed = 0;
    #1;
    check("7 * 0 unsigned", 32'h0, out_upper, 32'h0, out_lower);

    // Test 4: 0xFFFFFFFF * 2 = 0x00000001_FFFFFFFE
    a = 32'hFFFFFFFF;
    b = 32'd2;
    a_is_signed = 0;
    b_is_signed = 0;
    #1;
    check("0xFFFFFFFF * 2 unsigned", 32'h00000001, out_upper, 32'hFFFFFFFE, out_lower);

    // Test 5: 0xFFFFFFFF * 0xFFFFFFFF = 0xFFFFFFFE_00000001
    a = 32'hFFFFFFFF;
    b = 32'hFFFFFFFF;
    a_is_signed = 0;
    b_is_signed = 0;
    #1;
    check("0xFFFFFFFF^2 unsigned", 32'hFFFFFFFE, out_upper, 32'h00000001, out_lower);

    // -----------------------------------------------------------------------
    // Signed (MULH / MUL)
    // -----------------------------------------------------------------------

    // Test 6: -1 * -1 = 1
    a = 32'hFFFFFFFF;
    b = 32'hFFFFFFFF;
    a_is_signed = 1;
    b_is_signed = 1;
    #1;
    check("-1 * -1 signed", 32'h00000000, out_upper, 32'h00000001, out_lower);

    // Test 7: -2 * 3 = -6 = 0xFFFFFFFF_FFFFFFFA
    a = 32'hFFFFFFFE;
    b = 32'h00000003;
    a_is_signed = 1;
    b_is_signed = 1;
    #1;
    check("-2 * 3 signed", 32'hFFFFFFFF, out_upper, 32'hFFFFFFFA, out_lower);

    // Test 8: MIN_INT * -1 = 0x00000000_80000000
    a = 32'h80000000;
    b = 32'hFFFFFFFF;
    a_is_signed = 1;
    b_is_signed = 1;
    #1;
    check("MIN_INT * -1 signed", 32'h00000000, out_upper, 32'h80000000, out_lower);

    // Test 9: MIN_INT * MIN_INT = 2^62 = 0x40000000_00000000
    a = 32'h80000000;
    b = 32'h80000000;
    a_is_signed = 1;
    b_is_signed = 1;
    #1;
    check("MIN_INT^2 signed", 32'h40000000, out_upper, 32'h00000000, out_lower);

    // -----------------------------------------------------------------------
    // Mixed: signed * unsigned (MULHSU)
    // -----------------------------------------------------------------------

    // Test 10: -1 (signed) * 2 (unsigned) = -2 = 0xFFFFFFFF_FFFFFFFE
    a = 32'hFFFFFFFF;
    b = 32'h00000002;
    a_is_signed = 1;
    b_is_signed = 0;
    #1;
    check("-1s * 2u MULHSU", 32'hFFFFFFFF, out_upper, 32'hFFFFFFFE, out_lower);

    // Test 11: -2 (signed) * 3 (unsigned) = -6 = 0xFFFFFFFF_FFFFFFFA
    a = 32'hFFFFFFFE;
    b = 32'h00000003;
    a_is_signed = 1;
    b_is_signed = 0;
    #1;
    check("-2s * 3u MULHSU", 32'hFFFFFFFF, out_upper, 32'hFFFFFFFA, out_lower);

    // Test 12: 1 (signed) * 0xFFFFFFFF (unsigned) = 0x00000000_FFFFFFFF
    a = 32'h00000001;
    b = 32'hFFFFFFFF;
    a_is_signed = 1;
    b_is_signed = 0;
    #1;
    check("1s * 0xFFFFFFFF_u MULHSU", 32'h00000000, out_upper, 32'hFFFFFFFF, out_lower);

    // -----------------------------------------------------------------------
    // Lower bits are the same regardless of sign mode
    // -----------------------------------------------------------------------

    // Test 13: 0xFFFFFFFF * 3 — lower word should be 0xFFFFFFFD either way
    a = 32'hFFFFFFFF;
    b = 32'h00000003;

    a_is_signed = 0;
    b_is_signed = 0;
    #1;
    check("0xFFFFFFFF * 3 lower unsigned", 32'h00000002, out_upper, 32'hFFFFFFFD, out_lower);

    a_is_signed = 1;
    b_is_signed = 1;
    #1;
    check("0xFFFFFFFF * 3 lower signed", 32'hFFFFFFFF, out_upper, 32'hFFFFFFFD, out_lower);

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
