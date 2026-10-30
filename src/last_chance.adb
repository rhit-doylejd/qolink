package body Last_Chance is

   procedure Handler (Source_Location : System.Address; Line : Integer) is
      pragma Unreferenced (Source_Location, Line);
   begin
      loop
         null;
      end loop;
   end Handler;

end Last_Chance;