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
//Sample packet test using FIFO to feed payload bits

module framer_tb; //reg/wires taken from framer module
reg clk, reset, start;
wire busy;
wire done;
reg [1:0] packet_class;
reg [10:0] length;
reg [63:0] timestamp;
wire [7:0] payload;
wire payload_valid;
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
   
//FIFO module, fill with payload bits and then send signal to FIFO from framer when ready to accept 
reg fifo_write; 
wire fifo_read;
reg [7:0] fifo_input;
wire [7:0] fifo_out;
wire fifo_full, fifo_empty;

fifo payload_fifo(.clk(clk), .reset(reset), .write(fifo_write), .read(fifo_read),
    .in(fifo_input), .out(fifo_out), .full(fifo_full), .empty(fifo_empty));

//assignments to connect input/outputs
assign payload = fifo_out; //continuous payload input is fifo output
assign payload_valid = !reset && !fifo_empty; //payload is valid as long as there's anything in the fifo
assign fifo_read = payload_valid && payload_ready; //read from fifo (remove byte from pointer) only if it is read by framer

 






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
    //Need to feed payload into FIFO
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
