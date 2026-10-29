with System;
with Ada.Unchecked_Conversion;

package body NEORV32.UART0 is

   use Interfaces;

   type Prescaler_Select is
      (Div_2, Div_4, Div_8, Div_64, Div_128, Div_1024, Div_2048, Div_4096)
      with Size => 3;
   
   Prescaler_Value : constant array (Prescaler_Select) of Positive := 
      [Div_2 => 2,
       Div_4 => 4,
       Div_8 => 8,
       Div_64 => 64,
       Div_128 => 128,
       Div_1024 => 1024,
       Div_2048 => 2048,
       Div_4096 => 4096];

   type Baud_Divisor is mod 2 ** 10 with Size => 10;
   type UInt4 is mod 2 ** 4  with Size => 4;
   type UInt6 is mod 2 ** 6 with Size => 6;

   type Control_Register is record
      Enable : Boolean := False;
      Sim_Mode : Boolean := False;
      HW_Flow_Control : Boolean := False;
      Prescaler : Prescaler_Select := Div_2;
      Baud_Div : Baud_Divisor := 0;
      RX_Not_Empty : Boolean := False;
      RX_Full : Boolean := False;
      TX_Empty : Boolean := False;
      TX_Not_Full : Boolean := False;
      IRQ_RX_Not_Empty : Boolean := False;
      IRQ_RX_FULL : Boolean := False;
      IRQ_TX_Empty : Boolean := False;
      IRQ_TX_Not_Full : Boolean := False;
      Reserved : UInt6 := 0;
      RX_Overrun : Boolean := False;
      TX_Busy : Boolean := False;
   end record
      with Size => 32,
         Bit_Order => System.Low_Order_First,
         Volatile_Full_Access;
   
   for Control_Register use record
      Enable           at 0 range  0 ..  0;
      Sim_Mode         at 0 range  1 ..  1;
      HW_Flow_Control  at 0 range  2 ..  2;
      Prescaler        at 0 range  3 ..  5;
      Baud_Div         at 0 range  6 .. 15;
      RX_Not_Empty     at 0 range 16 .. 16;
      RX_Full          at 0 range 17 .. 17;
      TX_Empty         at 0 range 18 .. 18;
      TX_Not_Full      at 0 range 19 .. 19;
      IRQ_RX_Not_Empty at 0 range 20 .. 20;
      IRQ_RX_Full      at 0 range 21 .. 21;
      IRQ_TX_Empty     at 0 range 22 .. 22;
      IRQ_TX_Not_Full  at 0 range 23 .. 23;
      Reserved         at 0 range 24 .. 29;
      RX_Overrun       at 0 range 30 .. 30;
      TX_Busy          at 0 range 31 .. 31;
   end record;

   type Data_Register is record
      RTX          : Unsigned_8  := 0;
      RX_FIFO_Log2 : UInt4       := 0;
      TX_FIFO_Log2 : UInt4       := 0;
      Reserved     : Unsigned_16 := 0;
   end record
     with Size      => 32,
          Bit_Order => System.Low_Order_First,
          Volatile_Full_Access;

   for Data_Register use record
      RTX          at 0 range  0 ..  7;
      RX_FIFO_Log2 at 0 range  8 .. 11;
      TX_FIFO_Log2 at 0 range 12 .. 15;
      Reserved     at 0 range 16 .. 31;
   end record;

   UART0_Base : constant := 16#FFF5_0000#;

   type UART_Registers is record
      CTRL : Control_Register;
      DATA : Data_Register;
   end record
     with Volatile;

   for UART_Registers use record
      CTRL at 16#0# range 0 .. 31;
      DATA at 16#4# range 0 .. 31;
   end record;

   Regs : UART_Registers
     with Import, Address => System'To_Address (UART0_Base);


   procedure Initialize (Baud : Baud_Rate := 115_200) is Divisor : Natural;
   begin
      Regs.CTRL := (others => <>);

      for P in Prescaler_Select loop
         Divisor := Clock_Hz / Prescaler_Value (P) / Baud;
         if Divisor in 1 .. 1024 then
            Regs.CTRL := 
               (Enable           => True,
                Sim_Mode         => Simulation_Build,
                Prescaler        => P,
                Baud_Div         => Baud_Divisor (Divisor - 1),
                others => <>);
            exit;
         end if;
      end loop;
   end Initialize;

   procedure Put (C: Character) is
   begin
      while not Regs.CTRL.TX_Not_Full loop
         null;
      end loop;
      Regs.DATA := (RTX => Character'Pos (C), others => <>);
   end Put;

   procedure Put (S : String) is
   begin 
      for C of S loop
         Put (C);
      end loop;
   end Put;

   procedure Put_Line (s : String) is
   begin
      Put (S);
      Put (ASCII.CR);
      Put (ASCII.LF);
   end Put_Line;

   type Nibble is mod 2 ** 4 with Size => 4;
   type Nibbles is array (0 .. 7) of Nibble
      with Pack, Size => 32;

   function To_Nibbles is
      new Ada.Unchecked_Conversion (Unsigned_32, Nibbles);

   Hex_Digit : constant array (Nibble) of Character := "0123456789ABCDEF";

   procedure Put_Hex (Value : Unsigned_32) is
      N : constant Nibbles := To_Nibbles (Value);
   begin
      for I in reverse N'Range loop
         Put (Hex_Digit (N (I)));
      end loop;
   end Put_Hex;

end NEORV32.UART0;