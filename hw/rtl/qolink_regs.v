`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Rose-Hulman Institute of Technology QOLink Team
// Engineer: Joshua Doyle
//
// Create Date: 10/29/2026
// Design Name: QOLink register block
// Module Name: qolink_regs
// Project Name: QOLink
// Target Devices: Nexys A7-100T (XC7A100T)
// Tool Versions: Vivado 2024.2
// Description: Wishbone slave on the NEORV32 XBUS (pipelined Wishbone subset,
//              NEORV32 v1.13.6 data sheet, "XBUS Bus Protocol"). Holds the
//              QOLink registers. Currently one 32-bit read/write scratch
//              register used to test CPU-to-gateware access.
//              Register map must match src/qolink/qolink-registers.ads.
//
// Dependencies: none
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//   Offset 0x000  SCRATCH  R/W  32-bit test register, resets to 0
//   Any other offset in the 4 KB window answers with a bus error.
//////////////////////////////////////////////////////////////////////////////////

module qolink_regs #(
    parameter [31:0] BASE_ADDR = 32'hF000_0000  // must match Base_Address in Ada; 4 KB aligned
)(
    input             clk,
    input             rst_n,       // active-low reset, same reset as the NEORV32

    // Wishbone slave port, connected to the NEORV32 XBUS
    input      [31:0] wb_adr_i,    // address
    input      [31:0] wb_dat_i,    // write data from the CPU
    output reg [31:0] wb_dat_o,    // read data to the CPU
    input             wb_we_i,     // 1 = write, 0 = read
    input      [3:0]  wb_sel_i,    // byte enables
    input             wb_stb_i,    // request strobe (one-cycle pulse)
    input             wb_cyc_i,    // bus cycle in progress
    output reg        wb_ack_o,    // transfer done (one-cycle pulse)
    output reg        wb_err_o     // transfer rejected (one-cycle pulse)
);

    // Register offsets, in bytes from BASE_ADDR
    localparam [11:0] OFF_SCRATCH = 12'h000;

    // Registers
    reg [31:0] scratch;

    // Request decode
    wire        request   = wb_cyc_i & wb_stb_i;                    // a new transfer this cycle
    wire        in_window = (wb_adr_i[31:12] == BASE_ADDR[31:12]);  // address is ours
    wire [11:0] offset    = wb_adr_i[11:0];                         // which register

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scratch  <= 32'h0000_0000;
            wb_dat_o <= 32'h0000_0000;
            wb_ack_o <= 1'b0;
            wb_err_o <= 1'b0;
        end else begin
            // ack and err are high for exactly one cycle per request
            wb_ack_o <= 1'b0;
            wb_err_o <= 1'b0;

            if (request && in_window) begin
                case (offset)
                    OFF_SCRATCH: begin
                        if (wb_we_i) begin
                            // write only the bytes the CPU selected
                            if (wb_sel_i[0]) scratch[ 7: 0] <= wb_dat_i[ 7: 0];
                            if (wb_sel_i[1]) scratch[15: 8] <= wb_dat_i[15: 8];
                            if (wb_sel_i[2]) scratch[23:16] <= wb_dat_i[23:16];
                            if (wb_sel_i[3]) scratch[31:24] <= wb_dat_i[31:24];
                        end
                        wb_dat_o <= scratch;   // read data, valid together with ack
                        wb_ack_o <= 1'b1;
                    end
                    default: begin
                        wb_err_o <= 1'b1;      // no register at this offset
                    end
                endcase
            end
        end
    end

endmodule