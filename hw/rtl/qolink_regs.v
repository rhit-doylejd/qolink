`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Rose-Hulman Institute of Technology QOLink Team
// Engineer: Joshua Doyle, Eric Steuber
//
// Create Date: 10/29/2026
// Design Name: QOLink register block
// Module Name: qolink_regs
// Project Name: QOLink
// Target Devices: Nexys A7-100T (XC7A100T)
// Tool Versions: Vivado 2024.2
// Description: Wishbone slave on the NEORV32 XBUS (pipelined Wishbone subset,
//              NEORV32 v1.13.6 data sheet, "XBUS Bus Protocol"). Holds the
//              QOLink registers. Contains scratch register for initial testing
//              and TX/RX FIFOs.
//              Register map must match src/qolink/qolink-registers.ads.
//
// Dependencies: fifo.v, loopback.v
//
// Revision:
// Revision 0.01 - File Created
// Revision 0.02 - Added FIFO module
// Revision 0.03 - Added RX FIFO, loopback, LOOPBACK_CTRL
// Additional Comments:
//   Offset 0x000  SCRATCH          R/W  32-bit test register, resets to 0
//   Offset 0x004  TX_FIFO_DATA     W    [7:0] push byte. Error if TX full or byte 0 not selected
//   Offset 0x008  TX_FIFO_STATUS   R    [0] empty, [1] full
//   Offset 0x00C  RX_FIFO_DATA     R    [7:0] pop byte. Error if RX empty. Ack is 1 cycle later
//   Offset 0x010  RX_FIFO_STATUS   R    [0] empty, [1] full
//   Offset 0x014  LOOPBACK_CTRL    W    [7:0] move this many bytes TX -> RX (0 = cancel;
//                                       a write while busy replaces the count)
//                                  R    [8] busy, [7:0] bytes remaining
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
    localparam [11:0] OFF_TX_FIFO_DATA = 12'h004;
    localparam [11:0] OFF_TX_FIFO_STATUS = 12'h008;
    localparam [11:0] OFF_RX_FIFO_DATA = 12'h00C;
    localparam [11:0] OFF_RX_FIFO_STATUS = 12'h010;
    localparam [11:0] OFF_LOOPBACK_CTRL = 12'h014;

    // Registers
    reg [31:0] scratch;
    reg rx_pop_pending;

    // Request decode
    wire        request   = wb_cyc_i & wb_stb_i;                    // a new transfer this cycle
    wire        in_window = (wb_adr_i[31:12] == BASE_ADDR[31:12]);  // address is ours
    wire [11:0] offset    = wb_adr_i[11:0];                         // which register

    // FIFO wires
    wire [7:0] tx_fifo_out;
    wire       tx_fifo_full;
    wire       tx_fifo_empty;
    wire [7:0] rx_fifo_in;
    wire [7:0] rx_fifo_out;
    wire       rx_fifo_full;
    wire       rx_fifo_empty;
    wire       read_tx_fifo;
    wire       write_rx_fifo;
    wire write_tx_fifo = request && in_window && wb_we_i && wb_sel_i[0] && (offset == OFF_TX_FIFO_DATA) && !tx_fifo_full;
    wire read_rx_fifo  = request && in_window && !wb_we_i && wb_sel_i[0] && (offset == OFF_RX_FIFO_DATA) && !rx_fifo_empty;

    //Loopback Wires
    wire       loopback_busy;
    wire [7:0] loopback_remaining;
    wire loopback_start = request && in_window && wb_we_i && wb_sel_i[0]
                        && (offset == OFF_LOOPBACK_CTRL);

    // TX FIFO module
    fifo u_tx_fifo (
        .clk   (clk),
        .reset (~rst_n),
        .write (write_tx_fifo),
        .read  (read_tx_fifo),
        .in    (wb_dat_i[7:0]),
        .out   (tx_fifo_out),
        .full  (tx_fifo_full),
        .empty (tx_fifo_empty)
    );

    // RX FIFO module
    fifo u_rx_fifo (
        .clk   (clk),
        .reset (~rst_n),
        .write (write_rx_fifo),
        .read  (read_rx_fifo),
        .in    (rx_fifo_in),
        .out   (rx_fifo_out),
        .full  (rx_fifo_full),
        .empty (rx_fifo_empty)
    );

    loopback u_loopback (
        .clk   (clk),
        .rst_n (rst_n),
        .start (loopback_start),
        .count (wb_dat_i[7:0]),
        .busy  (loopback_busy),
        .remaining (loopback_remaining),
        .tx_empty (tx_fifo_empty),
        .rx_full (rx_fifo_full),
        .data_in (tx_fifo_out),
        .data_out (rx_fifo_in),
        .read  (read_tx_fifo),
        .write (write_rx_fifo)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scratch  <= 32'h0000_0000;
            wb_dat_o <= 32'h0000_0000;
            wb_ack_o <= 1'b0;
            wb_err_o <= 1'b0;
            rx_pop_pending <= 1'b0;
        end else begin
            // ack and err are high for exactly one cycle per request
            wb_ack_o <= 1'b0;
            wb_err_o <= 1'b0;
            rx_pop_pending <= 1'b0;
            if (rx_pop_pending) begin // one cycle after the pop: rx_fifo_out is valid
                wb_dat_o <= {24'h0, rx_fifo_out};
                wb_ack_o <= 1'b1;
            end
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
                    OFF_TX_FIFO_DATA: begin
                        if (write_tx_fifo) begin
                            wb_ack_o <= 1'b1;   // push happened via write_tx_fifo
                        end else begin
                            wb_err_o <= 1'b1;
                        end
                    end
                    OFF_TX_FIFO_STATUS: begin
                        if (wb_we_i) begin
                            wb_err_o <= 1'b1;   // read-only register
                        end else begin
                            wb_dat_o <= {30'h0, tx_fifo_full, tx_fifo_empty};
                            wb_ack_o <= 1'b1;
                        end
                    end
                    OFF_RX_FIFO_DATA: begin
                        if (read_rx_fifo)
                            rx_pop_pending <= 1'b1; // pop happens this edge; ack next cycle
                        else
                            wb_err_o <= 1'b1;
                    end
                    OFF_RX_FIFO_STATUS: begin
                        if (wb_we_i) begin
                            wb_err_o <= 1'b1;   // read-only register
                        end else begin
                            wb_dat_o <= {30'h0, rx_fifo_full, rx_fifo_empty};
                            wb_ack_o <= 1'b1;
                        end
                    end
                    OFF_LOOPBACK_CTRL: begin
                        wb_dat_o <= {23'h0, loopback_busy, loopback_remaining};  // bit 8 = busy, [7:0] = remaining
                        wb_ack_o <= 1'b1;   // write starts a transfer; read returns status
                    end
                    default: begin
                        wb_err_o <= 1'b1;      // no register at this offset
                    end
                endcase
            end
        end
    end

endmodule