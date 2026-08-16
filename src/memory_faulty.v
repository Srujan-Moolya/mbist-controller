// memory_faulty.v
// ============================================================
// memory_faulty.v (CORRECTED)
// Memory wrapper with INJECTABLE faults, controlled by parameters.
// ============================================================
module memory_faulty #(
    parameter ADDR_WIDTH = 5,
    parameter DATA_WIDTH = 8,
    parameter FAULT_MODE = 0,
    parameter [ADDR_WIDTH-1:0] FAULT_ADDR  = 0,
    parameter [ADDR_WIDTH-1:0] COUPLE_SRC  = 0,
    parameter [ADDR_WIDTH-1:0] COUPLE_DST  = 1,
    parameter FAULT_BIT  = 0,
    parameter FAULT_VAL  = 1
)(
    input  wire                    clk,
    input  wire                    we,
    input  wire [ADDR_WIDTH-1:0]   addr,
    input  wire [DATA_WIDTH-1:0]   din,
    output reg  [DATA_WIDTH-1:0]   dout
);

    localparam DEPTH = 1 << ADDR_WIDTH;
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = {DATA_WIDTH{1'b0}};
    end

    // Synchronous write
    always @(posedge clk) begin
        if (we) begin
            // normal write
            mem[addr] <= din;

            // FAULT_MODE 2: coupling fault
            if (FAULT_MODE == 2 && addr == COUPLE_SRC) begin
                mem[COUPLE_DST] <= mem[COUPLE_DST] ^ (1'b1 << FAULT_BIT);
            end

            // FAULT_MODE 3: transition fault (0->1 stuck)
            if (FAULT_MODE == 3 && addr == FAULT_ADDR && din[FAULT_BIT] == 1'b1) begin
                mem[addr] <= din & ~(1'b1 << FAULT_BIT); 
            end
        end
    end

    // Combinational read (Fixes the 1-cycle latency bug)
    always @(*) begin
        if (FAULT_MODE == 1 && addr == FAULT_ADDR) begin
            // stuck-at fault read behavior
            dout = (mem[addr] & ~(1'b1 << FAULT_BIT)) | (FAULT_VAL << FAULT_BIT);
        end else begin
            dout = mem[addr];
        end
    end

endmodule
