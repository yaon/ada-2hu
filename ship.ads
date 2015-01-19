with screen_interface; use screen_Interface;

package Ship is
  function get_color return Color;
  function get_length return Integer;
  function get_posy return Integer;
  function get_posx return Integer;
  procedure move_left;
  procedure move_right;
  procedure on_star_collision;
end Ship;
