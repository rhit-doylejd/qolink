with System;
with Interfaces;

package QOLink.Registers is

   use Interfaces;

   Base_Address : constant := 16#F000_0000#;

   type UInt23 is mod 2 ** 23 with Size => 23;
   type UInt24 is mod 2 ** 24 with Size => 24;
   type UInt30 is mod 2 ** 30 with Size => 30;


   type Scratch_Register is record
      Byte_0 : Unsigned_8 := 0; 
      Byte_1 : Unsigned_8 := 0; 
      Byte_2 : Unsigned_8 := 0; 
      Byte_3 : Unsigned_8 := 0; 
   end record
      with Size => 32,
         Bit_Order => System.Low_Order_First, 
         Volatile_Full_Access;
      
   for Scratch_Register use record
      Byte_0 at 0 range 0 .. 7;
      Byte_1 at 0 range 8 .. 15;
      Byte_2 at 0 range 16 .. 23;
      Byte_3 at 0 range 24 .. 31;
   end record;

   type FIFO_Data_Register is record
      Data     : Unsigned_8 := 0;
      Reserved : UInt24     := 0;
   end record
      with Size => 32,
         Bit_Order => System.Low_Order_First,
         Volatile_Full_Access;
 
   for FIFO_Data_Register use record
      Data     at 0 range 0 .. 7;
      Reserved at 0 range 8 .. 31;
   end record;

   type FIFO_Status_Register is record
      Empty    : Boolean := False;
      Full     : Boolean := False;
      Reserved : UInt30  := 0;
   end record
      with Size => 32,
         Bit_Order => System.Low_Order_First,
         Volatile_Full_Access;
 
   for FIFO_Status_Register use record
      Empty    at 0 range 0 .. 0;
      Full     at 0 range 1 .. 1;
      Reserved at 0 range 2 .. 31;
   end record;

      type Loopback_Control_Register is record
      Count    : Unsigned_8 := 0;
      Busy     : Boolean    := False;
      Reserved : UInt23     := 0;
   end record
      with Size => 32,
         Bit_Order => System.Low_Order_First,
         Volatile_Full_Access;
 
   for Loopback_Control_Register use record
      Count    at 0 range 0 .. 7;
      Busy     at 0 range 8 .. 8;
      Reserved at 0 range 9 .. 31;
   end record;

   type Register_Block is record
      Scratch        : Scratch_Register;
      TX_Data        : FIFO_Data_Register;
      TX_Status      : FIFO_Status_Register;
      RX_Data        : FIFO_Data_Register;
      RX_Status      : FIFO_Status_Register;
      Loopback_Ctrl  : Loopback_Control_Register;
   end record
      with Volatile;

   for Register_Block use record
      Scratch       at 16#00# range 0 .. 31;
      TX_Data       at 16#04# range 0 .. 31;
      TX_Status     at 16#08# range 0 .. 31;
      RX_Data       at 16#0C# range 0 .. 31;
      RX_Status     at 16#10# range 0 .. 31;
      Loopback_Ctrl at 16#14# range 0 .. 31;
   end record;

   Regs : Register_Block
      with Import, Address => System'To_Address(Base_Address);

end QOLink.Registers;
