`timescale 1ns / 1ps

module tb_cpu;

  int   pass_count = 0;
  int   fail_count = 0;

  logic clk;
  logic reset;
  logic running;
  logic error;

  cpu uut (
      .clk(clk),
      .reset(reset),
      .running(running),
      .error(error)
  );

  // Clock generation: 10ns period
  initial clk = 0;
  always #5 clk = ~clk;

  // Task allowing a program to be run
  task automatic run_program(input string label, input logic [31:0] prog[]);
    automatic int cycles;
    // Ensure the CPU is in reset state before mucking with the memory.
    @(posedge clk);
    reset = 1;

    // Load in the program
    @(posedge clk);
    for (int i = 0; i < prog.size(); i++) uut.u_ram.mem[uut.RESET_VECTOR+i] = prog[i];

    // Allow the CPU to restart, and wait for it to finish running or for 1000 cycles.
    reset  = 0;
    cycles = 0;
    while (running && cycles < 1000) begin
      @(posedge clk);
      cycles++;
    end

    if (cycles >= 1000) begin
      $display("WARN[ %s]: CPU failed to stop during test", label);
    end

    // Let everything settle.
    @(posedge clk);
  endtask


  task automatic check_register(input string label, input logic [4:0] reg_idx,
                                input logic [31:0] expected);
    logic [31:0] actual = uut.u_registers.x[reg_idx];
    if (actual !== expected) begin
      $display("FAIL [%s]: register %2d was 0x%08x; expected 0x%08x", label, reg_idx, actual,
               expected);
      fail_count++;
    end else begin
      pass_count++;
    end
  endtask

  initial begin
    $dumpfile("sim/tb_cpu.fst");
    $dumpvars(0, tb_cpu);

    // -----------------------------------------------------------------------
    // Set register x1 to 0 by XOR
    // -----------------------------------------------------------------------
    begin : register_x1_to_0_xor
      static logic [31:0] prog[] = '{32'h0010C0B3};  // XOR x1, x1, x1
      run_program("register_x1_to_0_xor", prog);
      check_register("register_x1_to_0_xor", 1, 0);
    end

    // -----------------------------------------------------------------------
    // Set register x2 to 0 by ADDI x0, 0
    // -----------------------------------------------------------------------
    begin : register_x2_to_0_addi
      static logic [31:0] prog[] = '{32'h00000113};  // ADDI x2, x0, 0
      run_program("register_x2_to_0_addi", prog);
      check_register("register_x2_to_0_addi", 2, 0);
    end

    // -----------------------------------------------------------------------
    // Set register x1 to 17 by ADDI x0, 17
    // -----------------------------------------------------------------------
    begin : x1_to_17
      static
      logic [31:0]
      prog[] = '{
          32'h01100093  // ADDI x1, x0, 1          
      };
      run_program("x1_to_17", prog);
      check_register("x1_to_17", 1, 17);
    end

    // -----------------------------------------------------------------------
    // 1 + 2 = 3
    // -----------------------------------------------------------------------
    begin : one_plus_one
      static
      logic [31:0]
      prog[] = '{
          32'h00100093,  // ADDI x1, x0, 1
          32'h00200113,  // ADDI x2, x0, 2
          32'h002081B3  // ADD x3, x1, x2
      };
      run_program("one_plus_one", prog);
      check_register("one_plus_one", 3, 3);
    end

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
