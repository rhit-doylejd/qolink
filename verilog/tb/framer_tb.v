`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/03/2026 02:07:21 PM
// Design Name: 
// Module Name: framer_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module framer_tb; //reg/wires taken from framer module
reg clk, reset, start;
wire busy;
reg done;
reg [1:0] packet_class;
reg [10:0] length;
reg [63:0] timestamp;
reg [7:0] payload;
wire payload_ready;
reg [7:0] transmit_data;
reg [1:0] transmit_type;
wire transmit_valid;
reg transmit_ready;
//assigning by name just to avoid confusion
framer dut(.clk(clk), .reset(reset), .start(start), .busy(busy), .done(done),
    .packet_class(packet_class), .length(length), .timestamp(timestamp), .payload(payload),
    .payload_ready(payload_ready), .transmit_data(transmit_data), .transmit_type(transmit_type), 
    .transmit_valid(transmit_valid), .transmit_ready(transmit_ready));












always #5 clk = ~clk;
endmodule
