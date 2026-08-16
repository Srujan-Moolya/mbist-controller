// tb_mbist.v (CORRECTED)
// Instantiates FIVE copies of mbist_top, each wired to a
// different memory scenario.
// ============================================================
`timescale 1ns/1ps

module tb_mbist;

    parameter ADDR_WIDTH = 5;
    parameter DATA_WIDTH = 8;

    reg clk = 0;
    reg rst_n = 0;
    reg start = 0;

    wire done0, pass0, done1, pass1, done2, pass2, done3, pass3, done4, pass4;
    wire [3:0] fe1, fe2, fe3;
    wire [ADDR_WIDTH-1:0] fa1, fa2, fa3;
    wire [DATA_WIDTH-1:0] fexp1, fexp2, fexp3, fact1, fact2, fact3;

    always #5 clk = ~clk;

    // ---- DUT0: golden memory, March C- ----
    mbist_top #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .USE_FAULTY(0))
    dut0 (.clk(clk), .rst_n(rst_n), .start(start), .alg_sel(1'b0),
          .done(done0), .pass(pass0),
          .fail_element(), .fail_addr(), .fail_expected(), .fail_actual());

    // ---- DUT1: stuck-at fault @ addr 10, bit 3 stuck at 1 ----
    mbist_top #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH),
                .USE_FAULTY(1), .FAULT_MODE(1),
                .FAULT_ADDR(10), .FAULT_BIT(3), .FAULT_VAL(1))
    dut1 (.clk(clk), .rst_n(rst_n), .start(start), .alg_sel(1'b0),
          .done(done1), .pass(pass1),
          .fail_element(fe1), .fail_addr(fa1),
          .fail_expected(fexp1), .fail_actual(fact1));

    // ---- DUT2: coupling fault, write to addr 4 flips bit 2 of addr 15 ----
    mbist_top #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH),
                .USE_FAULTY(1), .FAULT_MODE(2),
                .COUPLE_SRC(4), .COUPLE_DST(15), .FAULT_BIT(2))
    dut2 (.clk(clk), .rst_n(rst_n), .start(start), .alg_sel(1'b0),
          .done(done2), .pass(pass2),
          .fail_element(fe2), .fail_addr(fa2),
          .fail_expected(fexp2), .fail_actual(fact2));

    // ---- DUT3: transition fault @ addr 20, bit 5 can't go 0->1 ----
    mbist_top #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH),
                .USE_FAULTY(1), .FAULT_MODE(3),
                .FAULT_ADDR(20), .FAULT_BIT(5))
    dut3 (.clk(clk), .rst_n(rst_n), .start(start), .alg_sel(1'b0),
          .done(done3), .pass(pass3),
          .fail_element(fe3), .fail_addr(fa3),
          .fail_expected(fexp3), .fail_actual(fact3));

    // ---- DUT4: golden memory, March SS (shorter algorithm) ----
    mbist_top #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .USE_FAULTY(0))
    dut4 (.clk(clk), .rst_n(rst_n), .start(start), .alg_sel(1'b1),
          .done(done4), .pass(pass4),
          .fail_element(), .fail_addr(), .fail_expected(), .fail_actual());

    // ---- LATCH THE DONE SIGNALS HERE ----
    // This catches the 1-cycle pulses so they don't get missed
    reg d0=0, d1=0, d2=0, d3=0, d4=0;
    always @(posedge clk) begin
        if (done0) d0 <= 1'b1;
        if (done1) d1 <= 1'b1;
        if (done2) d2 <= 1'b1;
        if (done3) d3 <= 1'b1;
        if (done4) d4 <= 1'b1;
    end

    integer cyc;

    initial begin
        $display("=====================================================");
        $display(" MBIST Verification Suite - DFT project");
        $display("=====================================================");

        rst_n = 0;
        repeat (3) @(negedge clk);
        rst_n = 1;
      @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        // wait until ALL five finish using the latched signals
        cyc = 0;
        while (!(d0 && d1 && d2 && d3 && d4)) begin
            @(negedge clk);
            cyc = cyc + 1;
            if (cyc > 5000) begin
                $display("ERROR: simulation timeout - a DUT never asserted done");
                $finish;
            end
        end
        @(negedge clk); // let pass/fail settle one more cycle

        $display("");
        $display("---------------------- RESULTS ---------------------");
        $display("DUT0 golden memory   / March C- : %s (expected PASS)",
                   pass0 ? "PASS" : "FAIL");

        $display("DUT1 stuck-at fault  / March C- : %s (expected FAIL)%s",
                   pass1 ? "PASS" : "FAIL",
                   pass1 ? "" : $sformatf(" -> element %0d, addr %0d, exp=%0d got=%0d",
                                            fe1, fa1, fexp1, fact1));

        $display("DUT2 coupling fault  / March C- : %s (expected FAIL)%s",
                   pass2 ? "PASS" : "FAIL",
                   pass2 ? "" : $sformatf(" -> element %0d, addr %0d, exp=%0d got=%0d",
                                            fe2, fa2, fexp2, fact2));

        $display("DUT3 transition flt  / March C- : %s (expected FAIL)%s",
                   pass3 ? "PASS" : "FAIL",
                   pass3 ? "" : $sformatf(" -> element %0d, addr %0d, exp=%0d got=%0d",
                                            fe3, fa3, fexp3, fact3));

        $display("DUT4 golden memory   / March SS : %s (expected PASS)",
                   pass4 ? "PASS" : "FAIL");

        $display("------------------------------------------------------");
        if (pass0 && !pass1 && !pass2 && !pass3 && pass4)
            $display("SUMMARY: All fault classes correctly DETECTED. Controller verified.");
        else
            $display("SUMMARY: Unexpected result - check fault injection wiring.");
        $display("------------------------------------------------------");

        $finish;
    end

endmodule
