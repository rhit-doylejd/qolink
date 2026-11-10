`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/07/2026 07:05:53 PM
// Design Name: 
// Module Name: deframer
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


module deframer( //signals are similar to framer, except with error field for CRC check
//Control Signals
input clk, reset,
output busy, 
output reg done, error, //error is new, from CRC check
output reg [1:0] packet_class, //Matched to framer
output reg [10:0] length,
output reg [47:0] timestamp,
output [7:0] payload,
output payload_valid,
input payload_ready,
input [7:0] receive_data,
input [1:0] receive_type,
input receive_valid,
output receive_ready);

localparam  IDLE = 4'd0, //States are similar to 
            SFD = 4'd1,
            HEADER = 4'd2,
            SEQUENCE = 4'd3,
            TIMESTAMP = 4'd4,
            PAYLOAD = 4'd5,
            FCS = 4'd6,
            EFD = 4'd7,
            CRC_CHECK = 4'd8,
            OUTPUT = 4'd9;

localparam  TRANSMIT_BYTE = 2'b00, //matching the framer
            TRANSMIT_SFD = 2'b01,
            TRANSMIT_EFD = 2'b10;

reg [3:0] state; //current state
//registers for extracted fields that need to be processed
reg [15:0] header_reg; //need to split header into class/length
reg [31:0] fcs_reg; //give to CRC module to check
reg [7:0] payload_buffer [0:2047]; //holds payload until frame is validated by CRC, can store bytes up to length field max
//indices
reg [2:0] byte_index; //byte within non-payload field
reg [10:0] payload_index; //byte within payload field
wire receive_acc; //handshake wires
wire payload_acc;
//connects to the CRC module
wire crc_reset;
wire crc_enable;
wire [31:0] crc_output;
integer i;

endmodule
