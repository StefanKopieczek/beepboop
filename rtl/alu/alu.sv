import alu_types::*;

// Usage: 
// Parent modules should set a, b and op; and then assert 'enable'.
// They should then wait for 'ready' to go high. In most cases
// this will occur by the next clock posedge, but for longer operations
// like division, multiple clock pulses may be required.

module alu (
    input  logic           clk,
    input  logic    [31:0] a,
    input  logic    [31:0] b,
    input  alu_op_t        op,
    input  logic           enable,
    output logic    [31:0] out,
    output logic           ready
);

  // --- Declarations -------------------------------------------------------------------------------

  // Latch a, b and op defensively.
  logic [31:0] a_latch, b_latch;
  alu_op_t op_latch;

  // Set up the parameters of the various submodules.
  logic [31:0] adder_out;
  logic multiplier_a_is_signed;
  logic multiplier_b_is_signed;
  logic [31:0] multiplier_out_h;
  logic [31:0] multiplier_out_l;
  logic divider_is_signed;
  logic [31:0] divider_out_quot;
  logic [31:0] divider_out_rem;
  logic divider_out_ready;
  logic comparator_is_signed;
  logic comparator_out_lt;
  logic comparator_out_gt;
  logic comparator_out_eq;

  // -- Sequential: Latch inputs ------------------------------------------------------------------
  // The ALU top level is mostly combinatoric. We just need to latch the inputs.
  always_ff @(posedge clk) begin
    op_latch <= op;
    a_latch  <= a;

    // Minor hack: negate b if subtracting so we can just use the adder.
    b_latch  <= (op == SUBTRACT) ? -b : b;
  end

  // --- Combinatoric: Set up submodules ----------------------------------------------------------
  adder u_adder (
      .a  (a_latch),
      .b  (b_latch),
      .out(adder_out)
  );

  assign multiplier_a_is_signed = (op == MULTIPLY_UPPER_SIGNED || op == MULTIPLY_UPPER_SIGNED_UNSIGNED);
  assign multiplier_b_is_signed = (op == MULTIPLY_UPPER_SIGNED);
  multiplier u_multiplier (
      .a(a_latch),
      .b(b_latch),
      .a_is_signed(multiplier_a_is_signed),
      .b_is_signed(multiplier_b_is_signed),
      .out_upper(multiplier_out_h),
      .out_lower(multiplier_out_l)
  );

  assign divider_is_signed = (op == DIVIDE_SIGNED || op == REMAINDER_SIGNED);
  divider u_divider (
      .clk(clk),
      .enable(enable),
      .a(a),  // Not an error - the divider has its own latching,
      .b(b),  // so we save a clock cycle by not using the ALU latched values.
      .is_signed(divider_is_signed),
      .quotient(divider_out_quot),
      .remainder(divider_out_rem),
      .ready(divider_out_ready)
  );

  assign comparator_is_signed = (op == GT_SIGNED || op == GTE_SIGNED || op == LT_SIGNED || op == LTE_SIGNED);
  comparator u_comparator (
      .a(a_latch),
      .b(b_latch),
      .is_signed(comparator_is_signed),
      .less_than(comparator_out_lt),
      .greater_than(comparator_out_gt),
      .equal(comparator_out_eq)
  );

  // --- Combinatoric: Derive output --------------------------------------------------------------
  always_comb begin
    case (op_latch)
      ADD, SUBTRACT: begin
        ready = 1;
        out   = adder_out;
      end
      MULTIPLY_LOWER: begin
        ready = 1;
        out   = multiplier_out_l;
      end
      MULTIPLY_UPPER_UNSIGNED, MULTIPLY_UPPER_SIGNED, MULTIPLY_UPPER_SIGNED_UNSIGNED: begin
        ready = 1;
        out   = multiplier_out_h;
      end
      DIVIDE_UNSIGNED, DIVIDE_SIGNED: begin
        ready = divider_out_ready;
        out   = divider_out_quot;
      end
      REMAINDER_UNSIGNED, REMAINDER_SIGNED: begin
        ready = divider_out_ready;
        out   = divider_out_rem;
      end
      AND: begin
        ready = 1;
        out   = a_latch & b_latch;
      end
      OR: begin
        ready = 1;
        out   = a_latch | b_latch;
      end
      XOR: begin
        ready = 1;
        out   = a_latch ^ b_latch;
      end
      EQ: begin
        ready = 1;
        out   = {31'b0, comparator_out_eq};
      end
      GT_UNSIGNED, GT_SIGNED: begin
        ready = 1;
        out   = {31'b0, comparator_out_gt};
      end
      GTE_UNSIGNED, GTE_SIGNED: begin
        ready = 1;
        out   = {31'b0, comparator_out_gt | comparator_out_eq};
      end
      LT_UNSIGNED, LT_SIGNED: begin
        ready = 1;
        out   = {31'b0, comparator_out_lt};
      end
      LTE_UNSIGNED, LTE_SIGNED: begin
        ready = 1;
        out   = {31'b0, comparator_out_lt | comparator_out_eq};
      end
      default: begin
        // If handling an unknown operation, let the output float but assert readiness so the CPU 
        // doesn't hang.
        out   = 'x;
        ready = 1;
      end
    endcase
  end

endmodule
