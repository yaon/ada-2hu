with screen_interface; use screen_Interface;

procedure Hello
is
   type Color_Array is array (Natural range <>) of Color;
   All_Colors : constant Color_Array :=
     (White, Blue, Green, Orange, Red, Yellow, Black, Gray,
      Pink, Light_Gray, Sky_Blue, Violet);
begin
   Screen_Interface.Initialize;

   --  Draw rectangles
   for I in 0 .. width'last / 2 loop
      declare
         C : constant Color := All_Colors ((I / 8) mod All_Colors'Length);
      begin
         for X in Width'First + I .. Width'Last - I loop
            Set_Pixel ((X, Height'First + I), C);
            Set_Pixel ((X, Height'Last - I), C);
         end loop;
         for Y in Height'First + I .. Height'Last - I loop
            Set_Pixel ((Width'First + I, Y), C);
            Set_Pixel ((Width'Last - I, Y), C);
         end loop;
      end;
   end loop;

   if True then
      loop
         null;
      end loop;
   else
      while not Get_Touch_State.Touch_Detected loop
         null;
      end loop;

      Fill_Screen (Gray);

      declare
         Last_X : Width := (Width'Last - Width'First) / 2;
         Last_Y : Height := (Height'Last - Height'First) / 2;
         State : Touch_State;
      begin
         loop
            loop
               State := Get_Touch_State;
               exit when State.Touch_Detected
                 and then (State.X /= Last_X or State.Y /= Last_Y);
            end loop;

            --  Clear cross.
            for I in Width loop
               Set_Pixel ((I, Last_Y), Gray);
            end loop;
            for I in Height loop
               Set_Pixel ((Last_X, I), Gray);
            end loop;

            --  Draw cross.
            Last_Y := State.Y;
            Last_X := State.X;

            for I in Width loop
              if State.X < (Width'Last - Width'First) / 2 then
                Set_Pixel ((I, Last_Y), Red);
              else
                Set_Pixel ((I, Last_Y), Blue);
              end if;
            end loop;
            for I in Height loop
              if State.X < (Width'Last - Width'First) / 2 then
                Set_Pixel ((Last_X, I), Red);
              else
                Set_Pixel ((Last_X, I), Blue);
              end if;
            end loop;
         end loop;
      end;
   end if;
end hello;
