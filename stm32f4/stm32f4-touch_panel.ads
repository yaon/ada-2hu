with STM32F4.LCD;

package STM32F4.Touch_Panel is

   type TP_State is record
      Touch_Detected : Boolean;
      X : LCD.Width;
      Y : LCD.Height;
      Z : Half_Word;
   end record;

   procedure Initialize;
   function Get_State return TP_State;
end STM32F4.Touch_Panel;
