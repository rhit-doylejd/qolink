`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Rose-Hulman Institute of Technology QOLink Team
// Engineer: Mateo Olson
// 
// Create Date: 10/06/2026 11:49:22 AM
// Design Name: Simple 32-bit CRC Byte
// Module Name: crc32_byte
// Project Name: QOLink
// Target Devices: 
// Tool Versions: 
// Description: Simple 32-bit CRC calculation module, similar to crc32.v but unrolled to process 8 bits per clock cycle
// Dependencies: 
// 
// Revision: 
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module crc32_byte(
input clk,
input [7:0] in, 
input reset, enable, //Uses 16 bits per clock cycle as an input rather than a single bit
output [31:0] out);
reg [31:0] crc;
reg [31:0] crc_store; //used for holding a current crc value as it iterates through the stream 
integer i; //Loop counter, this implementation relies on Vivado synthesis to unroll the for loop 

assign out = crc ^ 32'hFFFFFFFF;

always @(*) begin
    crc_store = crc;
    for (i = 7; i >= 0; i = i - 1) begin //similar process to the crc32, but in a for loop checking through a byte
        if (crc_store[31]^in[i])
            crc_store = (crc_store << 1) ^ 32'h04C11DB7;
        else crc_store = crc_store << 1;     
    end
end

always@(posedge clk or posedge reset) begin //trigger on either clock edge or async reset
    if(reset) crc <= 32'hFFFFFFFF; //reset after input is done sending
    else if(enable==1) crc <= crc_store;
    end
endmodule
