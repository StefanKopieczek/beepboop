`timescale 1ns / 1ps

module tb_cpu;
  int   pass_count = 0;
  int   fail_count = 0;

  int   ecall = 32'h00000073;
  int   max_cycles = 10000000;

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

    $display("[%0t] Starting test: %s", $time, label);

    // Ensure the CPU is in reset state before mucking with the memory.
    @(posedge clk);
    reset = 1;

    // Load in the program
    @(posedge clk);
    for (int i = 0; i < prog.size(); i++) uut.u_ram.mem[(uut.RESET_VECTOR>>2)+i] = prog[i];

    // Allow the CPU to restart, and wait for it to finish running or for 1000 cycles.
    reset  = 0;
    cycles = 0;
    while (running && cycles < max_cycles) begin
      @(posedge clk);
      cycles++;
    end

    if (cycles >= max_cycles) begin
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
      static
      logic [31:0]
      prog[] = '{
          32'h0010C0B3,  // XOR x1, x1, x1
          ecall
      };
      run_program("register_x1_to_0_xor", prog);
      check_register("register_x1_to_0_xor", 1, 0);
    end

    // -----------------------------------------------------------------------
    // Set register x2 to 0 by ADDI x0, 0
    // -----------------------------------------------------------------------
    begin : register_x2_to_0_addi
      static
      logic [31:0]
      prog[] = '{
          32'h00000113,  // ADDI x2, x0, 0
          ecall
      };
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
          32'h01100093,  // ADDI x1, x0, 1          
          ecall
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
          32'h002081B3,  // ADD x3, x1, x2
          ecall
      };
      run_program("one_plus_one", prog);
      check_register("one_plus_one", 3, 3);
    end

    // -----------------------------------------------------------------------
    // 100 / 3 and 100 % 3
    // -----------------------------------------------------------------------
    begin : a_hundred_divided_by_3
      static
      logic [31:0]
      prog[] = '{
          32'h06400f93,  // ADDI x31, x0, 100
          32'h00300093,  // ADDI x1, x0, 3
          32'h021fc233,  // DIV x4, x31, x1
          32'h021fe2b3,  // REM x5, x31, x1
          ecall
      };
      run_program("a_hundred_divided_by_3", prog);
      check_register("a_hundred_divided_by_3 (quot)", 4, 33);
      check_register("a_hundred_divided_by_3 (rem)", 5, 1);
    end

    // -----------------------------------------------------------------------
    // Count to 100.
    // -----------------------------------------------------------------------
    begin : count_to_100
      static
      logic [31:0]
      prog[] = '{
          32'h0010c0b3,  // XOR x1, x1, x1
          32'h06400113,  // ADDI x2, x0, 100
          // loop:
          32'h00108093,  // ADDI x1, x1, 1
          32'hfe20cee3,  // BLT x1, x2, loop
          ecall
      };
      run_program("count_to_100", prog);
      check_register("count_to_100", 1, 100);
    end

    // -----------------------------------------------------------------------
    // Calculate the 20th Fibonnaci number, F20 = 6765.
    // -----------------------------------------------------------------------
    begin : fib_20
      static
      logic [31:0]
      prog[] = '{
          32'h00000293,  // ADDI x5, x0, 0      (F(i-1) = 0)
          32'h00100313,  // ADDI x6, x0, 1      (F(i)   = 1)
          32'h00100e13,  // ADDI x28, x0, 1     (i = 1)
          32'h01400e93,  // ADDI x29, x0, 20    (n = 20)
          // loop:
          32'h006283b3,  // ADD  x7, x5, x6
          32'h000302b3,  // ADD  x5, x6, x0
          32'h00038333,  // ADD  x6, x7, x0
          32'h001e0e13,  // ADDI x28, x28, 1
          32'hffde18e3,  // BNE  x28, x29, loop
          ecall
      };
      run_program("fib_20", prog);
      check_register("fib_20", 6, 6765);
    end

    // -----------------------------------------------------------------------
    // Calculate the 100th prime number. Should be 541.
    // -----------------------------------------------------------------------
    begin : prime_100
      static
      logic [31:0]
      prog[] = '{
          32'h00000293,  // ADDI x5,  x0, 0
          32'h00100313,  // ADDI x6,  x0, 1
          32'h06400e93,  // ADDI x29, x0, 100
          // next:
          32'h00130313,  // ADDI x6,  x6, 1
          32'h00200393,  // ADDI x7,  x0, 2
          // check:
          32'h02738e33,  // MUL  x28, x7, x7
          32'h01c34a63,  // BLT  x6, x28, prime
          32'h02736e33,  // REM  x28, x6, x7
          32'hfe0e06e3,  // BEQ  x28, x0, next
          32'h00138393,  // ADDI x7,  x7, 1
          32'hfe0006e3,  // BEQ  x0, x0, check   (was JAL; swapped for B-type)
          // prime:
          32'h00128293,  // ADDI x5,  x5, 1
          32'hfdd29ee3,  // BNE  x5, x29, next
          ecall
      };
      run_program("prime_100", prog);
      check_register("prime_100", 6, 541);
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
