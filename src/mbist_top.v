// ============================================================
// mbist_top.v
// Wires the MBIST controller to a Memory Under Test.
// USE_FAULTY / fault parameters let you swap in memory_faulty.v
// at instantiation time, so the SAME controller RTL is tested
// against both a golden memory and several broken memories.
// ============================================================
module mbist_top #(
    parameter ADDR_WIDTH  = 5,
    parameter DATA_WIDTH  = 8,
    parameter USE_FAULTY  = 0,   // 0 = golden memory, 1 = faulty memory
    parameter FAULT_MODE  = 0,
    parameter [ADDR_WIDTH-1:0] FAULT_ADDR = 0,
    parameter [ADDR_WIDTH-1:0] COUPLE_SRC = 0,
    parameter [ADDR_WIDTH-1:0] COUPLE_DST = 1,
    parameter FAULT_BIT   = 0,
    parameter FAULT_VAL   = 1
)(
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    input  wire alg_sel,
    output wire done,
    output wire pass,
    output wire [3:0] fail_element,
    output wire [ADDR_WIDTH-1:0] fail_addr,
    output wire [DATA_WIDTH-1:0] fail_expected,
    output wire [DATA_WIDTH-1:0] fail_actual
);

    wire we;
    wire [ADDR_WIDTH-1:0] addr;
    wire [DATA_WIDTH-1:0] din;
    wire [DATA_WIDTH-1:0] dout;

    mbist_controller #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)
    ) u_ctrl (
        .clk(clk), .rst_n(rst_n), .start(start), .alg_sel(alg_sel),
        .we(we), .addr(addr), .din(din), .dout(dout),
        .done(done), .pass(pass),
        .fail_element(fail_element), .fail_addr(fail_addr),
        .fail_expected(fail_expected), .fail_actual(fail_actual)
    );

    generate
        if (USE_FAULTY) begin : gen_faulty
            memory_faulty #(
                .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH),
                .FAULT_MODE(FAULT_MODE), .FAULT_ADDR(FAULT_ADDR),
                .COUPLE_SRC(COUPLE_SRC), .COUPLE_DST(COUPLE_DST),
                .FAULT_BIT(FAULT_BIT), .FAULT_VAL(FAULT_VAL)
            ) u_mem (
                .clk(clk), .we(we), .addr(addr), .din(din), .dout(dout)
            );
        end else begin : gen_golden
            memory_mut #(
                .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)
            ) u_mem (
                .clk(clk), .we(we), .addr(addr), .din(din), .dout(dout)
            );
        end
    endgenerate

endmodule
