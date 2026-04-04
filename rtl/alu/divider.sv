module divider (
    input  logic        clk,
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic        is_signed,
    input  logic        enable,
    output logic [31:0] quotient,
    output logic [31:0] remainder,
    output logic        ready

    // NB: No reset required, because asserting 'enable' will initialise the module from any state.
);
  // --- Types and declarations -------------------------------------------------------------------
  typedef enum logic {
    WAITING = 1'b0,
    WORKING = 1'b1
  } state_t;

  state_t state;

  // When working, we go through 32 passes, which we track using the counter.
  logic [4:0] counter;

  // Defensively latch B to allow the input to change during operations.
  // We don't need to latch A as the algorithm immediately copies it into 'data'.
  logic [31:0] b_latch;

  // We'll do unsigned division and then adjust the signs at the end.
  // - a_sgn, b_sgn are for the inputs.
  // - quotient_sgn, remainder_sgn are used to adjust the outputs.
  logic a_sgn, b_sgn, quotient_sgn, remainder_sgn;

  // The algorithm acts on 64 contiguous bits. When it finishes they will hold 
  // the unsigned {remainder, quotient}.
  logic [63:0] data;

  // --- Output -----------------------------------------------------------------------------------
  // The algorithm works on unsigned values in data, which will hold {remainder, quotient} once
  // processing is complete. We adjust the signs at the end as needed.
  assign ready = (state == WAITING);
  assign remainder[31:0] = remainder_sgn ? -data[63:32] : data[63:32];
  assign quotient[31:0] = quotient_sgn ? -data[31:0] : data[31:0];

  // --- Combinatoric logic -----------------------------------------------------------------------
  // Operand signs
  assign a_sgn = is_signed & a[31];
  assign b_sgn = is_signed & b[31];

  // Convenience values for bit shifting logic
  logic [63:0] data_shifted;
  logic [31:0] rem_candidate;
  assign data_shifted  = data << 1;
  assign rem_candidate = data_shifted[63:32];

  // --- Sequential logic -----------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (enable) begin
      // To start the algorithm, the parent should set a, b and is_signed,
      // then bring 'enable' high for one clock cycle.
      if (b == 0) begin
        // Division by zero (special case): remainder is A, quotient is -1.
        // Abort immediately.
        state <= WAITING;
        quotient_sgn <= 0;
        remainder_sgn <= 0;
        data <= {a, 32'hffffffff};
      end else begin
        // Standard case - set up and enter WORKING state.
        state <= WORKING;
        counter <= 5'd31;
        data <= {32'b0, a_sgn ? -a : a};
        b_latch <= b_sgn ? -b : b;
        quotient_sgn <= a_sgn ^ b_sgn;
        remainder_sgn <= a_sgn;
      end
    end else if (state == WORKING) begin
      // The WORKING logic runs 32 cycles and then returns to WAITING state,
      // exposing the outputs and setting 'ready' high.      
      if (rem_candidate >= b_latch) begin
        // The shifted remainder is bigger than the divisor, so
        // we can subtract the divisor and store the new remainder.
        // When we do this we put a 1 in the lower quotient bit.
        data[63:32] <= (rem_candidate - b_latch);
        data[31:1] <= data_shifted[31:1];
        data[0] <= 1;
      end else begin
        // The shifted remainder is not yet bigger than the divisor,
        // so we keep it and put a 0 in the lower quotient bit.
        data <= data_shifted;
      end

      if (counter > 0) begin
        counter <= counter - 1;
      end else begin
        state <= WAITING;
      end
    end
  end
endmodule
