with Ada.Unchecked_Conversion;

with Interfaces;
use Interfaces;

with Last_Chance;
pragma Unreferenced (Last_Chance);
with NEORV32.UART0;

with QOLink.Registers;
use QOLink.Registers;

--  Tests the TX FIFO -> loopback -> RX FIFO path through the QOLink
--  registers. Same sequence as Tests 4-8 in qolink_regs_tb.v, except the
--  bus-error cases: on the board a bus error traps the CPU, so this test
--  checks status before every data access and never causes one.
--
--  Run it straight after an FPGA reset: the FIFOs only clear on reset.
--  The test drains both FIFOs at the end so it can be rerun.

procedure Loopback_Test is

   package UART renames NEORV32.UART0;

   --  View status registers as one 32-bit number, for printing and comparing.
   function To_U32 is
     new Ada.Unchecked_Conversion (FIFO_Status_Register, Unsigned_32);
   function To_U32 is
     new Ada.Unchecked_Conversion (Loopback_Control_Register, Unsigned_32);

   --  FIFO status values: bit 0 = empty, bit 1 = full
   ST_Empty : constant Unsigned_32 := 16#1#;
   ST_Data  : constant Unsigned_32 := 16#0#;   --  neither empty nor full
   ST_Full  : constant Unsigned_32 := 16#2#;

   --  Loopback status values: bit 8 = busy, bits 7..0 = bytes remaining
   LB_Idle  : constant Unsigned_32 := 16#000#;

   --  Upper bound on polling loops, so a hardware bug shows up as FAIL
   --  instead of a hang.
   Max_Polls : constant := 10_000;

   Failures : Natural := 0;

   ---------------------------------------------------------------------------
   --  Reporting
   ---------------------------------------------------------------------------
   procedure Check (What : String; Actual, Expected : Unsigned_32) is
   begin
      UART.Put ("  " & What & ": expect 0x");
      UART.Put_Hex (Expected);
      UART.Put ("  read 0x");
      UART.Put_Hex (Actual);
      if Actual = Expected then
         UART.Put_Line ("  OK");
      else
         UART.Put_Line ("  FAIL");
         Failures := Failures + 1;
      end if;
   end Check;

   procedure Fail (What : String) is
   begin
      UART.Put_Line ("  " & What & "  FAIL");
      Failures := Failures + 1;
   end Fail;

   ---------------------------------------------------------------------------
   --  Register reads (each is a single 32-bit load)
   ---------------------------------------------------------------------------
   function TX_Status return Unsigned_32 is (To_U32 (Regs.TX_Status));
   function RX_Status return Unsigned_32 is (To_U32 (Regs.RX_Status));
   function LB_Status return Unsigned_32 is (To_U32 (Regs.Loopback_Ctrl));

   ---------------------------------------------------------------------------
   --  FIFO access: check status first so a bug can never cause a bus error
   ---------------------------------------------------------------------------
   procedure Push (B : Unsigned_8) is
   begin
      if Regs.TX_Status.Full then
         Fail ("push: TX full");
      else
         Regs.TX_Data := (Data => B, others => <>);   --  whole record: one store
      end if;
   end Push;

   procedure Pop_Check (Expected : Unsigned_8) is
   begin
      if Regs.RX_Status.Empty then
         Fail ("pop: RX empty");
      else
         declare
            R : constant FIFO_Data_Register := Regs.RX_Data;  --  one read = one pop
         begin
            Check ("RX byte", Unsigned_32 (R.Data), Unsigned_32 (Expected));
         end;
      end if;
   end Pop_Check;

   ---------------------------------------------------------------------------
   --  Loopback control
   ---------------------------------------------------------------------------
   procedure Start_Loopback (N : Unsigned_8) is   --  N = 0 cancels
   begin
      Regs.Loopback_Ctrl := (Count => N, others => <>);   --  whole record
   end Start_Loopback;

   procedure Wait_Idle is
   begin
      for Poll in 1 .. Max_Polls loop
         if not Regs.Loopback_Ctrl.Busy then
            return;
         end if;
      end loop;
      Fail ("loopback still busy");
   end Wait_Idle;

   procedure Wait_Remaining (N : Unsigned_8) is
   begin
      for Poll in 1 .. Max_Polls loop
         if Regs.Loopback_Ctrl.Count = N then
            return;
         end if;
      end loop;
      Fail ("loopback count never reached expected value");
   end Wait_Remaining;

   --  Give the hardware time to (wrongly) move a byte, so a stall test
   --  can tell "stalled" from "hasn't started yet". Each read is a bus
   --  transfer of several clocks; 100 reads is far more than the 3 clocks
   --  the loopback needs per byte.
   procedure Settle is
   begin
      for I in 1 .. 100 loop
         if Regs.Loopback_Ctrl.Busy then
            null;
         end if;
      end loop;
   end Settle;

begin
   UART.Initialize (Baud => 115_200);
   UART.Put_Line ("QOLink FIFO / loopback test");

   UART.Put_Line ("Test 1: state after reset");
   Check ("TX status", TX_Status, ST_Empty);
   Check ("RX status", RX_Status, ST_Empty);
   Check ("loopback ", LB_Status, LB_Idle);

   UART.Put_Line ("Test 2: TX FIFO fills to 16");
   Push (16#A0#);
   Check ("TX status", TX_Status, ST_Data);
   for I in Unsigned_8 range 1 .. 15 loop
      Push (16#A0# + I);                             --  A1..AF
   end loop;
   Check ("TX status", TX_Status, ST_Full);

   UART.Put_Line ("Test 3: loopback moves all 16 bytes, in order");
   Start_Loopback (16);
   Wait_Idle;
   Check ("loopback ", LB_Status, LB_Idle);
   Check ("TX status", TX_Status, ST_Empty);
   Check ("RX status", RX_Status, ST_Full);
   for I in Unsigned_8 range 0 .. 15 loop
      Pop_Check (16#A0# + I);                        --  A0..AF
   end loop;
   Check ("RX status", RX_Status, ST_Empty);

   UART.Put_Line ("Test 4: loopback moves exactly the requested count");
   for I in Unsigned_8 range 0 .. 4 loop
      Push (16#B0# + I);                             --  B0..B4
   end loop;
   Start_Loopback (3);
   Wait_Idle;
   Pop_Check (16#B0#);
   Pop_Check (16#B1#);
   Pop_Check (16#B2#);
   Check ("RX status", RX_Status, ST_Empty);          --  exactly 3 moved
   Check ("TX status", TX_Status, ST_Data);           --  B3, B4 still in TX

   UART.Put_Line ("Test 5: loopback pauses when TX runs dry");
   Start_Loopback (4);                                --  only B3, B4 available
   Wait_Remaining (2);
   Settle;
   Check ("loopback ", LB_Status, 16#102#);           --  busy, 2 remaining
   Push (16#C0#);
   Push (16#C1#);
   Wait_Idle;
   Pop_Check (16#B3#);
   Pop_Check (16#B4#);
   Pop_Check (16#C0#);
   Pop_Check (16#C1#);
   Check ("RX status", RX_Status, ST_Empty);

   UART.Put_Line ("Test 6: loopback pauses when RX is full; 0 cancels");
   for I in Unsigned_8 range 0 .. 15 loop
      Push (16#D0# + I);                             --  D0..DF
   end loop;
   Start_Loopback (16);
   Wait_Idle;
   Check ("RX status", RX_Status, ST_Full);
   Push (16#E0#);
   Start_Loopback (1);                                --  RX full: must stall
   Settle;
   Check ("loopback ", LB_Status, 16#101#);           --  busy, nothing popped
   Check ("TX status", TX_Status, ST_Data);           --  E0 still in TX
   Start_Loopback (0);                                --  cancel
   Check ("loopback ", LB_Status, LB_Idle);
   for I in Unsigned_8 range 0 .. 15 loop
      Pop_Check (16#D0# + I);                        --  D0..DF, nothing lost
   end loop;
   Settle;                                            --  RX has room now...
   Check ("RX status", RX_Status, ST_Empty);          --  ...but cancelled: E0 not moved

   UART.Put_Line ("Cleanup: move E0 through so both FIFOs end empty");
   Start_Loopback (1);
   Wait_Idle;
   Pop_Check (16#E0#);
   Check ("TX status", TX_Status, ST_Empty);
   Check ("RX status", RX_Status, ST_Empty);

   if Failures = 0 then
      UART.Put_Line ("PASS");
   else
      UART.Put_Line ("FAIL");
   end if;
end Loopback_Test;