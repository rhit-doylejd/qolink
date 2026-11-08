`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/07/2026 07:05:53 PM
// Design Name: 
// Module Name: deframer
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


module deframer(
//Control Signals
input clk, reset,
output busy, 
output reg done, error, //error is new, from CRC check
output reg [1:0] packet_class, //Matched to framer
output reg [10:0] length,
output reg [63:0] timestamp,
output [7:0] payload,
output payload_valid,
input payload_ready,
input [7:0] receive_data,
input [1:0] receive_type,
    );
endmodule
