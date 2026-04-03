`timescale 1ns / 1ps

module tb_regfile;
  logic clk;
  logic [4:0] rd_addr_a, rd_addr_b;
  logic [31:0] rd_data_a, rd_data_b;
  logic wr_en;
  logic [4:0] wr_addr;
  logic [31:0] wr_data;

  int pass_count = 0;
  int fail_count = 0;

  registers uut (
      .clk(clk),
      .rd_addr_a(rd_addr_a),
      .rd_data_a(rd_data_a),
      .rd_addr_b(rd_addr_b),
      .rd_data_b(rd_data_b),
      .wr_en(wr_en),
      .wr_addr(wr_addr),
      .wr_data(wr_data)
  );

  // --- 10 ns period ---
  initial clk = 0;
  always #5 clk = ~clk;

  // --- Helper to check the value at a read port ---
  task automatic check(input string port, input logic [4:0] addr, input logic [31:0] expected,
                       input logic [31:0] actual);

    if (actual !== expected) begin
      $display("$FAIL: x%0d port %s = 0x%08x, expected 0x%08x (t=%0t)", addr, port, actual,
               expected, $time);
      fail_count++;
    end else begin
      pass_count++;
    end
  endtask

  initial begin
    $dumpfile("sim/tb_regfile.vcd");
    $dumpvars(0, tb_regfile);

    wr_en = 0;
    wr_addr = 5'd0;
    wr_data = 32'd0;
    rd_addr_a = 5'd0;
    rd_addr_b = 5'd0;

    // -----------------------------------------------------------------------
    // Test 1: x0 reads as 0 on both ports
    // -----------------------------------------------------------------------
    @(negedge clk);
    rd_addr_a = 5'd0;
    rd_addr_b = 5'd0;
    #1;
    check("A", rd_addr_a, 32'd0, rd_data_a);
    check("B", rd_addr_b, 32'd0, rd_data_b);

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
