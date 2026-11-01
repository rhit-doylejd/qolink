`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/24/2026 07:46:56 PM
// Design Name: 
// Module Name: framer
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


module framer(
//Control Signals
input clk, reset, start,
output busy, 
output reg done,
//Preamble generated internally
//SFD generated internally
//Header
input [1:0] packet_class,
input [10:0] length,
//Sequence generated internally
//Timestamp
input [63:0] timestamp,
//Payload
input [7:0] payload,
input payload_valid,
output payload_ready,
//FCS generated internally
//EFD generated internally
output reg [7:0] transmit_data, //byte being streamed out
output reg [1:0] transmit_type, //manchester, sfd, or efd
output reg transmit_valid, //framer ready to send
input transmit_ready //transmitter ready
    );
localparam  IDLE = 4'd0, //states
            PREAMBLE = 4'd1,
            SFD = 4'd2,
            HEADER = 4'd3,
            SEQUENCE = 4'd4,
            TIMESTAMP = 4'd5,
            PAYLOAD = 4'd6,
            CRC_CAPTURE = 4'd7, 
            FCS = 4'd8,
            EFD = 4'd9;

localparam  TRANSMIT_BYTE = 2'b00, //fed to the transmitter so it knows what to output
            TRANSMIT_SFD = 2'b01,
            TRANSMIT_EFD = 2'b10;
reg [3:0] state; //current state
//registers for all fields
reg [1:0] class_reg;
reg [10:0] length_reg;
reg [7:0] sequence_reg; //sequence number for current frame
reg [7:0] sequence_count [0:3]; //sequence count for each class passed to sequence reg
reg [63:0] timestamp_reg;
reg [31:0] fcs_reg;
reg [2:0] byte_index; //byte within non-payload field
reg [10:0] payload_index; //byte within payload field
wire [15:0] header; //class + length + 3 reserved
wire transmit_accept;
//connects to the CRC module
wire crc_reset;
wire crc_enable;
wire [31:0] crc_output;
integer i;

//constant assignments
assign busy = (state != IDLE);
assign header = {class_reg, length_reg, 3'b000}; //combine bits for header
assign transmit_accept = transmit_valid && transmit_ready;
assign payload_ready = (state == PAYLOAD) && transmit_ready;
assign crc_reset = reset || (state == IDLE); //reset when signal given or when idle
assign crc_enable = transmit_accept && ((state == HEADER) || (state == SEQUENCE) || (state == TIMESTAMP) || (state == PAYLOAD));

//set up crc module
crc32_byte crc_module(
    .clk(clk),
    .in(transmit_data),
    .reset(crc_reset),
    .enable(crc_enable),
    .out(crc_output)
);

//update output for state
always @(*) begin
    transmit_data = 8'h00; //default no output
    transmit_type = TRANSMIT_BYTE;
    transmit_valid = 0;
    
    case(state)
        PREAMBLE: begin //send specific preamble pattern byte
            transmit_data = 8'b01010101; //can change, preamble used for sync
            transmit_type = TRANSMIT_BYTE;
            transmit_valid = 1;
        end
        SFD: begin //tell transmitter to send SFD (NOT MANCHESTER) byte
            transmit_type = TRANSMIT_SFD;
            transmit_valid = 1;
        end
        HEADER: begin
            if(byte_index == 0) transmit_data = header[15:8]; //upper header bits
            else transmit_data = header[7:0]; //lower 8 bits of header
            transmit_type = TRANSMIT_BYTE;
            transmit_valid = 1;
        end
        SEQUENCE: begin
            transmit_data = sequence_reg; //sequenc counter register
            transmit_type = TRANSMIT_BYTE;
            transmit_valid = 1;
        end
        TIMESTAMP: begin
            transmit_data = timestamp_reg[63 - 8 * byte_index -: 8]; //selects 8 bits at a time using byte index as a reference
            transmit_type = TRANSMIT_BYTE;
            transmit_valid = 1;
        end
        PAYLOAD: begin
            transmit_data = payload;
            transmit_type = TRANSMIT_BYTE;
            transmit_valid = payload_valid; //only transmit if payload input is up to date
        end
        FCS: begin
            transmit_data = fcs_reg[31 - 8 * byte_index -: 8]; //selects 8 bits at a time using byte index as a reference
            transmit_type = TRANSMIT_BYTE;
            transmit_valid = 1;
        end
        EFD: begin
            transmit_type = TRANSMIT_EFD;
            transmit_valid = 1;
        end
    endcase   
end
//update states
always @(posedge clk or posedge reset) begin
    if(reset) begin //clear all registers, set state to IDLE, set done to 0, set all indices to 0
        state <= IDLE;
        done <= 0;
        class_reg <= 0;
        length_reg <= 0;
        sequence_reg <= 0;
        timestamp_reg <= 0;
        fcs_reg <= 0;
        byte_index <= 0;
        payload_index <= 0;
        for(i = 0; i < 4; i = i + 1) sequence_count[i] <= 0;
    end
    else begin //TODO finish state machine
        case(state) //handle switching to next state and managing what needs to be done during a state
            IDLE: begin
                if(start) begin //start condition, initialize the registers and reset indices
                    done <= 0;
                    class_reg <= packet_class;
                    length_reg <= length;
                    sequence_reg <= sequence_count[packet_class];
                    timestamp_reg <= timestamp;
                    byte_index <= 0;
                    payload_index <= 0;
                    state <= PREAMBLE; //go to next state
                end
                //otherwise do nothing
            end
            PREAMBLE: begin
                if(transmit_accept) state <= SFD; //move onto SFD state
            end
            SFD: begin
                if(transmit_accept) state <= HEADER;
            end
            HEADER: begin //switch to sequence if byte_index = 1 otherwise switch byte index from 0 to 1
                if(transmit_accept) begin
                    if(byte_index == 1) begin
                        byte_index <= 0;
                        state <= SEQUENCE;
                    end
                    else byte_index <= 1;
                end
            end
            SEQUENCE: begin
                if(transmit_accept) state <= TIMESTAMP;
            end
            TIMESTAMP: begin //similar to header, but increment byte index
                if(transmit_accept) begin
                    if(byte_index == 7) begin
                        byte_index <= 0;
                        state <= PAYLOAD;
                    end
                    else byte_index = byte_index + 1;
                end
            end
            PAYLOAD: begin
            end
            CRC_CAPTURE: begin
            end
            FCS: begin
            end
            EFD: begin
            end
        endcase
    end
end
endmodule
