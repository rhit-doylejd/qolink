-- ================================================================================
-- Company: Rose-Hulman Institute of Technology QOLink Team
-- Engineer: Joshua Doyle
--
-- Create Date: 10/30/2026
-- Design Name: QOLink CPU
-- Module Name: qolink_cpu
-- Project Name: QOLink
-- Target Devices: Nexys A7-100T (XC7A100T)
-- Tool Versions: Vivado 2024.2, NEORV32 v1.13.6
-- Description: NEORV32 processor configured for the QOLink Ada driver.
--              All processor settings live here, so the Verilog top level
--              only sees plain ports. Based on rtl/test_setups/
--              neorv32_test_setup_approm.vhd (boot from pre-initialized IMEM).
--
--              Settings must match the Ada side:
--                CLOCK_FREQUENCY  -> Clock_Hz in src/neorv32/neorv32.ads
--                IMEM/DMEM sizes  -> MEMORY in src/neorv32/neorv32.ld
--                RISCV_ISA_M/C    -> runtime light-rv32im (-march=rv32im)
--
-- Dependencies: NEORV32 core (library neorv32), neorv32_imem_image package
--               generated from the Ada program by image_gen
--
-- Revision:
-- Revision 0.01 - File Created
-- ================================================================================

library ieee;
use ieee.std_logic_1164.all;

library neorv32;

entity qolink_cpu is
  port (
    -- Global control --
    clk_i       : in  std_ulogic;                      -- 100 MHz clock
    rstn_i      : in  std_ulogic;                      -- reset, low-active, async

    -- UART0 --
    uart0_txd_o : out std_ulogic;                      -- serial data to the PC
    uart0_rxd_i : in  std_ulogic;                      -- serial data from the PC

    -- XBUS (Wishbone) to the QOLink register block --
    xbus_adr_o  : out std_ulogic_vector(31 downto 0);  -- address
    xbus_dat_o  : out std_ulogic_vector(31 downto 0);  -- write data
    xbus_we_o   : out std_ulogic;                      -- 1 = write
    xbus_sel_o  : out std_ulogic_vector(3 downto 0);   -- byte enables
    xbus_stb_o  : out std_ulogic;                      -- request strobe
    xbus_cyc_o  : out std_ulogic;                      -- cycle in progress
    xbus_dat_i  : in  std_ulogic_vector(31 downto 0);  -- read data
    xbus_ack_i  : in  std_ulogic;                      -- transfer done
    xbus_err_i  : in  std_ulogic                       -- transfer error
  );
end entity;

architecture rtl of qolink_cpu is
begin

  neorv32_inst : entity neorv32.neorv32_top
    generic map (
      -- Clocking --
      CLOCK_FREQUENCY  => 100_000_000,  -- Hz, = Clock_Hz in neorv32.ads
      -- Boot: run the program pre-loaded into IMEM --
      BOOT_MODE_SELECT => 2,
      -- CPU: rv32im --
      RISCV_ISA_C      => false,
      RISCV_ISA_M      => true,
      -- Instruction memory: 16 KB at 0x00000000 --
      IMEM_EN          => true,
      IMEM_SIZE        => 16*1024,
      -- Data memory: 8 KB at 0x80000000 --
      DMEM_EN          => true,
      DMEM_SIZE        => 8*1024,
      -- External bus to QOLink --
      XBUS_EN          => true,
      XBUS_TIMEOUT     => 2048,
      -- UART0 for text output --
      IO_UART0_EN      => true
    )
    port map (
      -- Global control --
      clk_i       => clk_i,
      rstn_i      => rstn_i,
      -- XBUS (xbus_cti_o and xbus_tag_o are not needed) --
      xbus_adr_o  => xbus_adr_o,
      xbus_dat_o  => xbus_dat_o,
      xbus_we_o   => xbus_we_o,
      xbus_sel_o  => xbus_sel_o,
      xbus_stb_o  => xbus_stb_o,
      xbus_cyc_o  => xbus_cyc_o,
      xbus_dat_i  => xbus_dat_i,
      xbus_ack_i  => xbus_ack_i,
      xbus_err_i  => xbus_err_i,
      -- UART0 --
      uart0_txd_o => uart0_txd_o,
      uart0_rxd_i => uart0_rxd_i
    );

end architecture;