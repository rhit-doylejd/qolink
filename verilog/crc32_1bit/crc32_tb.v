`timescale 1ns / 1ps

module crc32_tb;
reg clk, X, reset, enable;
wire [31:0] out;
reg[71:0] packet; //sample packet of ASCII "123456789", which should result in CRC of 0xFC891918 (standard test result without byte reflection)
integer i; //counter used in for loop
    //crc32(clk, in, reset, enable, out)
    crc32 dut(clk, X, reset, enable, out);
    initial begin 
        clk = 0; 
        X = 0;
        reset = 1;
        enable = 0;
        packet = "123456789";
        @(negedge clk) reset = 0;
        enable = 1;
        for(i = 71; i >= 0; i = i - 1) begin //feed input into module bit-by-bit for entire sample packet
            X = packet[i];
            @(negedge clk);
        end
        enable = 0;
        $finish;
    end
        
always #5 clk=~clk; //10 ns full clock cycle
endmodule
