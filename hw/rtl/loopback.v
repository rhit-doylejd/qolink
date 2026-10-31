`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Rose-Hulman Institute of Technology QOLink Team
// Engineer: Eric Steuber
//
// Create Date: 10/31/2026
// Design Name: QOLink loopback path
// Module Name: loopback
// Project Name: QOLink
// Target Devices: Nexys A7-100T (XC7A100T)
// Tool Versions: Vivado 2024.2
// Description: Moves an exact number of bytes from the TX FIFO to the RX FIFO.
//              Stand-in for the real link, used to test the register block and
//              the Ada driver end to end.
//
//              Usage:
//                - Pulse `start` for one clock with the byte count on `count`.
//                - `busy` stays high until all bytes have landed in RX.
//                - `remaining` = bytes not yet popped from TX.
//                - If TX runs empty or RX fills up, the transfer pauses and
//                  resumes on its own when there is data / room again.
//                - A new `start` replaces the remaining count. count = 0 cancels.
//                  A byte already popped from TX still lands in RX.
//
//              Timing: fifo.v registers its output, so a popped byte appears on
//              data_in one clock after `read`; `write` is delayed one clock to
//              catch it. A new pop waits until the previous push has landed so
//              the FIFO flags are current. One byte moves every 3 clocks:
//
//                cycle    n      n+1     n+2
//                read     1      0       0     (pop TX at end of n)
//                write    0      1       0     (push RX at end of n+1)
//                flags    -      -       valid (next pop may start at n+3)
//
// Dependencies: none (connects between two fifo.v instances)
//
// Revision:
// Revision 0.01 - File Created
// Revision 0.02 - Transfer an exact byte count instead of a level-sensitive enable
//////////////////////////////////////////////////////////////////////////////////

module loopback (
    input  wire       clk,
    input  wire       rst_n,      // active-low async reset, same as qolink_regs

    // Control
    input  wire       start,      // one-clock pulse: load `count` and begin
    input  wire [7:0] count,      // number of bytes to move (0 = cancel)
    output wire       busy,       // high until every requested byte is in RX
    output wire [7:0] remaining,  // bytes not yet popped from TX

    // TX FIFO side
    input  wire       tx_empty,   // from TX FIFO empty
    input  wire [7:0] data_in,    // from TX FIFO out
    output reg        read,       // pop pulse to TX FIFO

    // RX FIFO side
    input  wire       rx_full,    // from RX FIFO full
    output wire [7:0] data_out,   // to RX FIFO in
    output reg        write       // push pulse to RX FIFO
);

    reg [7:0] remaining_r;

    // data_in is a register output in fifo.v, so it is stable for the whole
    // cycle in which write is high.
    assign data_out  = data_in;
    assign remaining = remaining_r;

    // Busy while bytes are still owed, or a byte is still in flight.
    assign busy = (remaining_r != 8'd0) || read || write;

    // Pop one byte only when:
    //   - bytes are still owed
    //   - TX has a byte and RX has room
    //   - no byte is in flight, so the FIFO flags are current
    wire pop = (remaining_r != 8'd0) && !tx_empty && !rx_full && !read && !write;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            remaining_r <= 8'd0;
            read        <= 1'b0;
            write       <= 1'b0;
        end else begin
            // A start takes priority: load the new count, no pop this cycle.
            read  <= pop && !start;
            write <= read;              // push RX one clock after the pop

            if (start)
                remaining_r <= count;
            else if (pop)
                remaining_r <= remaining_r - 8'd1;
        end
    end

endmodule