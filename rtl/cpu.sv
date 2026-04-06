module cpu #(
    parameter MEMORY_WIDTH = 14,
    parameter RESET_VECTOR = 32'h100,
    parameter MEM_INIT = ""
) (
    input  logic clk,
    input  logic reset,
    output logic running,
    output logic error
);
  // --- Typedef and declarations -----------------------------------------------------------------
  typedef enum {
    INIT,
    REQUEST_INSTR,
    DECODE,
    WAIT_FOR_ALU,
    FINISHED,
    ERROR
  } cpu_state_t;

  // CPU state variables
  cpu_state_t        state;
  logic       [31:0] pc;

  // Registers
  logic       [ 4:0] reg_rd_addr_a;
  logic       [ 4:0] reg_rd_addr_b;
  logic       [31:0] reg_rd_data_a;
  logic       [31:0] reg_rd_data_b;
  logic              reg_wr_enable;
  logic       [ 4:0] reg_wr_addr;
  logic       [31:0] reg_wr_data;

  // Decoder output
  logic       [31:0] instr_d;  // Synonym for ram_ronly_dout
  logic       [31:0] instr_q;  // Latched after reading instr_d
  logic       [31:0] instr;  // Mux of instr_d and instr_q; using instr_q alone wastes a cycle.
  logic              is_alu_instr;
  logic              is_immediate_instr;
  logic       [ 4:0] instr_reg_a;
  logic       [ 4:0] instr_reg_b;
  logic       [ 4:0] instr_reg_dst;
  logic       [31:0] immediate_value;
  alu_op_t           instr_alu_op;
  logic              instr_is_valid;

  // ALU parameters
  logic              alu_enable;
  alu_op_t           alu_op;
  logic       [31:0] alu_arg_a;
  logic       [31:0] alu_arg_b;
  logic       [31:0] alu_out;
  logic              alu_ready;

  // RAM
  logic       [31:0] ram_ronly_addr;
  logic       [31:0] ram_ronly_dout;
  logic       [31:0] ram_rw_addr;
  logic       [31:0] ram_din;
  logic       [31:0] ram_rw_dout;
  logic       [ 3:0] ram_write_enable;

  // --- Submodule wiring -------------------------------------------------------------------------
  registers u_registers (
      .clk(clk),
      .rd_addr_a(reg_rd_addr_a),
      .rd_data_a(reg_rd_data_a),
      .rd_addr_b(reg_rd_addr_b),
      .rd_data_b(reg_rd_data_b),
      .wr_en(reg_wr_enable),
      .wr_addr(reg_wr_addr),
      .wr_data(reg_wr_data)
  );

  alu u_alu (
      .clk(clk),
      .a(alu_arg_a),
      .b(alu_arg_b),
      .op(alu_op),
      .enable(alu_enable),
      .out(alu_out),
      .ready(alu_ready)
  );

  decoder u_decoder (
      .instr(instr),
      .is_alu(is_alu_instr),
      .is_immediate(is_immediate_instr),
      .reg_src_a(instr_reg_a),
      .reg_src_b(instr_reg_b),
      .reg_dst(instr_reg_dst),
      .immediate(immediate_value),
      .alu_op(instr_alu_op),
      .is_valid(instr_is_valid)
  );

  ram #(
      .MEM_INIT(MEM_INIT)
  ) u_ram (
      .clk(clk),
      .addr_ronly(ram_ronly_addr),
      .dout_ronly(ram_ronly_dout),
      .addr_rw(ram_rw_addr),
      .din(ram_din),
      .dout_rw(ram_rw_dout),
      .write_enable(ram_write_enable)
  );

  // --- Initialization ---------------------------------------------------------------------------
  initial begin
    state = INIT;
  end

  // --- Instr mux --------------------------------------------------------------------------------
  // Save a clock cycle by decoding instr directly from RAM when a read has just occurred.
  // In all other states, we use a latched value of instr (i.e. instr_q).
  // This makes the decoder output stable, but prevents us needing to wait a cycle for the latch
  // right after the instruction is read.
  assign instr_d = ram_ronly_dout;
  assign instr = (state == DECODE) ? instr_d : instr_q;

  // --- Combinatorial: Reading from memory -------------------------------------------------------
  assign ram_ronly_addr = pc;

  // --- Combinatorial: ALU args ------------------------------------------------------------------
  always_comb begin
    reg_rd_addr_a = instr_reg_a;
    reg_rd_addr_b = instr_reg_b;
    alu_arg_a = reg_rd_data_a;
    alu_arg_b = (is_immediate_instr) ? immediate_value : reg_rd_data_b;
    alu_op = instr_alu_op;

    // Due to latch propagation, this causes ALU processing to start the cycle _after_ we enter
    // decode.
    alu_enable = (state == DECODE);
  end

  // --- Combinatorial: register writes -----------------------------------------------------------
  always_comb begin
    reg_wr_addr   = instr_reg_dst;

    // TODO extend this when we have other operations
    reg_wr_data   = alu_out;
    reg_wr_enable = (state == WAIT_FOR_ALU) && (alu_ready);
  end

  // --- Sequential logic -------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (reset) state <= INIT;
    else tick_state();
  end

  task automatic tick_state();
    case (state)
      INIT: begin
        // Initial startup, or following a reset.
        pc <= RESET_VECTOR;
        state <= REQUEST_INSTR;
      end
      REQUEST_INSTR: begin
        // Request the next instruction from RAM.            
        state <= DECODE;
      end
      DECODE: begin
        instr_q <= instr_d;
        if (is_alu_instr) begin
          // The ALU is loaded combinatorially so we just need to wait for ALU ready state
          state <= WAIT_FOR_ALU;
        end else begin
          // Not supported yet
          // TODO extend this when we have other operations
          state <= ERROR;
        end
      end
      WAIT_FOR_ALU: begin
        if (alu_ready) begin
          pc <= pc + 1;
          state <= REQUEST_INSTR;
        end
      end
    endcase
  endtask

  // --- Outputs ----------------------------------------------------------------------------------
  assign running = (state != FINISHED) && (state != ERROR);
  assign error   = (state == ERROR);

endmodule
