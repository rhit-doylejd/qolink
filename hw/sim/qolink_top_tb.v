`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Rose-Hulman Institute of Technology QOLink Team
// Engineer: Joshua Doyle
//
// Create Date: 10/30/2026
// Design Name: QOLink system testbench
// Module Name: qolink_top_tb
// Project Name: QOLink
// Target Devices: simulation only
// Tool Versions: Vivado 2024.2 (xsim)
// Description: Runs the full design (NEORV32 + Ada program in IMEM +
//              qolink_regs). Provides clock, reset and an idle UART input,
//              and prints every XBUS transfer. The Ada program prints its
//              own results through UART0 simulation mode.
//              Requires the Ada program built with Simulation_Build = True.
//
// Dependencies: qolink_top.v and everything below it
//
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////

module qolink_top_tb;

    reg  clk        = 1'b0;
    reg  cpu_resetn = 1'b0;     // button "pressed" at start
    wire uart_txd;
    wire led_heartbeat;

    always #5 clk = ~clk;       // 100 MHz

    qolink_top dut (
        .clk           (clk),
        .cpu_resetn    (cpu_resetn),
        .uart_rxd      (1'b1),  // UART line idles high
        .uart_txd      (uart_txd),
        .led_heartbeat (led_heartbeat)
    );

    // Print every XBUS request and every response.
    always @(posedge clk) begin
        if (dut.xbus_cyc && dut.xbus_stb)
            $display("%10t  XBUS %s addr %h  wdata %h  sel %b",
                     $time, dut.xbus_we ? "write" : "read ",
                     dut.xbus_adr, dut.xbus_wdat, dut.xbus_sel);
        if (dut.xbus_ack)
            $display("%10t  XBUS ack            rdata %h", $time, dut.xbus_rdat);
        if (dut.xbus_err)
            $display("%10t  XBUS ERR", $time);
    end

    initial begin
        #100;                   // hold reset for 100 ns
        cpu_resetn = 1'b1;      // release the button
        #2_000_000;             // run 2 ms, far longer than the test needs
        $display("Simulation finished");
        $finish;
    end

endmodule