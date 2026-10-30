`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Rose-Hulman Institute of Technology QOLink Team
// Engineer: Joshua Doyle
//
// Create Date: 10/29/2026
// Design Name: QOLink register block testbench
// Module Name: qolink_regs_tb
// Project Name: QOLink
// Target Devices: simulation only
// Tool Versions: Vivado 2024.2 (xsim)
// Description: Self-checking testbench for qolink_regs. Acts as the NEORV32
//              XBUS master using single-access pipelined Wishbone transfers
//              (stb high for one cycle, cyc high until ack/err), as in the
//              NEORV32 v1.13.6 data sheet. Prints PASS or FAIL.
//
// Dependencies: hw/rtl/qolink_regs.v
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module qolink_regs_tb;

    //--------------------------------------------------------------------------
    // Clock and reset
    //--------------------------------------------------------------------------
    reg clk   = 1'b0;
    reg rst_n = 1'b0;

    always #5 clk = ~clk;   // 10 ns period = 100 MHz, same as the Nexys A7

    //--------------------------------------------------------------------------
    // Bus signals: driven by the testbench (acting as the NEORV32)
    //--------------------------------------------------------------------------
    reg  [31:0] adr  = 32'h0;
    reg  [31:0] wdat = 32'h0;
    reg         we   = 1'b0;
    reg  [3:0]  sel  = 4'h0;
    reg         stb  = 1'b0;
    reg         cyc  = 1'b0;

    // Bus signals: driven by the module
    wire [31:0] rdat;
    wire        ack;
    wire        err;

    //--------------------------------------------------------------------------
    // Design under test
    //--------------------------------------------------------------------------
    qolink_regs #(.BASE_ADDR(32'hF000_0000)) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .wb_adr_i (adr),
        .wb_dat_i (wdat),
        .wb_dat_o (rdat),
        .wb_we_i  (we),
        .wb_sel_i (sel),
        .wb_stb_i (stb),
        .wb_cyc_i (cyc),
        .wb_ack_o (ack),
        .wb_err_o (err)
    );

    //--------------------------------------------------------------------------
    // Results of the most recent transfer
    //--------------------------------------------------------------------------
    localparam [1:0] RESP_ACK     = 2'd0;
    localparam [1:0] RESP_ERR     = 2'd1;
    localparam [1:0] RESP_TIMEOUT = 2'd2;

    reg  [1:0]  resp;       // how the module answered
    reg  [31:0] rd;         // data it returned
    integer     failures = 0;

    //--------------------------------------------------------------------------
    // One XBUS transfer: stb for one cycle, cyc held until ack/err.
    // Gives up after 16 cycles (the real NEORV32 would bus-fault later).
    //--------------------------------------------------------------------------
    task bus_transfer(input [31:0] a, input w, input [31:0] d, input [3:0] s);
        integer cycles;
        begin
            @(posedge clk);
            adr <= a;  we <= w;  wdat <= d;  sel <= s;
            cyc <= 1'b1;
            stb <= 1'b1;

            @(posedge clk);                 // module sees the request on this edge
            stb <= 1'b0;

            cycles = 0;
            while (!ack && !err && cycles < 16) begin
                @(posedge clk);
                cycles = cycles + 1;
            end

            if      (ack) resp = RESP_ACK;
            else if (err) resp = RESP_ERR;
            else          resp = RESP_TIMEOUT;
            rd = rdat;

            cyc <= 1'b0;
            we  <= 1'b0;
            sel <= 4'h0;
        end
    endtask

    //--------------------------------------------------------------------------
    // Checking helpers
    //--------------------------------------------------------------------------
    task check_write(input [31:0] a, input [31:0] d, input [3:0] s);
        begin
            bus_transfer(a, 1'b1, d, s);
            if (resp != RESP_ACK) begin
                $display("  write %h <= %h  FAIL (response %0d)", a, d, resp);
                failures = failures + 1;
            end
        end
    endtask

    task check_read(input [31:0] a, input [31:0] expected);
        begin
            bus_transfer(a, 1'b0, 32'h0, 4'hF);
            if (resp == RESP_ACK && rd == expected)
                $display("  read  %h = %h  OK", a, rd);
            else begin
                $display("  read  %h = %h  FAIL (expected %h, response %0d)",
                         a, rd, expected, resp);
                failures = failures + 1;
            end
        end
    endtask

    task check_pattern(input [31:0] d);
        begin
            check_write(32'hF000_0000, d, 4'b1111);
            check_read (32'hF000_0000, d);
        end
    endtask

    task check_response(input [31:0] a, input w, input [1:0] expected);
        begin
            bus_transfer(a, w, 32'hDEAD_BEEF, 4'b1111);
            if (resp == expected)
                $display("  %s %h -> response %0d  OK", w ? "write" : "read ", a, resp);
            else begin
                $display("  %s %h -> response %0d  FAIL (expected %0d)",
                         w ? "write" : "read ", a, resp, expected);
                failures = failures + 1;
            end
        end
    endtask

    //--------------------------------------------------------------------------
    // Test sequence
    //--------------------------------------------------------------------------
    initial begin
        $display("qolink_regs testbench");

        repeat (4) @(posedge clk);          // hold reset for 4 cycles
        rst_n <= 1'b1;

        $display("Test 1: reset value");
        check_read(32'hF000_0000, 32'h0000_0000);

        $display("Test 2: full-word patterns");
        check_pattern(32'hA5A5_A5A5);
        check_pattern(32'h5A5A_5A5A);
        check_pattern(32'h0000_0000);
        check_pattern(32'hFFFF_FFFF);
        check_pattern(32'h1234_5678);
        check_pattern(32'hDEAD_BEEF);

        $display("Test 3: byte enables (write byte 2 only)");
        check_write(32'hF000_0000, 32'hFFFF_FFFF, 4'b1111);
        check_write(32'hF000_0000, 32'h3C3C_3C3C, 4'b0100);
        check_read (32'hF000_0000, 32'hFF3C_FFFF);

        $display("Test 4: unmapped offset answers with err");
        check_response(32'hF000_0004, 1'b0, RESP_ERR);
        check_response(32'hF000_0004, 1'b1, RESP_ERR);
        check_read    (32'hF000_0000, 32'hFF3C_FFFF);   // bad write changed nothing

        $display("Test 5: address outside the window gets no answer");
        check_response(32'h1000_0000, 1'b0, RESP_TIMEOUT);

        if (failures == 0)
            $display("PASS");
        else
            $display("FAIL: %0d check(s) failed", failures);

        $finish;
    end

endmodule