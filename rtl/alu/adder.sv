module adder (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] out
);

  always_comb begin
    // Note that this is valid irrespective of the sign of the operands.
    // Hooray for two's complement arithmetic!
    out = a + b;
  end

endmodule
