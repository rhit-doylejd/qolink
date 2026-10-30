with System;

package Last_Chance is

   procedure Handler (Source_Location : System.Address; Line : Integer)
      with No_Return,
         Export,
         Convention => C,
         External_Name => "__gnat_last_chance_handler";

end Last_Chance;