with screen_interface; use screen_Interface;
with Ada.Real_Time; use Ada.Real_Time;
with Ship;

procedure Hello
is
  Bg_Color : constant Color := Black;

  Last_X : Width := (Width'Last - Width'First) / 2;
  Last_Y : Height := (Height'Last - Height'First) / 2;
  State : Touch_State;

  Stars_Color : constant Color := White;
  Queue_Size : constant Integer := 100;
  Stars : array(0 .. Queue_Size) of Point;
  Inc : Integer := 0;

  Period : constant Time_Span := Milliseconds(100);
  Target_Time : Time;

begin
  Screen_Interface.Initialize;
  Fill_Screen (Bg_Color);

  -- Draw ship
  for I in Ship.get_posx .. Ship.get_posx + Ship.get_length loop
    Set_Pixel((I, Ship.get_posy + 1), Ship.get_color);
    Set_Pixel((I, Ship.get_posy), Ship.get_color);
  end loop;

  -- Init the stars
  for I in Stars'First .. Stars'Last - 1 loop
    Stars(I).X := I * 7 mod (Width'Last - Width'First - 2);
    Stars(I).Y := (-I) * 2;
  end loop;

  loop
    Target_Time := Clock + Period;
    delay until Target_Time;
    State := Get_Touch_State;

    -- Update new state
    Last_Y := State.Y;
    Last_X := State.X;

    -- Check where is the finger, update the ship accordingly
    if State.Touch_Detected then
      if State.X < (Width'Last - Width'First) / 2 then
        Ship.move_left;
      else
        Ship.move_right;
      end if;
    end if;

    -- Update the stars
    for I in Stars'First .. Stars'Last - 1 loop
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
end hello;
