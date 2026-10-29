`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/26/2026 08:27:04 PM
// Design Name: 
// Module Name: crc32_byte_tb
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

module crc32_byte_tb;
reg clk, reset, enable;
reg [7:0] X;
wire [31:0] out;
reg[71:0] packet; //sample packet of ASCII "123456789", which should result in CRC of 0xFC891918 (standard test result without byte reflection)
integer i; //counter used in for loop
    //crc32(clk, in, reset, enable, out)
    crc32_byte dut(clk, X, reset, enable, out);
    initial begin 
        clk = 0; 
        X = 0;
        reset = 1;
        enable = 0;
        packet = "123456789";
        @(negedge clk) reset = 0;
        enable = 1;
        for(i = 71; i >= 7; i = i - 8) begin //feed input into module bit-by-bit for entire sample packet
            X = packet[i -: 8];
            @(negedge clk);
        end
        enable = 0;
        $finish;
    end
        
always #5 clk=~clk;
endmodule
