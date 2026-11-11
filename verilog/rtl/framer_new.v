`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/24/2026 07:46:56 PM
// Design Name: 
// Module Name: framer_new
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.02 Remade to fit new specifications
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module framer_new(
//Control Signals
input clk, reset, start,
output busy, 
output reg done,
//Header
input [1:0] packet_class,
//Sequence generated internally
//Timestamp
input [47:0] timestamp, //captured when payload queued "Timestamp A"
input [47:0] current_timestamp, //current captured value "Timestamp C"
output timestamp_req, //requests timestamp capture 

//Payload, fixed 32-byte length fed in one cycle from FIFO
input [255:0] payload,
//FCS generated internally
output reg [7:0] transmit_data, //byte being streamed out
output transmit_start, //Signals encoder that header is transmitting
output reg transmit_valid, //framer ready to send
input transmit_ready //transmitter ready
    );

//States
localparam  IDLE = 3'd0, //default idle state
            TIMESTAMP_REQ = 3'd1, //signal to timestamp module to output current timestamp
            TIMESTAMP_WAIT = 3'd2, //wait for value to be saved
            HEADER = 3'd3, //transmit class/sequence
            TIMESTAMP = 3'd4, //transmit calculated delay
            PAYLOAD = 3'd5, //transmit 32-byte payload
            FCS = 3'd6; //send FCS


reg [2:0] state; //current state
//registers for all fields
reg [1:0] class_reg; //2 bit class field
reg [5:0] sequence_reg; //sequence number for current frame, 6 bits
reg [5:0] sequence_count [0:3]; //sequence count for each class passed to sequence reg
reg [47:0] timestamp_reg; //Starting timestamp "A"
reg [255:0] payload_reg;

//Captured internally
reg [23:0] calculated_delay; //Subtract timestamp_reg (Timestamp A) from current_timestamp (Timestamp C)

//Indices
reg [1:0] byte_index; //index for FCS, need 4 values
reg [4:0] payload_index; //index for payload, need 32 values

//Used for continuously assigning combined fields/subtracted fields
wire [7:0] header; //class + sequence (2b + 6b)
wire transmit_accept;
wire [47:0] timestamp_subtract; //assigned as current_timestamp - timestamp_reg (Timestamp C - timestamp A)

//connects to the CRC module
wire crc_reset;
wire crc_enable;
wire [31:0] crc_output;
integer i;

//constant assignments
assign busy = (state != IDLE);
assign header = {class_reg, sequence_reg}; //combine bits for header 2b + 6b
assign transmit_accept = transmit_valid && transmit_ready;
assign transmit_start = (state == HEADER); //signals to encoder that header is being transmitted
assign timestamp_req = (state == TIMESTAMP_REQ) && !reset;
assign timestamp_subtract = current_timestamp - timestamp_reg;
assign crc_reset = reset || (state == IDLE); //reset when signal given or when idle
assign crc_enable = transmit_accept && ((state == HEADER) || (state == TIMESTAMP) || (state == PAYLOAD));

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
    transmit_valid = 0;
    
    case(state)

        HEADER: begin
            transmit_data = header; //one-byte header
            transmit_valid = 1;
        end
        TIMESTAMP: begin
            transmit_data = calculated_delay[23 - 8 * byte_index -: 8]; //selects 8 bits at a time using byte index as a reference
            transmit_valid = 1;
        end
        PAYLOAD: begin
            transmit_data = payload_reg[255 - 8 * payload_index -: 8]; //iterate through 32-byte payload one byte at a time
            transmit_valid = 1;
        end
        FCS: begin
            transmit_data = crc_output[31 - 8 * byte_index -: 8]; //selects 8 bits at a time using byte index as a reference
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
        sequence_reg <= 0;
        for(i = 0; i < 4; i = i + 1) sequence_count[i] <= 0;
        timestamp_reg <= 0;
        payload_reg <= 0;
        calculated_delay <= 0;
        byte_index <= 0;
        payload_index <= 0;
    end
    else begin
        done <= 0;
        case(state) //handle switching to next state and managing what needs to be done during a state
            IDLE: begin
                if(start) begin //start condition, initialize the registers and reset indices
                    class_reg <= packet_class;
                    sequence_reg <= sequence_count[packet_class];
                    timestamp_reg <= timestamp;
                    payload_reg <= payload;
                    byte_index <= 0;
                    payload_index <= 0;
                    state <= TIMESTAMP_REQ; //go to next state
                end
                //otherwise do nothing
            end
            
            TIMESTAMP_REQ: begin //one cycle wait for timestamp capture
                state <= TIMESTAMP_WAIT;
            end
            
            TIMESTAMP_WAIT:begin
                calculated_delay <= timestamp_subtract[23:0];
                state <= HEADER;
            end
            
            HEADER: begin //transmit header byte
                if(transmit_accept) state <= TIMESTAMP;
            end
            
            TIMESTAMP: begin //send 3 timestamp bytes
                if(transmit_accept) begin
                    if(byte_index == 2) begin
                        byte_index <= 0;
                        state <= PAYLOAD;
                    end
                    else byte_index <= byte_index + 1;
                end
            end
            
            PAYLOAD: begin //transmit through entire payload length, use payload_index up to 32 bytes
                if(transmit_accept) begin
                    if(payload_index == 31) begin
                        payload_index <= 0;
                        state <= FCS;
                    end
                    else payload_index <= payload_index + 1;
                end
            end
            FCS: begin //output crc to transmitter, same as timestamp with byte_index = 3
                if(transmit_accept) begin
                    if(byte_index == 3) begin
                        byte_index <= 0;
                        sequence_count[class_reg] <= sequence_count[class_reg] + 1;
                        done <= 1;
                        state <= IDLE;
                    end
                    else byte_index <= byte_index + 1;
                end
            end
        endcase
    end
end
endmodule
