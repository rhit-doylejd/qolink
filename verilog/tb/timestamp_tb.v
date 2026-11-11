`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/11/2026 02:33:33 PM
// Design Name: 
// Module Name: timestamp_tb
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


module timestamp_tb;
reg clk, reset, queued_req, frame_req;
wire [47:0] queued_timestamp, frame_timestamp;
timestamp dut(.clk(clk), .reset(reset), .queued_req(queued_req), .frame_req(frame_req),
    .queued_timestamp(queued_timestamp), .frame_timestamp(frame_timestamp));

initial begin
    clk = 0;
    reset = 1;
    queued_req = 0;
    frame_req = 0;
    @(negedge clk);
    reset = 0;
    #201;
    queued_req = 1;
    @(negedge clk);
    queued_req = 0;
    #401;
    frame_req = 1;
    @(negedge clk);
    frame_req = 0;
    $finish;
end
always #5 clk = ~clk;
endmodule
