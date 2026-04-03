module adder (
    input logic [31:0] a,
    input logic [31:0] b,
    output logic [31:0] out,
    output logic carry
);

  always_comb begin
    out   = a + b;
    carry = a[31] & b[31];
  end

endmodule
