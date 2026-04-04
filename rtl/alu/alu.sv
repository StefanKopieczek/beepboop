import alu_types::*;

module alu (
    input  logic    [31:0] a,
    input  logic    [31:0] b,
    input  alu_op_t        op,
    input  logic           enable,
    output logic    [31:0] out,
    output logic           ready
);
endmodule
