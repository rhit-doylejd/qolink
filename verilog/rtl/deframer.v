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

//interpreted from received signal
output reg [1:0] packet_class, 
output reg [5:0] sequence,
output reg [23:0] calculated_delay,
output reg [255:0] payload,

output packet_valid,
input packet_ready,
//input byte stream
input [7:0] receive_data,
input receive_start,
input receive_valid,
output receive_ready);

localparam  IDLE = 3'd0, //default idle state
            HEADER = 3'd1,
            TIMESTAMP = 3'd2,
            PAYLOAD = 3'd3,
            FCS = 3'd4,
            CRC_CHECK = 3'd5,
            OUTPUT = 3'd6;
            
reg [2:0] state; //current state
//registers for extracted fields that need to be processed
reg [7:0] header_reg; //need to split header into class/length
reg [31:0] fcs_reg; //give to CRC module to check

//indices
reg [1:0] byte_index; //byte within non-payload field
reg [4:0] payload_index; //byte within payload field
wire receive_acc; //handshake wires
wire payload_acc;
//connects to the CRC module
wire crc_reset;
wire crc_enable;
wire [7:0] crc_input;
wire [31:0] crc_output;

//constant assignments
assign busy = (state != IDLE);
assign receive_ready = !reset && ((state == IDLE) || (state == TIMESTAMP) || (state == PAYLOAD) || (state == FCS)); //states that accept input bytes
assign receive_accept = receive_valid && receive_ready;
assign crc_reset = reset || (state == IDLE); //reset crc module between frames
assign crc_data = (state == HEADER) ? header_reg : receive_data; //if state is header feed header register to crc module
assign crc_enable = !reset && ((state == HEADER) || (receive_accept && ((state == TIMESTAMP) || (state == PAYLOAD))));

//set up crc module
crc32_byte crc_module(
    .clk(clk),
    .in(transmit_data),
    .reset(crc_reset),
    .enable(crc_enable),
    .out(crc_output)
);

//TODO FINISH STATES
always @(posedge clk or posedge reset) begin
    if(reset) begin //clear all registers, set state to IDLE, set done to 0, set all indices to 0
        state <= IDLE;
        done <= 0;
        error <= 0;
        
        //oclear utputs
        packet_class <= 0;
        sequence <= 0;
        calculated_delay <= 0;
        payload <= 0;
        
        //clear registers
        header_reg <= 0;
        fcs_reg <= 0;
        
        // clear indices
        byte_index <= 0;
        payload_index <= 0;
    end
    else begin
        done <= 0;
        error <= 0;
        
        case(state) //handle switching to next state and managing what needs to be done during a state
            IDLE: begin
                if(receive_accept && receive_start) begin //start interpreting data stream
                    header_reg <= receive_data; //header
                    packet_class <= receive_data[7:6]; //top 2 bits
                    sequence <= receive_data [5:0]; //bottom 6 bits
                    state <= HEADER;
                end
                //otherwise do nothing
            end

            HEADER: begin //send header to CRC
                state <= TIMESTAMP;
            end
            
            TIMESTAMP: begin //send 3 timestamp bytes
                if(receive_accept) begin
                    calculated_delay[23 - 8 * byte_index -: 8] <= receive_data;
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
            CRC_CHECK: begin
            end
            OUTPUT: begin
            end
        endcase
    end
end




endmodule
