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
//Sample packet test

module framer_tb; //reg/wires taken from framer module
reg clk, reset, start;
wire busy;
wire done;
reg [1:0] packet_class;
reg [10:0] length;
reg [63:0] timestamp;
reg [7:0] payload;
reg payload_valid;
wire payload_ready;
wire [7:0] transmit_data;
wire [1:0] transmit_type;
wire transmit_valid;
reg transmit_ready;
//assigning by name just to avoid confusion
framer dut(.clk(clk), .reset(reset), .start(start), .busy(busy), .done(done),
    .packet_class(packet_class), .length(length), .timestamp(timestamp), .payload(payload), .payload_valid(payload_valid),
    .payload_ready(payload_ready), .transmit_data(transmit_data), .transmit_type(transmit_type), 
    .transmit_valid(transmit_valid), .transmit_ready(transmit_ready));
initial begin
    clk <= 0;
    reset <= 1;
    start <= 0;
    @(negedge clk);
    reset <= 0;
    start <= 1;
    transmit_ready <= 1;
    //create sample packet with following values: class: Binary 10, length: Decimal 8, 
    // timestamp: Hex 0x1F1E1D1C1B1A1918, payload: Hex 0x2F2E2D2C2B2A2928
    packet_class <= 2'b10;
    length <= 11'h8;
    timestamp <= 64'h1F1E1D1C1B1A1918;
    @(negedge clk);
    start <= 0;
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    //Need to assign payload bytes one at a time:
    payload <= 8'h2F;
    payload_valid <= 1;
    @(negedge clk);
    payload <= 8'h2E;
    payload_valid <= 1;
    @(negedge clk);
    payload <= 8'h2D;
    payload_valid <= 1;
    @(negedge clk);
    payload <= 8'h2C;
    payload_valid <= 1;
    @(negedge clk);
    payload <= 8'h2B;
    payload_valid <= 1;
    @(negedge clk);
    payload <= 8'h2A;
    payload_valid <= 1;
    @(negedge clk);
    payload <= 8'h29;
    payload_valid <= 1;
    @(negedge clk);
    payload <= 8'h28;
    payload_valid <= 1;
    @(negedge clk);
    @(negedge clk);
    payload_valid <= 0;
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    $finish;
end
always #5 clk = ~clk;
endmodule
