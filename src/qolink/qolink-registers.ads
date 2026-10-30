with System;
with Interfaces;

package QOLink.Registers is

   use Interfaces;

   Base_Address : constant := 16#F000_0000#;

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

   type Register_Block is record
      Scratch : Scratch_Register;
   end record
      with Volatile;

   for Register_Block use record
      Scratch at 16#00# range 0 .. 31;
   end record;

   Regs : Register_Block
      with Import, Address => System'To_Address(Base_Address);

end QOLink.Registers;
