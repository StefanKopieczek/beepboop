
import alu_types::*;

// --- 32-Bit Instructions ------------------------------------------------------------------------
// Source: RISC-V Unprivileged Architecture s2.2
//
// R-type:  [  funct7  | rs2 | rs1 | f3 |  rd  | opcode ]
//          [  31:25   |24:20|19:15|14:12| 11:7 |  6:0   ]
//
// I-type:  [    imm[11:0]   | rs1 | f3 |  rd  | opcode ]
//          [     31:20      |19:15|14:12| 11:7 |  6:0   ]
//
// S-type:  [imm[11:5]| rs2 | rs1 | f3 |imm[4:0]| opcode ]
//          [  31:25  |24:20|19:15|14:12|  11:7  |  6:0   ]
//
// B-type:  [imm[12|10:5]| rs2 | rs1 | f3 |imm[4:1|11]| opcode ]
//          [   31:25    |24:20|19:15|14:12|   11:7    |  6:0   ]
//
// U-type:  [        imm[31:12]        |  rd  | opcode ]
//          [          31:12           | 11:7 |  6:0   ]
//
// J-type:  [ imm[20|10:1|11|19:12]    |  rd  | opcode ]
//          [          31:12           | 11:7 |  6:0   ]
// ------------------------------------------------------------------------------------------------

module decoder (
    input  logic    [31:0] instr,
    output logic           is_alu,
    output logic           is_immediate,
    output logic    [ 4:0] reg_src_a,
    output logic    [ 4:0] reg_src_b,
    output logic    [ 4:0] reg_dst,
    output logic    [31:0] immediate,
    output alu_op_t        alu_op,
    output logic           is_nop,
    output logic           is_exit,
    output logic           is_valid
);

  typedef enum {
    R,
    I,
    S,
    B,
    U,
    J,
    SYSTEM,  // ECALL and EBREAK
    FENCE,   // FENCE only
    UNKNOWN
  } instr_type_t;

  // --- Determine the instruction type -----------------------------------------------------------
  logic        [6:0] opcode;
  logic              opcode_is_valid;
  instr_type_t       instr_type;

  always_comb begin
    opcode = instr[6:0];
    case (opcode)
      7'b0110011: begin
        instr_type = R;
        opcode_is_valid = 1;
      end
      7'b0010011, 7'b0000011, 7'b1100111: begin
        instr_type = I;
        opcode_is_valid = 1;
      end
      7'b0100011: begin
        instr_type = S;
        opcode_is_valid = 1;
      end
      7'b1100011: begin
        instr_type = B;
        opcode_is_valid = 1;
      end
      7'b0110111, 7'b0010111: begin
        instr_type = U;
        opcode_is_valid = 1;
      end
      7'b1110011: begin
        instr_type = SYSTEM;
        opcode_is_valid = 1;
      end
      7'b0001111: begin
        instr_type = FENCE;
        opcode_is_valid = 1;
      end
      default: begin
        instr_type = UNKNOWN;
        opcode_is_valid = 0;
      end
    endcase
  end

  // --- Extract the fields -----------------------------------------------------------------------  
  logic [ 6:0] funct7;  // R only
  logic [ 4:0] rs2;  // R, S, and B
  logic [ 4:0] rs1;  // R, I, S, B
  logic [ 2:0] funct3;  // R, I, S, B
  logic [ 4:0] rd;  // R, I, U, J

  // R: absent
  // I: 12 bits
  // S: 12 bits
  // B: 13 bits, LSB always 0
  // U: 32 bits
  // J: 21 bits
  logic [31:0] imm;

  always_comb begin
    // RISC-V helpfully puts most fields at the same position regardless of the op type.
    // The exception is imm, which is of varying size and bit distribution.
    funct7 = instr[31:25];
    rs2 = instr[24:20];
    rs1 = instr[19:15];
    funct3 = instr[14:12];
    rd = instr[11:7];

    case (instr_type)
      R: imm = 'x;  // Unused for R-type
      I: imm = {20'b0, instr[31:20]};
      S: imm = {20'b0, instr[31:25], instr[11:7]};
      B: imm = {19'b0, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
      U: imm = {instr[31:12], 12'b0};
      J: imm = {11'b0, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
      SYSTEM: imm = {20'b0, instr[31:20]};
      FENCE: imm = 'x;  // Unused for FENCE
    endcase
  end

  // --- Handle ALU ops ---------------------------------------------------------------------------
  logic alu_is_immediate;
  logic [6:0] funct7_if_not_immediate = {7{!alu_is_immediate}} & funct7;
  logic [31:0] alu_immediate;
  logic alu_op_is_valid;
  always_comb begin
    if (opcode == 7'b0110011 || opcode == 7'b0010011) begin
      is_alu = 1;
      alu_is_immediate = (instr_type == I);

      // Pick out the ALU op.
      case ({
        alu_is_immediate, funct7_if_not_immediate, funct3
      })
        11'b00000000000: alu_op = ADD;
        11'b00100000000: alu_op = SUBTRACT;
        11'b00000000001: alu_op = SHIFT_LEFT;
        11'b00000000010: alu_op = LT_SIGNED;
        11'b00000000011: alu_op = LT_UNSIGNED;
        11'b00000000100: alu_op = XOR;
        11'b00000000101: alu_op = SHIFT_RIGHT_LOGICAL;
        11'b00100000101: alu_op = SHIFT_RIGHT_ARITHMETIC;
        11'b00000000110: alu_op = AND;
        11'b00000000111: alu_op = AND;
        11'b00000001000: alu_op = MULTIPLY_LOWER;
        11'b00000001001: alu_op = MULTIPLY_UPPER_SIGNED;
        11'b00000001010: alu_op = MULTIPLY_UPPER_SIGNED_UNSIGNED;
        11'b00000001011: alu_op = MULTIPLY_UPPER_UNSIGNED;
        11'b10000000000: alu_op = ADD;
        11'b10000000010: alu_op = LT_SIGNED;
        11'b10000000011: alu_op = LT_UNSIGNED;
        11'b10000000100: alu_op = XOR;
        11'b10000000110: alu_op = OR;
        11'b10000000111: alu_op = AND;
        11'b10000000001: alu_op = SHIFT_LEFT;
        11'b10000000101: alu_op = alu_op_t'(imm[30] ? SHIFT_RIGHT_ARITHMETIC : SHIFT_RIGHT_LOGICAL);
        default: alu_op = UNKNOWN_ALU_OP;
      endcase

      alu_op_is_valid = alu_op != UNKNOWN_ALU_OP;

      // Shifts abuse some of the imm bits to distinguish logical/arithmetic.
      // They actually only use the last 5 bits, so mask the others out.
      if (alu_is_immediate) begin
        if (funct3 == 3'b001 || funct3 == 3'b101) alu_immediate = {27'b0, imm[4:0]};
        else alu_immediate = imm;
      end else alu_immediate = 'x;
    end else begin
      is_alu = 0;
      alu_is_immediate = 'x;
      alu_op = UNKNOWN_ALU_OP;
      alu_op_is_valid = 'x;
      alu_immediate = 'x;
    end
  end

  // --- System and Fence -------------------------------------------------------------------------
  // FENCE is a no-op on a single core.
  // Proper handling of ECALL and EBREAK requires implementing some of the privileged architecture,
  // which I don't want to do yet. For now I'll treat ECALL as a clean exit and EBREAK as an abort.
  logic aborted;
  assign is_nop = (instr_type == FENCE);
  assign is_exit = (instr_type == SYSTEM);
  assign aborted = is_exit && imm[0] == 1;  // EBREAK


  // --- Plumb final outputs ----------------------------------------------------------------------
  assign immediate = is_alu ? alu_immediate : imm;
  assign is_valid = opcode_is_valid && (!is_alu || alu_op_is_valid) && !aborted;
  assign reg_src_a = rs1;
  assign reg_src_b = rs2;
  assign reg_dst = rd;
  assign is_immediate = alu_is_immediate;  // TODO: Extend me :) 

endmodule

