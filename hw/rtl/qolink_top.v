`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Rose-Hulman Institute of Technology QOLink Team
// Engineer: Joshua Doyle
//
// Create Date: 10/30/2026
// Design Name: QOLink top level
// Module Name: qolink_top
// Project Name: QOLink
// Target Devices: Nexys A7-100T (XC7A100T)
// Tool Versions: Vivado 2024.2
// Description: Top level of the QOLink FPGA design. Connects the NEORV32 CPU
//              (qolink_cpu) to the QOLink register block (qolink_regs) over
//              the XBUS, and both to the board's clock, reset, USB-UART and
//              one LED. Pin locations: hw/boards/<board>/<board>.xdc
//
// Dependencies: qolink_cpu.vhd, qolink_regs.v
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//   uart_rxd / uart_txd are named from the FPGA's point of view:
//   rxd = data the FPGA receives (from the PC), txd = data it sends.
//////////////////////////////////////////////////////////////////////////////////

module qolink_top (
    input  clk,            // 100 MHz board oscillator
    input  cpu_resetn,     // CPU RESET button, low while pressed
    input  uart_rxd,       // USB-UART: PC -> FPGA
    output uart_txd,       // USB-UART: FPGA -> PC
    output led_heartbeat   // blinks while the design is running
);

    //--------------------------------------------------------------------------
    // Reset synchronizer
    // The button can be released at any moment; this makes the end of reset
    // happen on a clock edge. Also holds reset for 2 cycles after configuration.
    //--------------------------------------------------------------------------
    reg [1:0] rst_sync = 2'b00;

    always @(posedge clk or negedge cpu_resetn) begin
        if (!cpu_resetn)
            rst_sync <= 2'b00;
        else
            rst_sync <= {rst_sync[0], 1'b1};
    end

    wire rst_n = rst_sync[1];

    //--------------------------------------------------------------------------
    // XBUS (Wishbone) between the CPU and the QOLink register block.
    // Names are from the CPU's point of view: wdat = CPU writes, rdat = CPU reads.
    //--------------------------------------------------------------------------
    wire [31:0] xbus_adr;
    wire [31:0] xbus_wdat;
    wire [31:0] xbus_rdat;
    wire [3:0]  xbus_sel;
    wire        xbus_we;
    wire        xbus_stb;
    wire        xbus_cyc;
    wire        xbus_ack;
    wire        xbus_err;

    //--------------------------------------------------------------------------
    // CPU: NEORV32 running the Ada program from IMEM
    //--------------------------------------------------------------------------
    qolink_cpu cpu (
        .clk_i       (clk),
        .rstn_i      (rst_n),
        .uart0_txd_o (uart_txd),
        .uart0_rxd_i (uart_rxd),
        .xbus_adr_o  (xbus_adr),
        .xbus_dat_o  (xbus_wdat),
        .xbus_we_o   (xbus_we),
        .xbus_sel_o  (xbus_sel),
        .xbus_stb_o  (xbus_stb),
        .xbus_cyc_o  (xbus_cyc),
        .xbus_dat_i  (xbus_rdat),
        .xbus_ack_i  (xbus_ack),
        .xbus_err_i  (xbus_err)
    );

    //--------------------------------------------------------------------------
    // QOLink register block (must match src/qolink/qolink-registers.ads)
    //--------------------------------------------------------------------------
    qolink_regs #(.BASE_ADDR(32'hF000_0000)) regs (
        .clk      (clk),
        .rst_n    (rst_n),
        .wb_adr_i (xbus_adr),
        .wb_dat_i (xbus_wdat),
        .wb_dat_o (xbus_rdat),
        .wb_we_i  (xbus_we),
        .wb_sel_i (xbus_sel),
        .wb_stb_i (xbus_stb),
        .wb_cyc_i (xbus_cyc),
        .wb_ack_o (xbus_ack),
        .wb_err_o (xbus_err)
    );

    //--------------------------------------------------------------------------
    // Heartbeat LED: bit 26 of a free-running counter.
    // 2^26 cycles at 100 MHz = 0.67 s on, 0.67 s off.
    //--------------------------------------------------------------------------
    reg [26:0] hb_count = 27'd0;

    always @(posedge clk)
        hb_count <= hb_count + 1'b1;

    assign led_heartbeat = hb_count[26];

endmodule