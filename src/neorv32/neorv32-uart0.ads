with Interfaces;

package NEORV32.UART0 is

   subtype Baud_Rate is Positive range 2_400 .. 1_000_000;

   procedure Initialize (Baud : Baud_Rate := 115_200);

   procedure Put (C: Character);
   procedure Put (S: String);
   procedure Put_Line (S: String);

   procedure Put_Hex (Value : Interfaces.Unsigned_32);

   end NEORV32.UART0;