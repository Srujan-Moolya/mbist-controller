// mbist_controller.v
// Programmable MBIST controller (March C- and March SS).
//
// IMPORTANT DESIGN NOTE:
// The memory (memory_mut.v) has a REGISTERED read: data for
// addr presented at cycle N appears on dout at cycle N+1.
// So every "read" operation in a march element needs TWO
// controller cycles: PRESENT (drive addr) then COMPARE (check
// dout against expected, one cycle later). This controller
// implements that explicitly with a phase flag, so the
// comparator is actually correct instead of comparing garbage.
//
// March C- (6-element reduced form, standard industrial form):
//   M0: up   { w0 }
//   M1: up   { r0, w1 }
//   M2: up   { r1, w0 }
//   M3: down { r0, w1 }
//   M4: down { r1, w0 }
//   M5: up   { r0 }
//
// March SS (shorter, alg_sel = 1) - fewer elements, faster,
// lower fault coverage - used for the "compare algorithms"
// story in the project write-up:
//   S0: up { w0 }
//   S1: up { r0, w1 }
//   S2: up { r1 }
// ============================================================
module mbist_controller #(
    parameter ADDR_WIDTH = 5,
    parameter DATA_WIDTH = 8
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    start,
    input  wire                    alg_sel,      // 0 = March C-, 1 = March SS

    output reg                     we,
    output reg  [ADDR_WIDTH-1:0]   addr,
    output reg  [DATA_WIDTH-1:0]   din,
    input  wire [DATA_WIDTH-1:0]   dout,

    output reg                     done,
    output reg                     pass,
    output reg  [3:0]              fail_element,
    output reg  [ADDR_WIDTH-1:0]   fail_addr,
    output reg  [DATA_WIDTH-1:0]   fail_expected,
    output reg  [DATA_WIDTH-1:0]   fail_actual
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    localparam [DATA_WIDTH-1:0] PAT0 = {DATA_WIDTH{1'b0}};
    localparam [DATA_WIDTH-1:0] PAT1 = {DATA_WIDTH{1'b1}};

    localparam OP_NONE = 3'd0,
               OP_W0   = 3'd1,
               OP_W1   = 3'd2,
               OP_R0   = 3'd3,
               OP_R1   = 3'd4;

    // Element table: {opA, opB, direction(0=up,1=down)}
    reg [2:0] mc_opA [0:5];
    reg [2:0] mc_opB [0:5];
    reg       mc_dir [0:5];
    reg [2:0] ss_opA [0:2];
    reg [2:0] ss_opB [0:2];
    reg       ss_dir [0:2];

    initial begin
        mc_opA[0]=OP_W0; mc_opB[0]=OP_NONE; mc_dir[0]=1'b0; // M0: up {w0}
        mc_opA[1]=OP_R0; mc_opB[1]=OP_W1;   mc_dir[1]=1'b0; // M1: up {r0,w1}
        mc_opA[2]=OP_R1; mc_opB[2]=OP_W0;   mc_dir[2]=1'b0; // M2: up {r1,w0}
        mc_opA[3]=OP_R0; mc_opB[3]=OP_W1;   mc_dir[3]=1'b1; // M3: down {r0,w1}
        mc_opA[4]=OP_R1; mc_opB[4]=OP_W0;   mc_dir[4]=1'b1; // M4: down {r1,w0}
        mc_opA[5]=OP_R0; mc_opB[5]=OP_NONE; mc_dir[5]=1'b0; // M5: up {r0}

        ss_opA[0]=OP_W0; ss_opB[0]=OP_NONE; ss_dir[0]=1'b0; // S0: up {w0}
        ss_opA[1]=OP_R0; ss_opB[1]=OP_W1;   ss_dir[1]=1'b0; // S1: up {r0,w1}
        ss_opA[2]=OP_R1; ss_opB[2]=OP_NONE; ss_dir[2]=1'b0; // S2: up {r1}
    end

    localparam IDLE       = 3'd0,
               PRESENT_A   = 3'd1,
               COMPARE_A   = 3'd2,
               PRESENT_B   = 3'd3,
               COMPARE_B   = 3'd4,
               ADVANCE     = 3'd5,
               DONE_ST     = 3'd6;

    reg [2:0]  state;
    reg [3:0]  elem;
    reg [3:0]  num_elems;
    reg [ADDR_WIDTH-1:0] cnt;
    reg        dir;
    reg [2:0]  opA, opB;

    function automatic is_read(input [2:0] op);
        is_read = (op == OP_R0) || (op == OP_R1);
    endfunction

    function automatic [DATA_WIDTH-1:0] expected_of(input [2:0] op);
        expected_of = (op == OP_R1) ? PAT1 : PAT0;
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= IDLE;
            we            <= 1'b0;
            addr          <= 0;
            din           <= 0;
            cnt           <= 0;
            elem          <= 0;
            done          <= 1'b0;
            pass          <= 1'b1;
            fail_element  <= 0;
            fail_addr     <= 0;
            fail_expected <= 0;
            fail_actual   <= 0;
        end else begin
            we   <= 1'b0;
            done <= 1'b0;

            case (state)

                IDLE: begin
                    if (start) begin
                        pass      <= 1'b1;
                        elem      <= 0;
                        num_elems <= alg_sel ? 4'd3 : 4'd6;
                        dir       <= alg_sel ? ss_dir[0] : mc_dir[0];
                        opA       <= alg_sel ? ss_opA[0] : mc_opA[0];
                        opB       <= alg_sel ? ss_opB[0] : mc_opB[0];
                        cnt       <= (alg_sel ? ss_dir[0] : mc_dir[0]) ? DEPTH-1 : 0;
                        state     <= PRESENT_A;
                    end
                end

                PRESENT_A: begin
                    addr <= cnt;
                    if (opA == OP_W0 || opA == OP_W1) begin
                        we    <= 1'b1;
                        din   <= (opA == OP_W1) ? PAT1 : PAT0;
                        state <= PRESENT_B;
                    end else if (is_read(opA)) begin
                        state <= COMPARE_A;
                    end else begin
                        state <= PRESENT_B;
                    end
                end

                COMPARE_A: begin
                    if (dout !== expected_of(opA)) begin
                        pass          <= 1'b0;
                        fail_element  <= elem;
                        fail_addr     <= cnt;
                        fail_expected <= expected_of(opA);
                        fail_actual   <= dout;
                    end
                    state <= PRESENT_B;
                end

                PRESENT_B: begin
                    addr <= cnt;
                    if (opB == OP_W0 || opB == OP_W1) begin
                        we    <= 1'b1;
                        din   <= (opB == OP_W1) ? PAT1 : PAT0;
                        state <= ADVANCE;
                    end else if (is_read(opB)) begin
                        state <= COMPARE_B;
                    end else begin
                        state <= ADVANCE;
                    end
                end

                COMPARE_B: begin
                    if (dout !== expected_of(opB)) begin
                        pass          <= 1'b0;
                        fail_element  <= elem;
                        fail_addr     <= cnt;
                        fail_expected <= expected_of(opB);
                        fail_actual   <= dout;
                    end
                    state <= ADVANCE;
                end

                ADVANCE: begin
                    if ((dir == 1'b0 && cnt == DEPTH-1) ||
                        (dir == 1'b1 && cnt == 0)) begin
                        if (elem == num_elems - 1) begin
                            state <= DONE_ST;
                        end else begin
                            elem  <= elem + 1;
                            opA   <= alg_sel ? ss_opA[elem+1] : mc_opA[elem+1];
                            opB   <= alg_sel ? ss_opB[elem+1] : mc_opB[elem+1];
                            dir   <= alg_sel ? ss_dir[elem+1] : mc_dir[elem+1];
                            cnt   <= (alg_sel ? ss_dir[elem+1] : mc_dir[elem+1]) ? DEPTH-1 : 0;
                            state <= PRESENT_A;
           
