with screen_interface; use screen_Interface;

procedure Hello
is
   type Color_Array is array (Natural range <>) of Color;
   All_Colors : constant Color_Array :=
     (White, Blue, Green, Orange, Red, Yellow, Black, Gray,
      Pink, Light_Gray, Sky_Blue, Violet);
begin
  Screen_Interface.Initialize;

  declare
    Last_X : Width := (Width'Last - Width'First) / 2;
    Last_Y : Height := (Height'Last - Height'First) / 2;
    Mid : constant Integer := Last_Y;
    Ship_Length : constant Integer := 12;
    Pos : Integer := Last_X;
    State : Touch_State;
    Ship_Color : Color := Pink;
    Bg_Color : Color := Black;
  begin
    Fill_Screen (Bg_Color);

    -- Draw ship
    for I in Pos .. Pos + Ship_Length loop
      Set_Pixel((I, Mid + 1), Ship_Color);
      Set_Pixel((I, Mid), Ship_Color);
    end loop;

    loop
      loop
        State := Get_Touch_State;
        exit when State.Touch_Detected
          and then (State.X /= Last_X or State.Y /= Last_Y);
      end loop;

      -- Update new state
      Last_Y := State.Y;
      Last_X := State.X;

      -- Check where is the finger, update the ship accordingly
      if State.X < (Width'Last - Width'First) / 2 then
        if Pos > 0 then
          Set_Pixel((Pos + Ship_Length, Mid + 1), Bg_Color);
          Set_Pixel((Pos - 1, Mid + 1), Ship_Color);
          Set_Pixel((Pos + Ship_Length, Mid), Bg_Color);
          Set_Pixel((Pos - 1, Mid), Ship_Color);
          Pos := Pos - 1;
        end if;
      else
        if Pos < (Width'Last - Width'First) - Ship_Length then
          Set_Pixel((Pos, Mid + 1), Bg_Color);
          Set_Pixel((Pos + Ship_Length + 1, Mid + 1), Ship_Color);
          Set_Pixel((Pos, Mid), Bg_Color);
          Set_Pixel((Pos + Ship_Length + 1, Mid), Ship_Color);
          Pos := Pos + 1;
        end if;
      end if;
    end loop;
  end;
end hello;
