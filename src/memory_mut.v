// memory_mut.v
// Simple synchronous SRAM model - Memory Under Test (MUT)
// 32 words x 8 bits (small so simulation runs fast)
// ============================================================
module memory_mut #(
    parameter ADDR_WIDTH = 5,          // 2^5 = 32 words
    parameter DATA_WIDTH = 8
)(
    input  wire                    clk,
    input  wire                    we,      // write enable
    input  wire [ADDR_WIDTH-1:0]   addr,
    input  wire [DATA_WIDTH-1:0]   din,
    output reg  [DATA_WIDTH-1:0]   dout
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Synchronous write, synchronous read (typical SRAM behavior)
    always @(posedge clk) begin
        if (we)
            mem[addr] <= din;
        dout <= mem[addr];   // read is registered, same as real SRAM
    end
  always @(*) begin
    dout = mem[addr];
  end

endmodule
