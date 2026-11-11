`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/10/2026 06:09:51 PM
// Design Name: 
// Module Name: timestamp
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


module timestamp(
input clk, reset, queued_req, frame_req, //two input requests, two outputs
output reg [47:0] queued_timestamp, frame_timestamp //queued is for frames as they enter FIFO, current is for frames in framer
    );
reg [47:0] counter;
always @(posedge clk or posedge reset) begin
    if(reset) begin
        counter <= 0;
        queued_timestamp <= 0;
        frame_timestamp <= 0;
    end
    else begin 
        counter <= counter + 10;
        if(queued_req) queued_timestamp <= counter;
        if(frame_req) frame_timestamp <= counter;
    end
end
endmodule
