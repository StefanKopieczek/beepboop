module multiplier (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic        a_is_signed,
    input  logic        b_is_signed,
    output logic [31:0] out_upper,
    output logic [31:0] out_lower
);

  logic [63:0] a_ext;
  logic [63:0] b_ext;

  assign a_ext = a_is_signed ? {{32{a[31]}}, a} : {32'b0, a};
  assign b_ext = b_is_signed ? {{32{b[31]}}, b} : {32'b0, b};

  logic [63:0] out;
  assign out = a_ext * b_ext;

  assign out_upper = out[63:32];
  assign out_lower = out[31:0];

endmodule
