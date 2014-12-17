with screen_interface; use screen_Interface;

procedure Hello
is
   type Color_Array is array (Natural range <>) of Color;
   All_Colors : constant Color_Array :=
     (White, Blue, Green, Orange, Red, Yellow, Black, Gray,
      Pink, Light_Gray, Sky_Blue, Violet);
begin
  Screen_Interface.Initialize;

  Fill_Screen (Gray);

  declare
    Last_X : Width := (Width'Last - Width'First) / 2;
    Last_Y : Height := (Height'Last - Height'First) / 2;
    Mid : constant Integer := Last_Y;
    Ship_Length : constant Integer := 12;
    Pos : Integer := Last_X;
    State : Touch_State;
    Cur_Col : Color;
  begin
    -- Draw ship
    for I in Pos .. Pos + Ship_Length loop
      Set_Pixel((I, Mid + 1), Pink);
      Set_Pixel((I, Mid), Pink);
    end loop;

    loop
      loop
        State := Get_Touch_State;
        exit when State.Touch_Detected
          and then (State.X /= Last_X or State.Y /= Last_Y);
      end loop;

      -- Clear cross.
      for I in Width loop
        Set_Pixel ((I, Last_Y), Gray);
      end loop;
      for I in Height loop
        Set_Pixel ((Last_X, I), Gray);
      end loop;

      -- Draw cross.
      Last_Y := State.Y;
      Last_X := State.X;

      -- Check where is the finger, update the ship accrodingly
      if State.X < (Width'Last - Width'First) / 2 then
        if Pos > 0 then
          Set_Pixel((Pos + Ship_Length, Mid + 1), Gray);
          Set_Pixel((Pos - 1, Mid + 1), Pink);
          Set_Pixel((Pos + Ship_Length, Mid), Gray);
          Set_Pixel((Pos - 1, Mid), Pink);
          Pos := Pos - 1;
        end if;
        Cur_Col := Red;
      else
        if Pos < (Width'Last - Width'First) - Ship_Length then
          Set_Pixel((Pos, Mid + 1), Gray);
          Set_Pixel((Pos + Ship_Length + 1, Mid + 1), Pink);
          Set_Pixel((Pos, Mid), Gray);
          Set_Pixel((Pos + Ship_Length + 1, Mid), Pink);
          Pos := Pos + 1;
        end if;
        Cur_Col := Blue;
      end if;

      for I in Width loop
        Set_Pixel ((I, Last_Y), Cur_Col);
      end loop;
      for I in Height loop
        Set_Pixel ((Last_X, I), Cur_Col);
      end loop;
    end loop;
  end;
end hello;
