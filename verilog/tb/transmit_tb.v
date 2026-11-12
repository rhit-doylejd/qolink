`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/11/2026 05:07:05 PM
// Design Name: 
// Module Name: transmit_tb
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


module transmit_tb;
reg clk, reset; //copied from transmit
wire busy, done;
reg [1:0] packet_class;
reg [255:0] payload;
reg packet_valid;
wire packet_ready;
wire [7:0] transmit_data;
wire transmit_valid;
wire transmit_start;
reg transmit_ready;

transmit dut(.clk(clk), .reset(reset), .busy(busy), .done(done), .packet_class(packet_class), 
    .payload(payload), .packet_valid(packet_valid), .packet_ready(packet_ready), .transmit_data(transmit_data), 
    .transmit_valid(transmit_valid), .transmit_start(transmit_start), .transmit_ready(transmit_ready));

integer i;

initial begin
    clk = 0;
    reset = 1;
    packet_valid = 0;
    transmit_ready = 1;
    
    //sample packet:
    packet_class = 2'b10;
    for(i = 0; i < 32; i = i + 1) payload[255 - 8*i -: 8] = i;
    @(negedge clk);
    reset = 0;
    @(negedge clk);
    packet_valid = 1; //start the transmit module
    wait(packet_ready); //wait for packet to be ready
    @(negedge clk);
    packet_valid = 0;
    wait(done);
    @(negedge clk);
    $finish;
end
always #5 clk = ~clk;
endmodule
