## ============================================================================
## QOLink - Nexys A7-100T pin and timing constraints
## Board : Digilent Nexys A7-100T (FPGA XC7A100T-1CSG324C)
## Top   : hw/rtl/qolink_top.v
## Pins checked against Digilent's Nexys-A7-100T-Master.xdc
## ============================================================================

## ---- Clock: 100 MHz oscillator ---------------------------------------------
set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33 } [get_ports { clk }]
create_clock -name sys_clk -period 10.000 -waveform {0.000 5.000} [get_ports { clk }]

## ---- Reset: CPU RESET button (low while pressed) ---------------------------
set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports { cpu_resetn }]

## ---- USB-UART (named from the FPGA's side) ---------------------------------
## Digilent name UART_TXD_IN  (PC transmits, FPGA receives)
set_property -dict { PACKAGE_PIN C4  IOSTANDARD LVCMOS33 } [get_ports { uart_rxd }]
## Digilent name UART_RXD_OUT (FPGA transmits, PC receives)
set_property -dict { PACKAGE_PIN D4  IOSTANDARD LVCMOS33 } [get_ports { uart_txd }]

## ---- LED 0: heartbeat --------------------------------------------------------
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports { led_heartbeat }]

## ---- Configuration bank voltage ------------------------------------------------
set_property CFGBVS VCCO        [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]