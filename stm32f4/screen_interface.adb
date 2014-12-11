with STM32F4.Touch_Panel;
with STM32F4; use STM32F4;
with STM32F4.LCD; use STM32F4.LCD;

package body Screen_Interface is
   procedure Initialize is
   begin
      STM32F4.LCD.Initialize;
      STM32F4.LCD.Set_Background (16#00#, 16#00#, 16#00#);
      STM32F4.Touch_Panel.Initialize;
   end;

   function Get_Touch_State return Touch_State is
      TS : Touch_State;
      ST_TS : STM32F4.Touch_Panel.TP_State;
   begin
     ST_TS := STM32F4.Touch_Panel.Get_State;

      TS.Touch_Detected := ST_TS.Touch_Detected;
      TS.X := ST_TS.X;
      TS.Y := ST_TS.Y;
      return TS;
   end;

   procedure Set_Pixel (P : Point; Col : Color) is
   begin
      STM32F4.LCD.Set_Pixel (STM32F4.LCD.Layer1, P.X, P.Y, Col);
   end;

   procedure Fill_Screen (Col : Color) is
      FB : constant Frame_Buffer_Access := Get_Frame_Buffer (Layer1);
   begin
      FB.all := (others => Col);
   end Fill_Screen;

   function RGB_To_Color (R, G, B : RGB_Value) return Color is
      RF : constant Float := (Float (R) / 255.0) * 31.0;
      GF : constant Float := (Float (G) / 255.0) * 31.0;
      BF : constant Float := (Float (B) / 255.0) * 31.0;
   begin
      return 16#8000# or
        (Color (RF) * (2**10)) or (Color (GF) * (2**5)) or Color (BF);
   end RGB_To_Color;

end Screen_Interface;
