with System;
with Ada.Unchecked_Conversion;
with Ada.Real_Time; use Ada.Real_Time;

with STM32F4;                     use STM32F4;
with STM32F4.GPIO;                use STM32F4.GPIO;
with STM32F4.SPI;                 use STM32F4.SPI;
with STM32F4.SDRAM;               use STM32F4.SDRAM;
with STM32F4.Reset_Clock_Control; use STM32F4.Reset_Clock_Control;

pragma Warnings (Off);
with System.BB.Parameters; use System.BB.Parameters;
pragma Warnings (On);

with STM32F429_Discovery;  use STM32F429_Discovery;

package body STM32F4.LCD is

   --  LCD configuration:
   --  IM[0:3] = 0110 -> 4-write 8-bit seria I, SDA: In/Out
   --                    SCL (clock, rising edge), SDA (data, D7 -> D0),
   --                    D/CX (data/command on D0), CSX (chip select)
   --  SCL: PF7
   --  SDA: PF9
   --  DCX: PD13
   --  CSX: PC2
   --
   --  PD12: RDX
   --  PD11: TE
   --
   --  PA4:  VSYNC
   --  PC6:  HSYNC
   --  PF10: ENABLE
   --  PG7:  DOTCLOCK
   --
   --  R2-R7: PC10, PB0,  PA11, PA12, PB1,  PG6
   --  G2-G7: PA6,  PG10, PB10, PB11, PC7,  PD3
   --  B2-B7: PD6,  PG11, PG12, PA3,  PB8,  PB9

   --  RGB interface
   --  RCM=10, RIM-0, DPI=101: DE mode, 16-bit RGB interface

   --  Screen parameters:
   HSYNCW : constant := 10;  --  HSYNC width (in pixels)
   HBP    : constant := 20;  --  Horizontal back porch (in pixels)
   HFP    : constant := 10;  --  Horizontal front porch (in pixels)
   VSYNCH : constant := 2;   --  VSYNC height (in lines)
   VBP    : constant := 2;   --  Vertical back porch (in lines)
   VFP    : constant := 4;   --  Vertical front porch (in lines)

   function As_Word is new Ada.Unchecked_Conversion
     (Source => System.Address, Target => Word);

   NCS_GPIO : GPIO_Port renames GPIO_C;  --  NCS == CXS (chip select)
   WRX_GPIO : GPIO_Port renames GPIO_D;  --  WRX == DCX (Data/Command)

   NCS_Pin  : GPIO_Pin renames Pin_2;
   WRX_Pin  : GPIO_Pin renames Pin_13;

   SCK_GPIO  : GPIO_Port renames GPIO_F;
   MISO_GPIO : GPIO_Port renames GPIO_F;
   MOSI_GPIO : GPIO_Port renames GPIO_F;

   SCK_Pin   : GPIO_Pin renames Pin_7;
   MISO_Pin  : GPIO_Pin renames Pin_8;
   MOSI_Pin  : GPIO_Pin renames Pin_9;

   SCK_AF  : GPIO_Alternate_Function renames GPIO_AF_SPI5;
   MISO_AF : GPIO_Alternate_Function renames GPIO_AF_SPI5;
   MOSI_AF : GPIO_Alternate_Function renames GPIO_AF_SPI5;

   LCD_SPI : SPI_Port renames SPI_5;

   --  Layer Control Register
   type LC_Registers is record
      Len        : Bits_1; --  Layer Enable
      Colken     : Bits_1; --  Color Keying Enable
      Reserved_1 : Bits_2;
      Cluten     : Bits_1; --  Color Look-Up Table Enable
      Reserved_2 : Bits_27;
   end record with Pack, Volatile, Size => 32;

   --  Layerx Window Horizontal Position Configuration Register
   type LWHPC_Registers is record
      Horizontal_Start : Bits_12; --  Window Horizontal Start Position
      Reserved_1       : Bits_4;
      Horizontal_Stop  : Bits_12; --  Window Horizontal Stop Position
      Reserved_2       : Bits_4;
   end record with Pack, Volatile, Size => 32;

   --  Layerx Window Vertical Position Configuration Register
   type LWVPC_Registers is record
      Vertical_Start : Bits_11; --  Window Vertical Start Position
      Reserved_1     : Bits_5;
      Vertical_Stop  : Bits_11; --  Window Vertical Stop Position
      Reserved_2     : Bits_5;
   end record with Pack, Volatile, Size => 32;

   --  Layerx Color Keying Configuration Register
   type LCKC_Registers is record
      CKBlue     : Byte;
      CKGreen    : Byte;
      CKRed      : Byte;
      Reserved_1 : Byte;
   end record with Pack, Volatile, Size => 32;

   --  Layerx Pixel Format Configuration Register
   subtype LPFC_Register is Word;

   --  Layer Constant Alpha Configuration Register
   type LCAC_Registers is record
      CONSTA   : Byte;
      Reserved : Bits_24;
   end record with Pack, Volatile, Size => 32;

   --  Layer Default Color Configuration Register
   type LDCC_Registers is record
      DCBlue  : Byte;
      DCGreen : Byte;
      DCRed   : Byte;
      DCAlpha : Byte;
   end record with Pack, Volatile, Size => 32;

   --  Layer Blending Factors Configuration Register
   type LBFC_Registers is record
      BF2        : Bits_3; --  Blending Factor 2
      Reserved_1 : Bits_5;
      BF1        : Bits_3; --  Blending Factor 1
      Reserved_2 : Bits_21;
   end record with Pack, Volatile, Size => 32;

   --  Layer Color Frame Buffer Length Register
   type LCFBL_Registers is record
      CFBLL      : Bits_13; --  Color Frame Buffer Line Length
      Reserved_1 : Bits_3;
      CFBP       : Bits_13; --  Color Frame Pitch in bytes
      Reserved_2 : Bits_3;
   end record with Pack, Volatile, Size => 32;

   --  Layer Color Frame Buffer Line Number Register
   type LCFBLN_Registers is record
      CFBLNBR  : Bits_11; --  Frame Buffer Line Number
      Reserved : Bits_21;
   end record with Pack, Volatile, Size => 32;

   --  Layer CLUT Write Register
   type LCLUTW_Registers is record
      Blue    : Byte;
      Green   : Byte;
      Red     : Byte;
      CLUTADD : Byte;
   end record with Pack, Volatile, Size => 32;

   type Layer is record
      Ctrl       : LC_Registers;
      WHPC       : LWHPC_Registers;
      WVPC       : LWVPC_Registers;
      CKC        : LCKC_Registers;
      PFC        : LPFC_Register;
      CAC        : LCAC_Registers;
      DCC        : LDCC_Registers;
      BFC        : LBFC_Registers;
      Reserved_1 : Word;
      Reserved_2 : Word;
      --  Layer Color Frame Buffer Address Register
      CFBA       : Word with Volatile;
      CFBL       : LCFBL_Registers;
      CFBLN      : LCFBLN_Registers;
      Reserved_3 : Word;
      Reserved_4 : Word;
      Reserved_5 : Word;
      CLUTW      : LCLUTW_Registers;
   end record with Pack, Volatile, Size => 17 * 32;

   --  Synchronization Size Configuration Register
   type SSC_Registers is record
      VSH        : Bits_11; --  Vertical Synchronization Height
      Reserved_1 : Bits_5;
      HSW        : Bits_12; --  Horizontal Synchronization Width
      Reserved_2 : Bits_4;
   end record with Pack, Volatile, Size => 32;

   --  Back Porch Configuration Register
   type BPC_Registers is record
      AVBP       : Bits_11; --  Accumulated Vertical back porch
      Reserved_1 : Bits_5;
      AHBP       : Bits_12; --  Accumulated Horizontal back porch
      Reserved_2 : Bits_4;
   end record with Pack, Volatile, Size => 32;

   --  Active Width Configuration Register
   type AWC_Registers is record
      AAH        : Bits_11; --  Accumulated Active Height
      Reserved_1 : Bits_5;
      AAW        : Bits_12; --  Accumulated Active Width
      Reserved_2 : Bits_4;
   end record with Pack, Volatile, Size => 32;

   --  Total Width Configuration Register
   type TWC_Registers is record
      TOTALH     : Bits_11; --  Total Height
      Reserved_1 : Bits_5;
      TOTALW     : Bits_12; --  Total Width
      Reserved_2 : Bits_4;
   end record with Pack, Volatile, Size => 32;

   --  Global Control Register
   type GC_Registers is record
      LTDCEN     : Bits_1; --  Controller Enable
      Reserved_1 : Bits_3;
      DBW        : Bits_3; --  Dither Blue Width
      Reserved_2 : Bits_1;
      DGW        : Bits_3; --  Dither Green Width
      Reserved_3 : Bits_1;
      DRW        : Bits_3; --  Dither Red Width
      Reserved_4 : Bits_1;
      DEN        : Bits_1; --  Dither Enable
      Reserved_5 : Bits_11;
      PCPOL      : Bits_1; --  Pixel Clock Polarity
      DEPOL      : Bits_1; --  Data Enable Polarity
      VSPOL      : Bits_1; --  Vertical Synchronization Polarity
      HSPOL      : Bits_1; --  Horizontal Synchronization Polarity
   end record with Pack, Volatile, Size => 32;

   --  Shadow Reload Configuration Register
   type SRC_Registers is record
      IMR      : Bits_1; --  Immediate Reload
      VBR      : Bits_1; --  Vertical Blanking Reload
      Reserved : Bits_30;
   end record with Pack, Volatile, Size => 32;

   --  Background Color Configuration Register
   type BCC_Registers is record
      BCBlue   : Byte;
      BCGreen  : Byte;
      BCRed    : Byte;
      Reserved : Byte;
   end record with Pack, Volatile, Size => 32;

   --  Interrupt Enable Register
   type IE_Registers is record
      LIE      : Bits_1; --  Line Interrupt Enable
      FUIE     : Bits_1; --  FIFO Underrun Interrupt Enable
      TERRIE   : Bits_1; --  Transfer Error Interrupt Enable
      RRIE     : Bits_1; --  Register Reload interrupt enable
      Reserved : Bits_28;
   end record with Pack, Volatile, Size => 32;

   --  Interrupt Status Register
   type IS_Registers is record
      LIF      : Bits_1; --  Line Interrupt flag
      FUIF     : Bits_1; --  FIFO Underrun Interrupt flag
      TERRIF   : Bits_1; --  Transfer Error Interrupt flag
      RRIF     : Bits_1; --  Register Reload interrupt flag
      Reserved : Bits_28;
   end record with Pack, Volatile, Size => 32;

   --  Interrupt Clear Register
   type IC_Registers is record
      CLIF     : Bits_1; --  Clear Line Interrupt flag
      CFUIF    : Bits_1; --  Clear FIFO Underrun Interrupt flag
      CTERRIF  : Bits_1; --  Clear Transfer Error Interrupt flag
      CRRIF    : Bits_1; --  Clear Register Reload interrupt flag
      Reserved : Bits_28;
   end record with Pack, Volatile, Size => 32;

   --  Line Interrupt Position Configuration Register
   type LIPC_Registers is record
      LIPOS    : Bits_11; --  Line Interrupt Position
      Reserved : Bits_21;
   end record with Pack, Volatile, Size => 32;

   --  Current Position Status Register
   type CPS_Registers is record
      CYPOS : Bits_16;
      CXPOS : Bits_16;
   end record with Pack, Volatile, Size => 32;

   --  Current Display Status Register
   type CDS_Registers is record
      VDES     : Bits_1; --  Vertical Data Enable display Status
      HDES     : Bits_1; --  Horizontal Data Enable display Status
      VSYNCS   : Bits_1; --  Vertical Synchronization Enable display Status
      HSYNCS   : Bits_1; --  Horizontal Synchronization Enable display Status
      Reserved : Bits_28;
   end record with Pack, Volatile, Size => 32;

   Polarity_Active_Low  : constant := 0;
   Polarity_Active_High : constant := 1;

   type LTDCR is record
      Reserved_0 : Word;           --  Offset 0x000
      Reserved_1 : Word;
      SSC        : SSC_Registers;
      BPC        : BPC_Registers;

      AWC        : AWC_Registers;  --  Offset 0x010
      TWC        : TWC_Registers;
      GC         : GC_Registers;
      Reserved_2 : Word;

      Reserved_3 : Word;           --  Offset 0x020
      SRC        : SRC_Registers;
      Reserved_4 : Word;
      BCC        : BCC_Registers;

      Reserved_5 : Word;           --  Offset 0x030
      IE         : IE_Registers;
      ISR        : IS_Registers;
      IC         : IC_Registers;

      LIPC       : LIPC_Registers; --  Offset 0x040
      CPS        : CPS_Registers;
      CDS        : CDS_Registers;
      Reserved_6 : Word;
   end record with Size => 20 * 32;

   Peripheral_Base      : constant := 16#4000_0000#;
   APB2_Peripheral_Base : constant := Peripheral_Base + 16#0001_0000#;
   LTDC_Base            : constant := APB2_Peripheral_Base + 16#6800#;
   Layer1_Base          : constant := LTDC_Base + 16#084#;
   Layer2_Base          : constant := LTDC_Base + 16#104#;

   LTDC     : LTDCR with Volatile, Address => System'To_Address (LTDC_Base);
   Layer1_Reg : aliased Layer
     with Volatile, Address => System'To_Address (Layer1_Base);
   Layer2_Reg : aliased Layer
     with Volatile, Address => System'To_Address (Layer2_Base);

   type Layer_Access is access all Layer;

   Frame_Buffer_Array : array (LCD_Layer) of aliased Frame_Buffer
     with Volatile, Address => System'To_Address (16#D000_0000#);

   procedure Init_LCD_GPIO is
      Conf : GPIO_Port_Configuration;
   begin
      Enable_Clock (GPIO_A);
      Enable_Clock (GPIO_B);
      Enable_Clock (GPIO_C);
      Enable_Clock (GPIO_D);
      Enable_Clock (GPIO_F);
      Enable_Clock (GPIO_G);

      --  GPIO pins dedicated to LTDC port
      Configure_Alternate_Function (GPIO_A,
                                    (Pin_3, Pin_4, Pin_6, Pin_11, Pin_12),
                                    GPIO_AF_LTDC);

      Conf.Speed       := Speed_50MHz;
      Conf.Mode        := Mode_AF;
      Conf.Output_Type := Push_Pull;
      Conf.Resistors   := Floating;
      Conf.Locked      := True;
      Configure_IO (GPIO_A, (Pin_3, Pin_4, Pin_6, Pin_11, Pin_12), Conf);

      Configure_Alternate_Function (GPIO_B, (Pin_0, Pin_1), GPIO_AF_LTDC_2);
      Configure_Alternate_Function (GPIO_B, (Pin_8, Pin_9, Pin_10, Pin_11),
                                    GPIO_AF_LTDC);
      Configure_IO (GPIO_B, (Pin_0, Pin_1, Pin_8, Pin_9, Pin_10, Pin_11),
                    Conf);

      Configure_Alternate_Function (GPIO_C, (Pin_6, Pin_7, Pin_10),
                                    GPIO_AF_LTDC);
      Configure_IO (GPIO_C, (Pin_6, Pin_7, Pin_10), Conf);

      Configure_Alternate_Function (GPIO_D, (Pin_3, Pin_6), GPIO_AF_LTDC);
      Configure_IO (GPIO_D, (Pin_3, Pin_6), Conf);

      Configure_Alternate_Function (GPIO_F, Pin_10, GPIO_AF_LTDC);
      Configure_IO (GPIO_F, Pin_10, Conf);

      Configure_Alternate_Function (GPIO_G, (Pin_6, Pin_7, Pin_11),
                                    GPIO_AF_LTDC);
      Configure_Alternate_Function (GPIO_G, (Pin_10, Pin_12), GPIO_AF_LTDC_2);
      Configure_IO (GPIO_G, (Pin_6, Pin_7, Pin_10, Pin_11, Pin_12), Conf);

      --  PD11, PD12: unused
   end Init_LCD_GPIO;

   procedure Init_LCD_SPI is
      Conf     : GPIO_Port_Configuration;
      SPI_Conf : SPI_Configuration;
   begin
      --  Configure SPI lines.
      Enable_Clock (SCK_GPIO);
      Enable_Clock (MISO_GPIO);
      Enable_Clock (MOSI_GPIO);
      Enable_Clock (LCD_SPI);

      Configure_Alternate_Function (SCK_GPIO, SCK_Pin, SCK_AF);
      Configure_Alternate_Function (MISO_GPIO, MISO_Pin, MISO_AF);
      Configure_Alternate_Function (MOSI_GPIO, MOSI_Pin, MOSI_AF);

      Conf.Speed       := Speed_25MHz;
      Conf.Mode        := Mode_AF;
      Conf.Output_Type := Push_Pull;
      Conf.Resistors   := Pull_Down;
      Conf.Locked      := True;
      Configure_IO (SCK_GPIO, SCK_Pin, Conf);
      Configure_IO (MISO_GPIO, MISO_Pin, Conf);
      Configure_IO (MOSI_GPIO, MOSI_Pin, Conf);

      Reset (LCD_SPI);

      if not Is_Enabled (LCD_SPI) then
         SPI_Conf.Direction           := D2Lines_FullDuplex;
         SPI_Conf.Mode                := Master;
         SPI_Conf.Data_Size           := Data_8;
         SPI_Conf.Clock_Polarity      := Low;
         SPI_Conf.Clock_Phase         := P1Edge;
         SPI_Conf.Slave_Management    := Soft;
         SPI_Conf.Baud_Rate_Prescaler := BRP_16;
         SPI_Conf.First_Bit           := MSB;
         SPI_Conf.CRC_Poly            := 7;
         Configure (LCD_SPI, SPI_Conf);
         Enable (LCD_SPI);
      end if;
   end Init_LCD_SPI;

   procedure Chip_Select (Enabled : Boolean) is
   begin
      if Enabled then
         Clear (NCS_GPIO, NCS_Pin);
      else
         Set (NCS_GPIO, NCS_Pin);
      end if;
   end Chip_Select;

   procedure LCD_CtrlLinesConfig is
      Conf : GPIO_Port_Configuration;
   begin
      --  Configure CSX and DCX gpio as output.
      Enable_Clock (NCS_GPIO);
      Enable_Clock (WRX_GPIO);

      Conf.Speed       := Speed_50MHz;
      Conf.Mode        := Mode_Out;
      Conf.Output_Type := Push_Pull;
      Conf.Resistors   := Floating;
      Conf.Locked      := True;
      Configure_IO (NCS_GPIO, NCS_Pin, Conf);

      Configure_IO (WRX_GPIO, WRX_Pin, Conf);
      Chip_Select (false);
   end LCD_CtrlLinesConfig;

   procedure LCD_WriteCommand (Cmd : Half_Word) is
   begin
      --  Reset DCX (control)
      Clear (WRX_GPIO, WRX_Pin);

      --  Set /CSX
      Chip_Select (true);

      --  Send byte
      Send (LCD_SPI, Cmd);

      while not Tx_Is_Empty (LCD_SPI) loop
         null;
      end loop;

      while Is_Busy (LCD_SPI) loop
         null;
      end loop;

      --  Reset /CSX
      Chip_Select (false);
   end LCD_WriteCommand;

   procedure LCD_WriteData (Cmd : Half_Word) is
   begin
      --  Set DCX (data)
      Set (WRX_GPIO, WRX_Pin);

      --  Set /CSX
      Chip_Select (true);

      Send (LCD_SPI, Cmd);

      while not Tx_Is_Empty (LCD_SPI) loop
         null;
      end loop;

      while Is_Busy (LCD_SPI) loop
         --  if SPI_Get_Flags (LCD_SPI).Frame_Fmt_Error = 1 then
         --     raise Program_Error;
         --  end if;
         null;
      end loop;

      Chip_Select (false);

   end LCD_WriteData;

   --  LCD Registers
   LCD_SOFT_RESET    : constant := 16#01#;  --  Software reset
   LCD_SLEEP_OUT     : constant := 16#11#;  --  Sleep out register
   LCD_GAMMA         : constant := 16#26#;  --  Gamma register
   LCD_DISPLAY_OFF   : constant := 16#28#;  --  Display off register
   LCD_DISPLAY_ON    : constant := 16#29#;  --  Display on register
   LCD_COLUMN_ADDR   : constant := 16#2A#;  --  Colomn address register
   LCD_PAGE_ADDR     : constant := 16#2B#;  --  Page address register
   LCD_GRAM          : constant := 16#2C#;  --  GRAM register
   LCD_MAC           : constant := 16#36#;  --  Memory Access Control register
   LCD_PIXEL_FORMAT  : constant := 16#3A#;  --  Pixel Format register
   LCD_WDB           : constant := 16#51#;  --  Write Brightness Display reg
   LCD_WCD           : constant := 16#53#;  --  Write Control Display register
   LCD_RGB_INTERFACE : constant := 16#B0#;  --  RGB Interface Signal Control
   LCD_FRC           : constant := 16#B1#;  --  Frame Rate Control register
   LCD_BPC           : constant := 16#B5#;  --  Blanking Porch Control reg
   LCD_DFC           : constant := 16#B6#;  --  Display Function Control reg
   LCD_POWER1        : constant := 16#C0#;  --  Power Control 1 register
   LCD_POWER2        : constant := 16#C1#;  --  Power Control 2 register
   LCD_VCOM1         : constant := 16#C5#;  --  VCOM Control 1 register
   LCD_VCOM2         : constant := 16#C7#;  --  VCOM Control 2 register
   LCD_POWERA        : constant := 16#CB#;  --  Power control A register
   LCD_POWERB        : constant := 16#CF#;  --  Power control B register
   LCD_PGAMMA        : constant := 16#E0#;  --  Positive Gamma Correction reg
   LCD_NGAMMA        : constant := 16#E1#;  --  Negative Gamma Correction reg
   LCD_DTCA          : constant := 16#E8#;  --  Driver timing control A
   LCD_DTCB          : constant := 16#EA#;  --  Driver timing control B
   LCD_POWER_SEQ     : constant := 16#ED#;  --  Power on sequence register
   LCD_3GAMMA_EN     : constant := 16#F2#;  --  3 Gamma enable register
   LCD_INTERFACE     : constant := 16#F6#;  --  Interface control register
   LCD_PRC           : constant := 16#F7#;  --  Pump ratio control register

   procedure My_Delay (Ms : Integer) is
      Next_Start : Time := Clock;
      Period    : constant Time_Span := Milliseconds (Ms);
   begin
      Next_Start := Next_Start + Period;
      delay until Next_Start;
   end My_Delay;

   procedure LCD_PowerOn is
   begin
      LCD_WriteCommand (LCD_SOFT_RESET);
      My_Delay (10);
      LCD_WriteCommand (LCD_DISPLAY_OFF);

      LCD_WriteCommand (16#CA#);
      LCD_WriteData (16#C3#);
      LCD_WriteData (16#08#);
      LCD_WriteData (16#50#);
      LCD_WriteCommand (LCD_POWERB); --  0xcf
      LCD_WriteData (16#00#);
      LCD_WriteData (16#C1#);
      LCD_WriteData (16#30#);
      LCD_WriteCommand (LCD_POWER_SEQ); --  0xed
      LCD_WriteData (16#64#);
      LCD_WriteData (16#03#);
      LCD_WriteData (16#12#);
      LCD_WriteData (16#81#);
      LCD_WriteCommand (LCD_DTCA); --  0xe8
      LCD_WriteData (16#85#);
      LCD_WriteData (16#00#);
      LCD_WriteData (16#78#);
      LCD_WriteCommand (LCD_POWERA); --  0xcb
      LCD_WriteData (16#39#);
      LCD_WriteData (16#2C#);
      LCD_WriteData (16#00#);
      LCD_WriteData (16#34#);
      LCD_WriteData (16#02#);
      LCD_WriteCommand (LCD_PRC); --  0xf7
      LCD_WriteData (16#20#);
      LCD_WriteCommand (LCD_DTCB); --  0xea
      LCD_WriteData (16#00#);
      LCD_WriteData (16#00#);
      LCD_WriteCommand (LCD_FRC);  -- 0xb1
      LCD_WriteData (16#00#);  --  DIVA=0
      LCD_WriteData (16#1B#);  --  RTNA=11011 -> 70Hz
      LCD_WriteCommand (LCD_DFC);
      LCD_WriteData (16#0A#);
      LCD_WriteData (16#A2#);
      LCD_WriteCommand (LCD_POWER1);
      LCD_WriteData (16#10#);
      LCD_WriteCommand (LCD_POWER2);
      LCD_WriteData (16#10#);
      LCD_WriteCommand (LCD_VCOM1);
      LCD_WriteData (16#45#);
      LCD_WriteData (16#15#);
      LCD_WriteCommand (LCD_VCOM2);
      LCD_WriteData (16#90#);
      LCD_WriteCommand (LCD_MAC);
      LCD_WriteData (16#C8#); --  MY=1, MX=1, MV=0, ML=0, BGR=1, MH=0
      LCD_WriteCommand (LCD_PIXEL_FORMAT);
      LCD_WriteData (16#55#); --  DPI=101, DBI=101 (16 bits/pixel)
      LCD_WriteCommand (LCD_3GAMMA_EN);
      LCD_WriteData (16#00#);
      LCD_WriteCommand (LCD_RGB_INTERFACE);
      LCD_WriteData (16#C2#); -- ByPass=1, RCM=10 VSPL=0, HSPL=0, DPL=1, EPL=0
      LCD_WriteCommand (LCD_DFC);
      LCD_WriteData (16#0A#);
      LCD_WriteData (16#A7#);
      LCD_WriteData (16#27#);
      LCD_WriteData (16#04#);

      --  colomn address set: 0 - 239
      LCD_WriteCommand (LCD_COLUMN_ADDR);
      LCD_WriteData (16#00#);
      LCD_WriteData (16#00#);
      LCD_WriteData (16#00#);
      LCD_WriteData (16#EF#);
      --  Page Address Set: 0 - 319
      LCD_WriteCommand (LCD_PAGE_ADDR);
      LCD_WriteData (16#00#);
      LCD_WriteData (16#00#);
      LCD_WriteData (16#01#);
      LCD_WriteData (16#3F#);
      LCD_WriteCommand (LCD_INTERFACE);
      LCD_WriteData (16#01#); --  WEMODE: wrap at end of page
      LCD_WriteData (16#00#); --  ENDIAN=0 (big endian), EPF=00
      LCD_WriteData (16#06#); --  DM=01 (RGB), RM=1 (RGB), RIM=0

      LCD_WriteCommand (LCD_GRAM);
      My_Delay (200);

      LCD_WriteCommand (LCD_GAMMA);
      LCD_WriteData (16#01#);

      LCD_WriteCommand (LCD_PGAMMA);
      LCD_WriteData (16#0F#);
      LCD_WriteData (16#29#);
      LCD_WriteData (16#24#);
      LCD_WriteData (16#0C#);
      LCD_WriteData (16#0E#);
      LCD_WriteData (16#09#);
      LCD_WriteData (16#4E#);
      LCD_WriteData (16#78#);
      LCD_WriteData (16#3C#);
      LCD_WriteData (16#09#);
      LCD_WriteData (16#13#);
      LCD_WriteData (16#05#);
      LCD_WriteData (16#17#);
      LCD_WriteData (16#11#);
      LCD_WriteData (16#00#);
      LCD_WriteCommand (LCD_NGAMMA);
      LCD_WriteData (16#00#);
      LCD_WriteData (16#16#);
      LCD_WriteData (16#1B#);
      LCD_WriteData (16#04#);
      LCD_WriteData (16#11#);
      LCD_WriteData (16#07#);
      LCD_WriteData (16#31#);
      LCD_WriteData (16#33#);
      LCD_WriteData (16#42#);
      LCD_WriteData (16#05#);
      LCD_WriteData (16#0C#);
      LCD_WriteData (16#0A#);
      LCD_WriteData (16#28#);
      LCD_WriteData (16#2F#);
      LCD_WriteData (16#0F#);

      LCD_WriteCommand (LCD_SLEEP_OUT);
      My_Delay (200);
      LCD_WriteCommand (LCD_DISPLAY_ON);
      --  GRAM start writing
      LCD_WriteCommand (LCD_GRAM);
   end LCD_PowerOn;

   procedure Reload_Config is
      SRC : SRC_Registers;
   begin
      --  Set Immediate reload bit.
      SRC := LTDC.SRC;
      SRC.IMR := 1;
      LTDC.SRC := SRC;

      loop
         SRC := LTDC.SRC;
         exit when SRC.IMR = 0;
      end loop;
   end Reload_Config;

   function Get_Layer (Layer : LCD_Layer) return Layer_Access is
   begin
      if Layer = Layer1 then
         return Layer1_Reg'Access;
      else
         return Layer2_Reg'Access;
      end if;
   end Get_Layer;

   procedure Init_Layer (Layer             : LCD_Layer;
                         Pixel_Fmt         : Word;
                         Blending_Factor_1 : Bits_3;
                         Blending_Factor_2 : Bits_3)
   is
      L : constant Layer_Access := Get_Layer (Layer);
      FB : constant Frame_Buffer_Access := Get_Frame_Buffer (Layer);
   begin
      --  Clear Layer frame buffer
      FB.all := (others => Black);

      --  Windowing configuration.

      declare
         WHPC       : LWHPC_Registers  := L.WHPC;
         WVPC       : LWVPC_Registers  := L.WVPC;
         PFC        : LPFC_Register    := L.PFC;
         CAC        : LCAC_Registers   := L.CAC;
         DCC        : LDCC_Registers   := L.DCC;
         BFC        : LBFC_Registers   := L.BFC;
         CFBL       : LCFBL_Registers  := L.CFBL;
         CFBLN      : LCFBLN_Registers := L.CFBLN;
      begin

         --  Window position.
         WHPC.Horizontal_Start := 30;
         WHPC.Horizontal_Stop := (LCD_PIXEL_WIDTH + WHPC.Horizontal_Start - 1);

         WVPC.Vertical_Start := 4;
         WVPC.Vertical_Stop := (LCD_PIXEL_HEIGHT + 4 - 1);

         L.WHPC := WHPC;
         L.WVPC := WVPC;

         --  Pixel format.
         PFC := Pixel_Fmt;
         L.PFC := PFC;

         --  Constant alpha value: 1.0
         CAC.CONSTA := 255;
         L.CAC := CAC;

         --  Default color: block
         DCC.DCBlue  := 0;
         DCC.DCGreen := 0;
         DCC.DCRed   := 0;
         DCC.DCALPHA := 0;
         L.DCC := DCC;

         --  Blending factors:
         BFC.BF1 := Blending_Factor_1;
         BFC.BF2 := Blending_Factor_2;
         L.BFC := BFC;

         --  Frame buffer length
         CFBL.CFBLL := (LCD_PIXEL_WIDTH * 2) + 3;
         CFBL.CFBP := LCD_PIXEL_WIDTH * 2;
         L.CFBL := CFBL;

         --  Frame buffer line number
         CFBLN.CFBLNBR := LCD_PIXEL_HEIGHT;
         L.CFBLN := CFBLN;

         --  Frame buffer address
         L.CFBA := As_Word (Frame_Buffer_Array (Layer)'Address);
      end;

      Reload_Config;
   end Init_Layer;

   procedure Initialize is
   begin
      --  LCD controler interface.
      LCD_CtrlLinesConfig;

      Chip_Select (true);
      Chip_Select (false);

      Init_LCD_SPI;

      LCD_PowerOn;

      LTDC_Clock_Enable;

      Init_LCD_GPIO;

      STM32F4.SDRAM.Initialize;

      --  Global configuration.
      declare
         GC : GC_Registers;
      begin
         GC := LTDC.GC;
         GC.LTDCEN := 0;
         GC.VSPOL := Polarity_active_Low;
         GC.HSPOL := Polarity_active_Low;
         GC.DEPOL := Polarity_active_Low;
         GC.PCPOL := Polarity_active_Low;
         LTDC.GC := GC;
      end;

      Set_PLLSAI_Factors (LCD => 4,  SAI1 => 7, VCO => 192, DivR => 2);

      Enable_PLLSAI;

      --  Synchronization size.
      declare
         SSC : SSC_Registers;
      begin
         SSC := LTDC.SSC;
         SSC.HSW := HSYNCW - 1;
         SSC.VSH := VSYNCH - 1;
         LTDC.SSC := SSC;
      end;

      --  Back porch config
      --  HBP + HSW = 30, VBP + VSH = 4
      LTDC.BPC := (AHBP => HSYNCW + HBP - 1,
                   AVBP => VSYNCH + VBP - 1,
                   Reserved_1 => 0, Reserved_2 => 0);

      --  Active width config: 240x320
      LTDC.AWC := (AAW => HSYNCW + HBP + LCD_PIXEL_WIDTH - 1,
                   AAH => VSYNCH + VBP + LCD_PIXEL_HEIGHT - 1,
                   Reserved_1 => 0, Reserved_2 => 0);

      --  Total width config
      --   VFP = 4, HFP = 10
      LTDC.TWC := (TOTALW => HSYNCW + HBP + LCD_PIXEL_WIDTH + HFP - 1,
                   TOTALH => VSYNCH + VBP + LCD_PIXEL_HEIGHT + VFP - 1,
                   Reserved_1 => 0, Reserved_2 => 0);

      Set_Background (16#00#, 16#00#, 16#00#);

      Reload_Config;

      declare
         GC : GC_Registers;
      begin
         --  Enable LTDC
         GC := LTDC.GC;
         GC.LTDCEN := 1;
         LTDC.GC := GC;
      end;

      STM32F4.LCD.Init_Layer (Layer1, Default_Pixel_Fmt,
                              BF1_Pixel_Alpha,
                              BF2_Pixel_Alpha);
      Reload_Config;
      Set_Layer_State (Layer1, Enabled);

      declare
         GC : GC_Registers;
      begin
         GC := LTDC.GC;
         --  enable Dither
         GC.DEN := 1;
         LTDC.GC := GC;
      end;

   end Initialize;

   function Get_Frame_Buffer (Layer : LCD_Layer) return Frame_Buffer_Access is
   begin
      return Frame_Buffer_Array (Layer)'Access;
   end Get_Frame_Buffer;

   procedure Set_Layer_State (Layer : LCD_Layer; State : Layer_State) is
      L : constant Layer_Access := Get_Layer (Layer);
      Ctrl : LC_Registers;
   begin
      Ctrl := L.all.Ctrl;
      Ctrl.LEN := (if State = Enabled then 1 else 0);
      L.all.Ctrl := Ctrl;
      Reload_Config;
   end Set_Layer_State;

   procedure Set_Background (R, G, B : Byte) is
   begin
      LTDC.BCC := (BCRed => R, BCBlue => G, BCGreen => B, Reserved => 0);
   end Set_Background;

   procedure Set_Pixel (Layer : LCD_Layer;
                        X     : Width;
                        Y     : Height;
                        Pix   : Pixel)
   is
      FB : constant Frame_Buffer_Access := Get_Frame_Buffer (Layer);
      Pix_Index : constant Frame_Buffer_Range :=
        Frame_Buffer_Range (X + Y * LCD_PIXEL_WIDTH);
   begin
      FB (Pix_Index) := Pix;
   end Set_Pixel;

   function Get_Pixel (Layer : LCD_Layer;
                        X     : Width;
                        Y     : Height) return Pixel
   is
      FB : constant Frame_Buffer_Access := Get_Frame_Buffer (Layer);
      Pix_Index : constant Frame_Buffer_Range :=
        Frame_Buffer_Range (X + Y * LCD_PIXEL_WIDTH);
   begin
      return FB (Pix_Index);
   end Get_Pixel;

end STM32F4.LCD;
