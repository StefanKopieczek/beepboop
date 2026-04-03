module divider (
    input  logic        clk,
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic        is_signed,
    input  logic        enable,
    output logic [31:0] quotient,
    output logic [31:0] remainder,
    output logic        ready
);


  enum {
    WAITING,
    WORKING
  } state;

  // When working, we go through 32 passes, which
  // we track using the counter.
  logic [4:0] counter;

  // Defensive guard against B changing during operation:
  // take a copy when the algorithm starts.
  // We don't need to latch A because it's immediately copied
  // into 'data' and then the original input isn't used. 
  logic [31:0] b_latch;

  // We'll do the algorithm as unsigned division and then adjust the signs at the end.
  logic a_sgn, b_sgn, quotient_sgn, remainder_sgn;

  // The algorithm acts on 64 contiguous bits, and when
  // it finishes they will hold {remainder, quotient}.
  // If doing signed calculation we need to adjust the sign bits.
  logic [63:0] data;
  assign remainder[31:0] = remainder_sgn ? -data[63:32] : data[63:32];
  assign quotient[31:0] = quotient_sgn ? -data[31:0] : data[31:0];

  assign ready = (state == WAITING);

  // Combinatorial logic for initialisation.
  always_comb begin
    a_sgn = is_signed & a[31];
    b_sgn = is_signed & b[31];
  end

  // Combinatorial logic for working algorithm.
  logic [63:0] shifted;
  logic [31:0] shifted_rem;
  always_comb begin
    shifted = data << 1;
    shifted_rem = shifted[63:32];
  end

  always_ff @(posedge clk) begin
    if (enable) begin
      // To start the algorithm, the parent should set a, b and is_signed,
      // then bring 'enable' high for one clock cycle.
      state <= WORKING;
      counter <= 5'd31;
      data <= {32'b0, a_sgn ? -a : a};
      b_latch <= b_sgn ? -b : b;
      quotient_sgn <= a_sgn ^ b_sgn;
      remainder_sgn <= a_sgn;
    end else if (state == WORKING) begin
      // The WORKING logic runs 32 cycles and then returns to WAITING state,
      // exposing the outputs and setting 'ready' high.      
      if (shifted_rem >= b_latch) begin
        // The shifted remainder is bigger than the divisor, so
        // we can subtract the divisor and store the new remainder.
        // When we do this we put a 1 in the lower quotient bit.
        data[63:32] <= (shifted_rem - b_latch);
        data[31:1] <= shifted[31:1];
        data[0] <= 1;
      end else begin
        // The shifted remainder is not yet bigger than the divisor,
        // so we keep it and put a 0 in the lower quotient bit.
        data <= shifted;
      end

      if (counter > 0) begin
        counter <= counter - 1;
      end else begin
        state <= WAITING;
      end
    end
  end
endmodule
