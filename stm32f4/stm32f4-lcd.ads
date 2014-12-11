package STM32F4.LCD is

   LCD_PIXEL_WIDTH  : constant := 240;
   LCD_PIXEL_HEIGHT : constant := 320;

   type LCD_Layer is (Layer1, Layer2);

   subtype Width is Natural range 0 .. (LCD_PIXEL_WIDTH - 1);
   subtype Height is Natural range 0 .. (LCD_PIXEL_HEIGHT - 1);

   subtype Pixel is Half_Word;

   Black      : constant Pixel := 16#8000#;
   White      : constant Pixel := 16#FFFF#;
   Red        : constant Pixel := 2**15 or (31 * (2**10));
   Green      : constant Pixel := 2**15 or (31 * (2**5));
   Blue       : constant Pixel := 2**15 or 31;
   Gray       : constant Pixel := 2**15 or 23 * (2**10) or 23 * (2**5) or 23;
   Light_Gray : constant Pixel := 2**15 or 30 * (2**10) or 30 * (2**5) or 30;
   Sky_Blue   : constant Pixel := 2**15 or 19 * (2**17) or 26 * (2**5) or 31;
   Yellow     : constant Pixel := 2**15 or 31 * (2**10) or 31 * (2**5);
   Orange     : constant Pixel := 2**15 or 31 * (2**10) or 21 * (2**5);
   Pink       : constant Pixel := 2**15 or 31 * (2**10) or 13 * (2**5) or 23;
   Violet     : constant Pixel := 2**15 or 19 * (2**10) or 6 * (2**5) or 26;

   type Frame_Buffer_Range is range
     0 .. (LCD_PIXEL_HEIGHT * LCD_PIXEL_WIDTH) - 1;

   type Frame_Buffer is array (Frame_Buffer_Range) of Pixel
     with Pack, Volatile;

   type Frame_Buffer_Access is not null access all Frame_Buffer;

   --  Pixel_Fmt_ARGB8888 : constant := 2#000#;
   --  Pixel_Fmt_RGB888   : constant := 2#001#;
   Pixel_Fmt_RGB565   : constant := 2#010#;
   Pixel_Fmt_ARGB1555 : constant := 2#011#;
   Pixel_Fmt_ARGB4444 : constant := 2#100#;
   --  Pixel_Fmt_L8       : constant := 2#101#;
   --  Pixel_Fmt_AL44     : constant := 2#110#;
   --  Pixel_Fmt_AL88     : constant := 2#111#;

   BF1_Constant_Alpha : constant := 2#100#;
   BF1_Pixel_Alpha    : constant := 2#110#;
   BF2_Constant_Alpha : constant := 2#101#;
   BF2_Pixel_Alpha    : constant := 2#111#;

   Default_Pixel_Fmt  : constant := Pixel_Fmt_ARGB1555;

   type Layer_State is (Enabled, Disabled);

   procedure Initialize;
   procedure Init_Layer (Layer             : LCD_Layer;
                         Pixel_Fmt         : Word;
                         Blending_Factor_1 : Bits_3;
                         Blending_Factor_2 : Bits_3);

   procedure Set_Background (R, G, B : Byte);
   procedure Set_Layer_State (Layer : LCD_Layer; State : Layer_State);
   function Get_Frame_Buffer (Layer : LCD_Layer) return Frame_Buffer_Access;
   procedure Set_Pixel (Layer : LCD_Layer; X : Width; Y : Height; Pix : Pixel);
   function Get_Pixel (Layer : LCD_Layer; X : Width; Y : Height) return Pixel;
end STM32F4.LCD;
