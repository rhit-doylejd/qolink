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

    //--------------------------------------------------------------------------
    // Register addresses (must match qolink_regs.v and qolink-registers.ads)
    //--------------------------------------------------------------------------
    localparam [31:0] SCRATCH        = 32'hF000_0000;
    localparam [31:0] TX_FIFO_DATA   = 32'hF000_0004;
    localparam [31:0] TX_FIFO_STATUS = 32'hF000_0008;
    localparam [31:0] RX_FIFO_DATA   = 32'hF000_000C;
    localparam [31:0] RX_FIFO_STATUS = 32'hF000_0010;
    localparam [31:0] LOOPBACK_CTRL  = 32'hF000_0014;

    // FIFO status values: bit 0 = empty, bit 1 = full
    localparam [31:0] ST_EMPTY = 32'h1;
    localparam [31:0] ST_DATA  = 32'h0;   // neither empty nor full
    localparam [31:0] ST_FULL  = 32'h2;

    reg  [1:0]  resp;       // how the module answered
    reg  [31:0] rd;         // data it returned
    integer     failures = 0;
    integer     i;

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
            check_write(SCRATCH, d, 4'b1111);
            check_read (SCRATCH, d);
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
    // Loopback helpers: same register accesses the Ada driver will make
    //--------------------------------------------------------------------------
    task start_loopback(input [7:0] n);      // move n bytes TX -> RX (0 = cancel)
        begin
            check_write(LOOPBACK_CTRL, {24'h0, n}, 4'b0001);
        end
    endtask

    task wait_loopback_idle;                 // poll busy (bit 8), give up after 100 reads
        integer polls;
        begin
            polls = 0;
            rd    = 32'h100;
            while (rd[8] && polls < 100) begin
                bus_transfer(LOOPBACK_CTRL, 1'b0, 32'h0, 4'hF);
                polls = polls + 1;
            end
            if (rd[8]) begin
                $display("  loopback still busy after %0d polls  FAIL (remaining %0d)",
                         polls, rd[7:0]);
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
        check_read(SCRATCH, 32'h0000_0000);

        $display("Test 2: full-word patterns");
        check_pattern(32'hA5A5_A5A5);
        check_pattern(32'h5A5A_5A5A);
        check_pattern(32'h0000_0000);
        check_pattern(32'hFFFF_FFFF);
        check_pattern(32'h1234_5678);
        check_pattern(32'hDEAD_BEEF);

        $display("Test 3: byte enables (write byte 2 only)");
        check_write(SCRATCH, 32'hFFFF_FFFF, 4'b1111);
        check_write(SCRATCH, 32'h3C3C_3C3C, 4'b0100);
        check_read (SCRATCH, 32'hFF3C_FFFF);

        $display("Test 4: TX FIFO push, status, and errors");
        check_read    (TX_FIFO_STATUS, ST_EMPTY);             // empty after reset
        check_response(TX_FIFO_DATA, 1'b0, RESP_ERR);         // TX_FIFO_DATA is write-only
        check_response(TX_FIFO_STATUS, 1'b1, RESP_ERR);       // TX_FIFO_STATUS is read-only
        bus_transfer  (TX_FIFO_DATA, 1'b1, 32'hFF, 4'b0010);  // byte 0 not selected
        if (resp != RESP_ERR) begin
            $display("  write without byte 0  FAIL (response %0d)", resp);
            failures = failures + 1;
        end
        check_read    (TX_FIFO_STATUS, ST_EMPTY);             // ...and nothing was pushed
        check_write   (TX_FIFO_DATA, 32'hA0, 4'b0001);
        check_read    (TX_FIFO_STATUS, ST_DATA);              // one byte: not empty, not full
        for (i = 1; i < 16; i = i + 1)
            check_write(TX_FIFO_DATA, 32'hA0 + i, 4'b0001);  // A1..AF: 16 bytes total
        check_read    (TX_FIFO_STATUS, ST_FULL);
        check_response(TX_FIFO_DATA, 1'b1, RESP_ERR);         // 17th write rejected

        $display("Test 5: loopback moves all 16 bytes, in order");
        check_read    (RX_FIFO_STATUS, ST_EMPTY);
        check_response(RX_FIFO_DATA, 1'b0, RESP_ERR);         // reading empty RX is an error
        check_response(RX_FIFO_DATA, 1'b1, RESP_ERR);         // RX_FIFO_DATA is read-only
        start_loopback(16);
        wait_loopback_idle;
        check_read    (LOOPBACK_CTRL,  32'h000);              // idle, 0 remaining
        check_read    (TX_FIFO_STATUS, ST_EMPTY);
        check_read    (RX_FIFO_STATUS, ST_FULL);
        for (i = 0; i < 16; i = i + 1)
            check_read(RX_FIFO_DATA, 32'hA0 + i);             // A0..AF, first in first out
        check_read    (RX_FIFO_STATUS, ST_EMPTY);
        check_response(RX_FIFO_DATA, 1'b0, RESP_ERR);

        $display("Test 6: loopback moves exactly the requested count");
        for (i = 0; i < 5; i = i + 1)
            check_write(TX_FIFO_DATA, 32'hB0 + i, 4'b0001);  // B0..B4
        start_loopback(3);
        wait_loopback_idle;
        check_read    (RX_FIFO_DATA, 32'hB0);
        check_read    (RX_FIFO_DATA, 32'hB1);
        check_read    (RX_FIFO_DATA, 32'hB2);
        check_read    (RX_FIFO_STATUS, ST_EMPTY);             // exactly 3 moved
        check_read    (TX_FIFO_STATUS, ST_DATA);              // B3, B4 still in TX

        $display("Test 7: loopback pauses when TX runs dry, resumes on new data");
        start_loopback(4);                                    // only B3, B4 available
        repeat (20) @(posedge clk);
        check_read    (LOOPBACK_CTRL, 32'h102);               // busy, 2 remaining
        check_write   (TX_FIFO_DATA, 32'hC0, 4'b0001);
        check_write   (TX_FIFO_DATA, 32'hC1, 4'b0001);
        wait_loopback_idle;
        check_read    (RX_FIFO_DATA, 32'hB3);
        check_read    (RX_FIFO_DATA, 32'hB4);
        check_read    (RX_FIFO_DATA, 32'hC0);
        check_read    (RX_FIFO_DATA, 32'hC1);
        check_read    (RX_FIFO_STATUS, ST_EMPTY);

        $display("Test 8: loopback pauses when RX is full; cancel stops it");
        for (i = 0; i < 16; i = i + 1)
            check_write(TX_FIFO_DATA, 32'hD0 + i, 4'b0001);  // D0..DF
        start_loopback(16);
        wait_loopback_idle;
        check_read    (RX_FIFO_STATUS, ST_FULL);
        check_write   (TX_FIFO_DATA, 32'hE0, 4'b0001);
        start_loopback(1);                                    // RX full: must stall
        repeat (20) @(posedge clk);
        check_read    (LOOPBACK_CTRL, 32'h101);               // busy, nothing popped
        check_read    (TX_FIFO_STATUS, ST_DATA);              // E0 still in TX
        start_loopback(0);                                    // cancel
        check_read    (LOOPBACK_CTRL, 32'h000);
        for (i = 0; i < 16; i = i + 1)
            check_read(RX_FIFO_DATA, 32'hD0 + i);             // D0..DF, nothing lost
        repeat (20) @(posedge clk);                           // RX has room now...
        check_read    (RX_FIFO_STATUS, ST_EMPTY);             // ...but cancelled: E0 not moved
        check_read    (TX_FIFO_STATUS, ST_DATA);


        $display("Test 9: unmapped offset answers with err");
        check_response(32'hF000_0100, 1'b0, RESP_ERR);
        check_response(32'hF000_0100, 1'b1, RESP_ERR);  
        check_read    (SCRATCH, 32'hFF3C_FFFF);   // bad write changed nothing

        $display("Test 10: address outside the window gets no answer");
        check_response(32'h1000_0000, 1'b0, RESP_TIMEOUT);

        if (failures == 0)
            $display("PASS");
        else
            $display("FAIL: %0d check(s) failed", failures);

        $finish;
    end

endmodule