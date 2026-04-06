`timescale 1ns / 1ps

module tb_ram;

  localparam MAX_ADDRESS = 15;
  logic        clk;

  logic [31:0] addr_ronly;
  logic [31:0] dout_ronly;

  logic [ 3:0] write_enable;
  logic [31:0] addr_rw;
  logic [31:0] din;
  logic [31:0] dout_rw;

  int          pass_count = 0;
  int          fail_count = 0;

  ram #(
      .MAX_ADDRESS(MAX_ADDRESS)
  ) uut (
      .clk(clk),
      .addr_ronly(addr_ronly),
      .dout_ronly(dout_ronly),
      .write_enable(write_enable),
      .addr_rw(addr_rw),
      .din(din),
      .dout_rw(dout_rw)
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

  // Write a full word via port B and wait one cycle for the synchronous read
  // to reflect the write.
  task automatic write_word(input logic [31:0] addr, input logic [31:0] data);
    @(posedge clk);
    write_enable = 4'b1111;
    addr_rw = addr;
    din = data;
    @(posedge clk);
    write_enable = 4'b0000;
  endtask

  // Write with an arbitrary byte-enable mask via port B.
  task automatic write_bytes(input logic [31:0] addr, input logic [31:0] data,
                             input logic [3:0] mask);
    @(posedge clk);
    write_enable = mask;
    addr_rw = addr;
    din = data;
    @(posedge clk);
    write_enable = 4'b0000;
  endtask

  // Present an address on port A and return the result after the synchronous
  // read latency.
  task automatic read_a(input logic [31:0] addr);
    @(posedge clk);
    addr_ronly = addr;
    @(posedge clk);  // Wait for synchronous read output
  endtask

  // Present an address on port B (with writes disabled) and return the
  // result after the synchronous read latency.
  task automatic read_b(input logic [31:0] addr);
    @(posedge clk);
    write_enable = 4'b0000;
    addr_rw = addr;
    @(posedge clk);  // Wait for synchronous read output
  endtask

  initial begin
    $dumpfile("sim/tb_ram.vcd");
    $dumpvars(0, tb_ram);

    addr_ronly = 0;
    write_enable = 4'b0000;
    addr_rw = 0;
    din = 0;

    // Wait for initial state to settle
    @(posedge clk);
    @(posedge clk);

    // -----------------------------------------------------------------------
    // Basic word write / read via RW port
    // -----------------------------------------------------------------------

    // Test: write and read back a word
    write_word(4'd0, 32'hDEADBEEF);
    read_b(4'd0);
    check("word write/read addr 0", 32'hDEADBEEF, dout_rw);

    // Test: write to a different address
    write_word(4'd5, 32'hCAFEBABE);
    read_b(4'd5);
    check("word write/read addr 5", 32'hCAFEBABE, dout_rw);

    // Test: previous address is not clobbered
    read_b(4'd0);
    check("addr 0 still intact", 32'hDEADBEEF, dout_rw);

    // -----------------------------------------------------------------------
    // Timing test
    // -----------------------------------------------------------------------
    // Tests that values are available to read the cycle after the write
    // (set up for write, write happens on next posedge; set up for read, read on next posedge)
    write_word(4'b1011, 32'hBABEBABE);
    addr_ronly = 4'b1011;
    @(posedge clk);
    #1;
    check("reads available after one cycle", 32'hBABEBABE, dout_ronly);


    // -----------------------------------------------------------------------
    // Read-only access
    // -----------------------------------------------------------------------

    // Test: ronly read of data written by rw
    read_a(4'd0);
    check("ronly reads addr 0", 32'hDEADBEEF, dout_ronly);

    read_a(4'd5);
    check("ronly reads addr 5", 32'hCAFEBABE, dout_ronly);

    // -----------------------------------------------------------------------
    // Byte-enable writes (sb)
    // -----------------------------------------------------------------------

    // Seed address 1 with a known pattern, then overwrite individual bytes
    write_word(4'd1, 32'hAABBCCDD);

    // Test: overwrite byte 0 only
    write_bytes(4'd1, 32'h000000FF, 4'b0001);
    read_b(4'd1);
    check("sb byte 0", 32'hAABBCCFF, dout_rw);

    // Test: overwrite byte 1 only
    write_bytes(4'd1, 32'h0000EE00, 4'b0010);
    read_b(4'd1);
    check("sb byte 1", 32'hAABBEEFF, dout_rw);

    // Test: overwrite byte 2 only
    write_bytes(4'd1, 32'h00110000, 4'b0100);
    read_b(4'd1);
    check("sb byte 2", 32'hAA11EEFF, dout_rw);

    // Test: overwrite byte 3 only
    write_bytes(4'd1, 32'h22000000, 4'b1000);
    read_b(4'd1);
    check("sb byte 3", 32'h2211EEFF, dout_rw);

    // -----------------------------------------------------------------------
    // Byte-enable writes (sh — halfword)
    // -----------------------------------------------------------------------

    write_word(4'd2, 32'hFFFFFFFF);

    // Test: overwrite lower halfword
    write_bytes(4'd2, 32'h00001234, 4'b0011);
    read_b(4'd2);
    check("sh lower half", 32'hFFFF1234, dout_rw);

    // Test: overwrite upper halfword
    write_bytes(4'd2, 32'hABCD0000, 4'b1100);
    read_b(4'd2);
    check("sh upper half", 32'hABCD1234, dout_rw);

    // -----------------------------------------------------------------------
    // Read-first behaviour on rw port
    // -----------------------------------------------------------------------
    // Non-blocking assignments evaluate all RHS before updating, so dout_rw
    // captures the old value of mem[addr_rw] on the same cycle as a write.
    // The new data appears on the following read cycle.

    write_word(4'd3, 32'hAAAAAAAA);  // Seed with a known value

    @(posedge clk);
    write_enable = 4'b1111;
    addr_rw = 4'd3;
    din = 32'h12345678;
    @(posedge clk);
    write_enable = 4'b0000;
    // dout_rw should hold the OLD value from before this write
    check("read-first: dout has old value", 32'hAAAAAAAA, dout_rw);

    // Now read back to confirm the write did land
    read_b(4'd3);
    check("read-first: new value on next read", 32'h12345678, dout_rw);

    // -----------------------------------------------------------------------
    // Simultaneous access from both ports
    // -----------------------------------------------------------------------

    // Seed two addresses
    write_word(4'd6, 32'h66666666);
    write_word(4'd7, 32'h77777777);

    // Read different addresses from both ports at the same time
    @(posedge clk);
    addr_ronly = 4'd6;
    addr_rw = 4'd7;
    write_enable = 4'b0000;
    @(posedge clk);
    check("simultaneous: read port reads addr 6", 32'h66666666, dout_ronly);
    check("simultaneous: rw port reads addr 7", 32'h77777777, dout_rw);

    // -----------------------------------------------------------------------
    // Write via RW port while reading a different address on read port
    // -----------------------------------------------------------------------

    @(posedge clk);
    addr_ronly = 4'd6;  // Read port reads addr 6
    write_enable = 4'b1111;  // RW port writes addr 8
    addr_rw = 4'd8;
    din = 32'hBEEFBEEF;
    @(posedge clk);
    write_enable = 4'b0000;
    check("read port undisturbed during RW port write", 32'h66666666, dout_ronly);

    // Verify the write landed
    read_b(4'd8);
    check("RW port write landed at addr 8", 32'hBEEFBEEF, dout_rw);

    // -----------------------------------------------------------------------
    // Byte-enable with no bits set (no-op write)
    // -----------------------------------------------------------------------

    write_word(4'd9, 32'h99999999);
    write_bytes(4'd9, 32'h00000000, 4'b0000);
    read_b(4'd9);
    check("zero byte-enable is a no-op", 32'h99999999, dout_rw);

    // -----------------------------------------------------------------------
    // Overwrite same address multiple times
    // -----------------------------------------------------------------------

    write_word(4'd10, 32'h11111111);
    write_word(4'd10, 32'h22222222);
    write_word(4'd10, 32'h33333333);
    read_b(4'd10);
    check("triple overwrite keeps last value", 32'h33333333, dout_rw);

    // Confirm via read port
    read_a(4'd10);
    check("triple overwrite via port A", 32'h33333333, dout_ronly);


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
