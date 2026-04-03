module registers (
    input logic clk,

    // We have two read ports, to speed up reading the operands
    // for a binary operation. Otherwise, this would take two
    // separate fetch cycles. 
    input  logic [ 4:0] rd_addr_a,
    output logic [31:0] rd_data_a,
    input  logic [ 4:0] rd_addr_b,
    output logic [31:0] rd_data_b,

    // We additionally have a dedicated write port, which is
    // clocked.
    input logic        wr_en,
    input logic [ 4:0] wr_addr,
    input logic [31:0] wr_data
);

  // In RISC-V, there are 32 "X" registers, but X0 is unwriteable
  // and always returns 0.
  logic [31:0] x[1:31];

  always_comb begin
    rd_data_a = (rd_addr_a == 5'd0) ? 32'd0 : x[rd_addr_a];
    rd_data_b = (rd_addr_b == 5'd0) ? 32'd0 : x[rd_addr_b];
  end

  always_ff @(posedge clk) begin
    if (wr_en && wr_addr != 5'd0) begin
      x[wr_addr] <= wr_data;
    end
  end

endmodule
