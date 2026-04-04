module comparator (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic        is_signed,
    output logic        less_than,
    output logic        greater_than,
    output logic        equal
);

  always_comb begin
    equal = a == b;

    case (is_signed)
      0: begin
        less_than = a < b;
        greater_than = a > b;
      end
      1: begin
        less_than = signed'(a) < signed'(b);
        greater_than = signed'(a) > signed'(b);
      end
    endcase
  end

endmodule
