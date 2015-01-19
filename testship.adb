with screen_interface; use screen_interface;
with Ship;

procedure TestShip is
  -- drawing positions
  Pos_X : Integer := 1;
  Pos_Y : constant Integer := 10;

  Ship_X : Integer;
  Shift : constant Integer := 1;

  procedure draw (c : Color) is
  begin
    Set_Pixel((Pos_X, Pos_Y), c);
    Set_Pixel((Pos_X + 1, Pos_Y), c);
    Set_Pixel((Pos_X, Pos_Y + 1), c);
    Set_Pixel((Pos_X + 1, Pos_Y + 1), c);
    Pos_X := Pos_X + 20;
  end draw;

  procedure ok is
  begin
    draw(Green);
  end ok;

  procedure ko is
  begin
    draw(Red);
  end ko;

begin
  Screen_Interface.Initialize;
  Fill_Screen(Black);

  -- 1.a) move_left
  Ship_X := Ship.get_posx;
  Ship.move_left;
  if Ship.get_posx = Ship_X - Shift then
    ok;
  else
    ko;
  end if;

  -- 1.b) move_right
  Ship_X := Ship.get_posx;
  Ship.move_right;
  if Ship.get_posx = Ship_X + Shift then
    ok;
  else
    ko;
  end if;

  -- set ship position to 0
  loop
    if Ship.get_posx = 0 then
      exit;
    end if;
    Ship.move_left;
  end loop;

  -- 2) check if x position stay in 0 after moving left
  Ship.move_left;
  if Ship.get_posx = 0 then
    ok;
  else
    ko;
  end if;
  
  -- set ship position to max width
  loop
    if Ship.get_posx = Width'Last - Ship.get_length then
      exit;
    end if;
    Ship.move_right;
  end loop;

  -- 2) check if x position stay in max width after moving right
  Ship.move_right;
  if Ship.get_posx = Width'Last - Ship.get_length then
    ok;
  else
    ko;
  end if;

  -- 4) ship moving left, check if go to right after colliding
  Ship.move_left;
  Ship_X := Ship.get_posx;
  Ship.on_star_collision;
  if Ship.get_posx > Ship_X then
    ok;
  else
    ko;
  end if;

  -- 4) ship moving right, check if go to left after colliding
  Ship.move_right;
  Ship_X := Ship.get_posx;
  Ship.on_star_collision;
  if Ship.get_posx < Ship_X then
    ok;
  else
    ko;
  end if;

  -- loop to avoid exiting
  loop
    null;
  end loop;

end TestShip;
