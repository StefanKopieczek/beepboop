// Usage:
// Two channels:
// - Use *_ronly for reads (e.g. PC)
// - Use *_rw for reads and writes
//
// On write, write_enable sets which bytes are actually written (e.g. 1101 excludes byte 3).
//
// Timings: 
// - Set up for write; write applied on next posedge.
// - Set up for read; on next posedge can read the previously written value
//
// Supposedly this should synthesise to BRAM.
module ram #(
    parameter MAX_ADDRESS = 2 ** 14 - 1,
    parameter MEM_INIT = ""
) (
    input logic clk,

    // Port A — read-only (e.g. instruction fetch)
    input  logic [31:0] addr_ronly,
    output logic [31:0] dout_ronly,

    // Port B — read/write with byte enables (e.g. data load/store)
    input  logic [ 3:0] write_enable,
    input  logic [31:0] addr_rw,
    input  logic [31:0] din,
    output logic [31:0] dout_rw
);

  logic [31:0] mem[0:MAX_ADDRESS];

  // Read port: synchronous read
  always_ff @(posedge clk) begin
    dout_ronly <= mem[addr_ronly];
  end

  // RW port: byte-granular write, synchronous read (write-first)
  always_ff @(posedge clk) begin
    for (int i = 0; i < 4; i++) begin
      if (write_enable[i]) mem[addr_rw][i*8+:8] <= din[i*8+:8];
    end
    dout_rw <= mem[addr_rw];
  end

  // Optional memory initialization
  generate
    if (MEM_INIT != "") begin : gen_mem_init
      initial begin
        $readmemh(MEM_INIT, mem);
      end
    end
  endgenerate

endmodule
