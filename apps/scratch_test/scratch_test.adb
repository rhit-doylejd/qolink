with Ada.Unchecked_Conversion;

with Interfaces;       
use Interfaces;

with Last_Chance;
pragma Unreferenced (Last_Chance);
with NEORV32.UART0;

with QOLink.Registers; 
use QOLink.Registers;

procedure Scratch_Test is

   package UART renames NEORV32.UART0;

   --  View a Scratch_Register as one 32-bit number, for printing.
   function To_U32 is
     new Ada.Unchecked_Conversion (Scratch_Register, Unsigned_32);

   type Pattern_List is array (Positive range <>) of Scratch_Register;

   Patterns : constant Pattern_List :=
     [(Byte_3 => 16#A5#, Byte_2 => 16#A5#, Byte_1 => 16#A5#, Byte_0 => 16#A5#),  --  A5A5A5A5
      (Byte_3 => 16#5A#, Byte_2 => 16#5A#, Byte_1 => 16#5A#, Byte_0 => 16#5A#),  --  5A5A5A5A
      (Byte_3 => 16#00#, Byte_2 => 16#00#, Byte_1 => 16#00#, Byte_0 => 16#00#),  --  00000000
      (Byte_3 => 16#FF#, Byte_2 => 16#FF#, Byte_1 => 16#FF#, Byte_0 => 16#FF#),  --  FFFFFFFF
      (Byte_3 => 16#12#, Byte_2 => 16#34#, Byte_1 => 16#56#, Byte_0 => 16#78#),  --  12345678
      (Byte_3 => 16#DE#, Byte_2 => 16#AD#, Byte_1 => 16#BE#, Byte_0 => 16#EF#)]; --  DEADBEEF

   Failures : Natural := 0;

   --  Read the register once, print what was expected and what came back,
   --  and count a failure if they differ.
   procedure Check (Expected : Scratch_Register) is
      Actual : constant Scratch_Register := Regs.Scratch;
   begin
      UART.Put ("  expect 0x");
      UART.Put_Hex (To_U32 (Expected));
      UART.Put ("  read 0x");
      UART.Put_Hex (To_U32 (Actual));
      if Actual = Expected then
         UART.Put_Line ("  OK");
      else
         UART.Put_Line ("  FAIL");
         Failures := Failures + 1;
      end if;
   end Check;

begin
   UART.Initialize (Baud => 115_200);
   UART.Put_Line ("QOLink scratch register test");

   --  Test 1: write the whole register, read it back.
   for P of Patterns loop
      Regs.Scratch := P;
      Check (P);
   end loop;

   --  Test 2: change one field. Volatile_Full_Access turns this into a
   --  32-bit read-modify-write, so the other three bytes must survive.
   Regs.Scratch := Patterns (1);
   Regs.Scratch.Byte_2 := 16#3C#;
   Check ((Byte_3 => 16#A5#, Byte_2 => 16#3C#, Byte_1 => 16#A5#, Byte_0 => 16#A5#));

   if Failures = 0 then
      UART.Put_Line ("PASS");
   else
      UART.Put_Line ("FAIL");
   end if;
end Scratch_Test;