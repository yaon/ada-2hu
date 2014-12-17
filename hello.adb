with screen_interface; use screen_Interface;

procedure Hello
is
begin
  Screen_Interface.Initialize;

  declare
    Bg_Color : constant Color := Black;

    Last_X : Width := (Width'Last - Width'First) / 2;
    Last_Y : Height := (Height'Last - Height'First) / 2;
    State : Touch_State;

    Mid : constant Integer := Last_Y;
    Ship_Color : constant Color := Pink;
    Ship_Length : constant Integer := 12;
    Pos : Integer := Last_X;

    Stars_Color : constant Color := White;
    Queue_Size : constant Integer := 100;
    Stars : array(0 .. Queue_Size) of Point;
    Inc : Integer := 0;
  begin
    Fill_Screen (Bg_Color);

    -- Draw ship
    for I in Pos .. Pos + Ship_Length loop
      Set_Pixel((I, Mid + 1), Ship_Color);
      Set_Pixel((I, Mid), Ship_Color);
    end loop;

    -- Init the stars
    for I in Stars'First .. Stars'Last loop
      Stars(I).X := I * 7 mod (Width'Last - Width'First - 2);
      Stars(I).Y := (-I) * 2;
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

      -- Update the stars
      for I in Stars'First .. Stars'Last loop
        Stars(I).Y := Stars(I).Y + 2;
        if Stars(I).Y >= 2 then
          -- clean the last star position
          Set_Pixel((Stars(I).x, Stars(I).y - 2), Stars_Color);
          Set_Pixel((Stars(I).x + 1, Stars(I).y - 2), Stars_Color);
          Set_Pixel((Stars(I).x, Stars(I).y + 1 - 2), Stars_Color);
          Set_Pixel((Stars(I).x + 1, Stars(I).y + 1 - 2), Stars_Color);

          -- Draw the star
          Set_Pixel((Stars(I).x, Stars(I).y), Stars_Color);
          Set_Pixel((Stars(I).x + 1, Stars(I).y), Stars_Color);
          Set_Pixel((Stars(I).x, Stars(I).y + 1), Stars_Color);
          Set_Pixel((Stars(I).x + 1, Stars(I).y + 1), Stars_Color);
        end if;
      end loop;
      Inc := Inc + 1;
    end loop;
  end;
end hello;
