package body Ship is
  Ship_Color : constant Color := Pink;
  Ship_Length : constant Integer := 12;

  Pos_Y : constant Integer := (Height'Last - Height'First) / 2;
  Pos_X : Integer := (Width'Last - Width'First) / 2;

  moved_right : Boolean := False;

  function get_color return Color is
  begin
    return Ship_Color;
  end get_color;

  function get_length return Integer is
  begin
    return Ship_Length;
  end get_length;

  function get_posy return Integer is
  begin
    return Pos_Y;
  end get_posy;

  function get_posx return Integer is
  begin
    return Pos_X;
  end get_posx;

  procedure move_left is
  begin
    moved_right := False;
    if Pos_X > 0 then
      Set_Pixel((Pos_X + Ship_Length, Pos_Y + 1), Black);
      Set_Pixel((Pos_X - 1, Pos_Y + 1), Ship_Color);
      Set_Pixel((Pos_X + Ship_Length, Pos_Y), Black);
      Set_Pixel((Pos_X - 1, Pos_Y), Ship_Color);
      Pos_X := Pos_X - 1;
    end if;
  end move_left;

  procedure move_right is
  begin
    moved_right := True;
    if Pos_X < (Width'Last - Width'First) - Ship_Length then
      Set_Pixel((Pos_X, Pos_Y + 1), Black);
      Set_Pixel((Pos_X + Ship_Length + 1, Pos_Y + 1), Ship_Color);
      Set_Pixel((Pos_X, Pos_Y), Black);
      Set_Pixel((Pos_X + Ship_Length + 1, Pos_Y), Ship_Color);
      Pos_X := Pos_X + 1;
    end if;
  end move_right;

  procedure on_star_collision is
  begin
    if moved_right then
      for I in 0..20 loop
        move_left;
      end loop;
    else
      for I in 0..20 loop
        move_right;
      end loop;
    end if;
  end on_star_collision;
end Ship;
