`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/11/2026 03:44:22 PM
// Design Name: 
// Module Name: transmit
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

//module that combines the timestamp, two FIFOs, and the framer, for final version add other classes 
//  and sort fifo pairs into classes
module transmit(
//control signals
input clk, reset,
output busy, done,

//from driver
input [1:0] packet_class,
input [255:0] payload,
input packet_valid,
output packet_ready,

//to encoder
output [7:0] transmit_data,
output transmit_valid,
output transmit_start,
input transmit_ready
    );
    
reg [1:0] class_reg; //holds values while timestamp is being captured
reg [255:0] payload_reg;
reg waiting; //packet accepted but not yet in FIFO

//for Timestamp module
wire queued_req;
wire frame_req;
wire [47:0] queued_timestamp;
wire [47:0] frame_timestamp;

//for FIFO modules
wire [49:0] metadata_fifo_out;
wire metadata_fifo_full, metadata_fifo_empty;
wire [255:0] payload_fifo_out;
wire payload_fifo_full, payload_fifo_empty;
wire fifo_write, fifo_read; //used for both at the same time

//for Framer module
wire framer_start, framer_busy; //used to pop from fifo and start framing, and to signal framer is processing

wire packet_accept; //accept a packet if it is valid and there is room

//constant assignments
assign packet_ready = !reset && !waiting && !metadata_fifo_full && !payload_fifo_full; //only ready if no FIFO is full, not being reset, and not waiting to put frame in fifo 
assign packet_accept = packet_valid && packet_ready; //accept when ready and driver gives packet
assign queued_req = packet_accept; //capture timestamp once packet is accepted from driver
assign fifo_write = !reset && waiting && !metadata_fifo_full && !payload_fifo_full; //write to FIFO during waiting
assign framer_start = !reset && !framer_busy && !metadata_fifo_empty && !payload_fifo_empty; //start framer if possible
assign fifo_read = framer_start; //read from FIFOs on framer start
assign busy = framer_busy;

//instantiate all modules
timestamp timestamp_module(
    .clk(clk), 
    .reset(reset), 
    .queued_req(queued_req), 
    .frame_req(frame_req),
    .queued_timestamp(queued_timestamp), 
    .frame_timestamp(frame_timestamp)
);

fifo #(
    .WIDTH(50)
) metadata_fifo(
    .clk(clk),
    .reset(reset), 
    .write(fifo_write),
    .read(fifo_read),
    .in({class_reg, queued_timestamp}),
    .out(metadata_fifo_out),
    .full(metadata_fifo_full),
    .empty(metadata_fifo_empty)
);

fifo #(
    .WIDTH(256)
) payload_fifo(
    .clk(clk),
    .reset(reset), 
    .write(fifo_write),
    .read(fifo_read),
    .in(payload_reg),
    .out(payload_fifo_out),
    .full(payload_fifo_full),
    .empty(payload_fifo_empty)
);

framer_new framer_module(
    .clk(clk),
    .reset(reset), 
    .start(framer_start),
    .busy(framer_busy),
    .done(done),
    .packet_class(metadata_fifo_out [49:48]), //class bits from metadata
    .timestamp(metadata_fifo_out [47:0]), //timestamp bits from metadata
    .current_timestamp(frame_timestamp),
    .timestamp_req(frame_req),
    .payload(payload_fifo_out),
    .transmit_data(transmit_data),
    .transmit_start(transmit_start),
    .transmit_valid(transmit_valid),
    .transmit_ready(transmit_ready)
);
    
always @(posedge clk or posedge reset) begin
    if(reset) begin //reset the registers
        class_reg <= 0;
        payload_reg <= 0;
        waiting <= 0;
    end
    else begin
        if(packet_accept) begin //set registers
            class_reg <= packet_class;
            payload_reg <= payload;
            waiting <= 1;
        end
        else if(fifo_write) waiting <= 0;
    end
end
    
    
    
    
endmodule
