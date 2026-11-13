`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/21/2026 01:59:13 PM
// Design Name: 
// Module Name: fifo_tb
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


module fifo_tb;
reg clk, reset, write, read;
reg [7:0] X; //input
wire [7:0] out;
wire full, empty;
integer i;

fifo dut(clk, reset, write, read, X, out, full, empty);

initial begin
    clk = 0;
    X = 0;
    reset = 1; //starting with reset condition
    write = 0;
    read = 0;
    
    @(negedge clk);
    reset = 0;
    //write test
    write = 1; //starting to write to the fifo
    for (i = 0; i < 16; i = i + 1) begin //fill fifo with integers 0 to 15
        X = i;
        @(negedge clk);
    end
    
    X = 8'hFF; //This write shouldn't go through or change anything, as the fifo is full
    @(negedge clk);
    write = 0;
    
    //read test
    read = 1; //starting to read from the fifo
    for (i = 0; i < 16; i = i + 1) begin //read 0 to 15 from the fifo, check order
        @(negedge clk);
    end
    
    @(negedge clk);//shouldn't read anything during this
    read = 0;
    
    //simultaneous read/write test
    write = 1;
    X = 8'hA1;
    @(negedge clk);
    X = 8'hB2;
    @(negedge clk);
    
    read = 1;
    X = 8'hC3;
    @(negedge clk);
    //check if fifo has B2 and C3 after this clock cycle
    write = 0;
    @(negedge clk);
    @(negedge clk);
    $finish;
    end

always #5 clk = ~clk;

endmodule
