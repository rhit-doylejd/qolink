`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/20/2026 02:13:32 PM
// Design Name: 
// Module Name: fifo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 16 bit FIFO module meant for testing with 1 byte of data per unit, 16 spaces, should be scalable for future use
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: incrementing the limited-size pointers should function as wraparound as it takes the lower 4 bits only
// 
//////////////////////////////////////////////////////////////////////////////////


module fifo(
input clk, reset, write, read, 
input wire [7:0] in, //write read flags to signal I/O
output reg [7:0] out, 
output wire full, empty //full empty flags to signal status of FIFO
);
reg [7:0] data [15:0]; //data storage, 16 spaces of 1 byte each
reg [3:0] read_ptr; //read address within data
reg [3:0] write_ptr; //write address within data
reg [4:0] count;
wire read_acc; //Checks to ensure FIFO isn't empty rather than using read enable input bit
wire write_acc; //Same as above, but for write and the FIFO being full before writing
    
assign read_acc = read && !empty;
assign write_acc = write && !full;
assign full = (count == 16);
assign empty = (count == 0);

always@(posedge clk or posedge reset)
    if(reset) begin //reset pointers, any garbage data stored within will be overwritten so no need to empty
        read_ptr <= 0;
        write_ptr <= 0;
        count <= 0;
        out <= 0;
    end else begin
        case ({read_acc, write_acc}) //four cases depending on read/write enable
            2'b00: begin //Nothing happens 
                end
            2'b01: begin //write, no read. increment count and write ptr and update data from input
                count <= count + 1'b1;
                data[write_ptr] <= in;
                write_ptr <= write_ptr + 1'b1;
                end
            2'b10: begin //read, no write. decrement count and increment read ptr and update output from data
                count <= count - 1'b1;
                out <= data[read_ptr];
                read_ptr <= read_ptr + 1'b1;
                end
            2'b11: begin //read and write, don't change count. increment write/read ptr, update output, update data
                data[write_ptr] <= in;
                out <= data[read_ptr];
                write_ptr <= write_ptr + 1'b1;
                read_ptr <= read_ptr + 1'b1;
                end
        endcase
    end
endmodule
