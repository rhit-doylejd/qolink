`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Rose-Hulman Institute of Technology QOLink Team
// Engineer: Mateo Olson
// 
// Create Date: 10/06/2026 11:49:22 AM
// Design Name: Simple 1-bit CRC with 32-bit Poly
// Module Name: crc32
// Project Name: QOLink
// Target Devices: 
// Tool Versions: 
// Description: Simple 32-bit CRC bitwise calculation module using Ethernet standard IEEE802.3-2022 as a reference, specifically
//              Section 3.2.9, additionally following the shift register process from https://www.sunshine2k.de/articles/coding/crc/understanding_crc.html
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module crc32(
input clk, in, reset, enable,
output [31:0] out);
reg [31:0] crc;
wire feedback;

assign feedback = crc[31] ^ in; //XOR the input and the MSB of the shift register
assign out = crc ^ 32'hFFFFFFFF;

always@(posedge clk or posedge reset) //trigger on either clock edge or async reset
    if(reset==1) crc <= 32'hFFFFFFFF; //reset after input is done sending
    else if(enable==1) begin //ensures that it only works when given enable signal
      if(feedback==1) crc <= (crc << 1) ^ 32'h04C11DB7; //check if polynomial division is necessary, using the ethernet standard polynomial
        else crc <= crc << 1;
    end
endmodule
