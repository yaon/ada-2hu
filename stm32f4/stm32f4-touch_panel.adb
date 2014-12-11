with Ada.Real_Time; use Ada.Real_Time;
with STM32F4.I2C;   use STM32F4.I2C;
with STM32F4.GPIO;  use STM32F4.GPIO;
with STM32F4.Reset_Clock_Control;

with STM32F429_Discovery;  use STM32F429_Discovery;

--  STMPE811 driver

package body STM32F4.Touch_Panel is

   SCL_GPIO : GPIO_Port renames GPIO_A;
   SCL_Pin  : GPIO_Pin  renames Pin_8;
   SCL_AF   : GPIO_Alternate_Function   renames GPIO_AF_I2C3;

   SDA_GPIO   : GPIO_Port               renames GPIO_C;
   SDA_Pin    : GPIO_Pin                renames Pin_9;
   SDA_AF     : GPIO_Alternate_Function renames GPIO_AF_I2C3;

   TP_I2C : I2C_Port renames I2C_3;

   --  ADDR0 = 0 -> address is 0x82
   IOE_ADDR : constant Byte := 16#82#;

   --  Control Registers
   IOE_REG_SYS_CTRL1 : constant Byte := 16#03#;
   IOE_REG_SYS_CTRL2 : constant Byte := 16#04#;
   IOE_REG_SPI_CFG   : constant Byte := 16#08#;

   --  Touch Panel Registers
   IOE_REG_TP_CTRL      : constant Byte := 16#40#;
   IOE_REG_TP_CFG       : constant Byte := 16#41#;
   IOE_REG_WDM_TR_X     : constant Byte := 16#42#;
   IOE_REG_WDM_TR_Y     : constant Byte := 16#44#;
   IOE_REG_WDM_BL_X     : constant Byte := 16#46#;
   IOE_REG_WDM_BL_Y     : constant Byte := 16#48#;
   IOE_REG_FIFO_TH      : constant Byte := 16#4A#;
   IOE_REG_FIFO_STA     : constant Byte := 16#4B#;
   IOE_REG_FIFO_SIZE    : constant Byte := 16#4C#;
   IOE_REG_TP_DATA_X    : constant Byte := 16#4D#;
   IOE_REG_TP_DATA_Y    : constant Byte := 16#4F#;
   IOE_REG_TP_DATA_Z    : constant Byte := 16#51#;
   IOE_REG_TP_DATA_XYZ  : constant Byte := 16#52#;
   IOE_REG_TP_FRACT_XYZ : constant Byte := 16#56#;
   IOE_REG_TP_DATA      : constant Byte := 16#57#;
   IOE_REG_TP_I_DRIVE   : constant Byte := 16#58#;
   IOE_REG_TP_SHIELD    : constant Byte := 16#59#;

   --  IOE GPIO Registers
   IOE_REG_GPIO_SET_PIN : constant Byte := 16#10#;
   IOE_REG_GPIO_CLR_PIN : constant Byte := 16#11#;
   IOE_REG_GPIO_MP_STA  : constant Byte := 16#12#;
   IOE_REG_GPIO_DIR     : constant Byte := 16#13#;
   IOE_REG_GPIO_ED      : constant Byte := 16#14#;
   IOE_REG_GPIO_RE      : constant Byte := 16#15#;
   IOE_REG_GPIO_FE      : constant Byte := 16#16#;
   IOE_REG_GPIO_AF      : constant Byte := 16#17#;

   --  IOE Functions
   IOE_ADC_FCT : constant Byte := 16#01#;
   IOE_TP_FCT  : constant Byte := 16#02#;
   IOE_IO_FCT  : constant Byte := 16#04#;

   --  ADC Registers
   IOE_REG_ADC_INT_EN   : constant Byte := 16#0E#;
   IOE_REG_ADC_INT_STA  : constant Byte := 16#0F#;
   IOE_REG_ADC_CTRL1    : constant Byte := 16#20#;
   IOE_REG_ADC_CTRL2    : constant Byte := 16#21#;
   IOE_REG_ADC_CAPT     : constant Byte := 16#22#;
   IOE_REG_ADC_DATA_CH0 : constant Byte := 16#30#;
   IOE_REG_ADC_DATA_CH1 : constant Byte := 16#32#;
   IOE_REG_ADC_DATA_CH2 : constant Byte := 16#34#;
   IOE_REG_ADC_DATA_CH3 : constant Byte := 16#36#;
   IOE_REG_ADC_DATA_CH4 : constant Byte := 16#38#;
   IOE_REG_ADC_DATA_CH5 : constant Byte := 16#3A#;
   IOE_REG_ADC_DATA_CH6 : constant Byte := 16#3B#;
   IOE_REG_ADC_DATA_CH7 : constant Byte := 16#3C#;

   --  Interrupt Control Registers
   IOE_REG_INT_CTRL     : constant Byte := 16#09#;
   IOE_REG_INT_EN       : constant Byte := 16#0A#;
   IOE_REG_INT_STA      : constant Byte := 16#0B#;
   IOE_REG_GPIO_INT_EN  : constant Byte := 16#0C#;
   IOE_REG_GPIO_INT_STA : constant Byte := 16#0D#;

   --  touch Panel Pins
   TOUCH_YD     : constant Byte := 16#02#;
   TOUCH_XD     : constant Byte := 16#04#;
   TOUCH_YU     : constant Byte := 16#08#;
   TOUCH_XU     : constant Byte := 16#10#;
   TOUCH_IO_ALL : constant Byte :=
     TOUCH_YD or TOUCH_XD or TOUCH_YU or TOUCH_XU;

   function Read_Data (Data_Addr : Byte) return Half_Word is
      Data : Half_Word;
   begin
      --  Send start
      Generate_Start (TP_I2C, Enabled);
      Wait_For_Flag (TP_I2C, SB, Enabled);

      --  Send addr
      Send_7Bit_Addr (TP_I2C, IOE_ADDR, Transmitter);
      Wait_For_Flag (TP_I2C, ADDR, Enabled);
      Clear_Flag (TP_I2C, ADDR);

      --  Send data
      Wait_For_Flag (TP_I2C, TXE, Enabled);
      Send_Data (TP_I2C, Data_Addr);

      --  Send start
      Generate_Start (TP_I2C, Enabled);
      Wait_For_Flag (TP_I2C, SB, Enabled);

      --  Send addr (receiver)
      Send_7Bit_Addr (TP_I2C, IOE_ADDR, Receiver);
      Wait_For_Flag (TP_I2C, ADDR, Enabled);

      Set_Ack_Config (TP_I2C, Disabled);
      Set_Nack_Config (TP_I2C, Next);

      Clear_Flag (TP_I2C, ADDR);

      Wait_For_Flag (TP_I2C, BTF, Enabled);

      Generate_Stop (TP_I2C, Enabled);

      Data := Half_Word (Read_Data (TP_I2C)) * (2**8);
      Data := Data or Half_Word (Read_Data (TP_I2C));

      Set_Ack_Config (TP_I2C, Enabled);
      Set_Nack_Config (TP_I2C, Current);

      return Data;
   end Read_Data;

   function Read_Register (Reg_Addr : Byte) return Byte is
      Data : Byte;
   begin
      --  Start
      Generate_Start (TP_I2C, Enabled);
      Wait_For_Flag (TP_I2C, SB, Enabled);

      Set_Ack_Config (TP_I2C, Disabled);

      --  Device address, R/W=0
      Send_7Bit_Addr (TP_I2C, IOE_ADDR, Transmitter);
      Wait_For_Flag (TP_I2C, ADDR, Enabled);
      Clear_Flag (TP_I2C, ADDR);

      --  Reg address
      Wait_For_Flag (TP_I2C, TXE, Enabled);
      Send_Data (TP_I2C, Reg_Addr);

      while (not Get_Flag (TP_I2C, TXE))
        or else (not Get_Flag (TP_I2C, BTF))
      loop
         null;
      end loop;

      --  Start
      Generate_Start (TP_I2C, Enabled);
      Wait_For_Flag (TP_I2C, SB, Enabled);

      --  Device address, R/W=1
      Send_7Bit_Addr (TP_I2C, IOE_ADDR, Receiver);
      Wait_For_Flag (TP_I2C, ADDR, Enabled);
      Clear_Flag (TP_I2C, ADDR);

      --  Wait byte
      Wait_For_Flag (TP_I2C, RXNE, Enabled);

      --  Stop
      Generate_Stop (TP_I2C, Enabled);

      Data := Read_Data (TP_I2C);

      --  Ack
      Set_Ack_Config (TP_I2C, Enabled);

      return Data;
   end Read_Register;

   procedure Write_Register (Reg_Addr : Byte; Data : Byte) is
   begin
      --  Start
      Generate_Start (TP_I2C, Enabled);
      Wait_For_Flag (TP_I2C, SB, Enabled);

      Set_Ack_Config (TP_I2C, Disabled);

      --  Device address
      Send_7Bit_Addr (TP_I2C, IOE_ADDR, Transmitter);
      Wait_For_Flag (TP_I2C, ADDR, Enabled);
      Clear_Flag (TP_I2C, ADDR);

      --  Register
      Wait_For_Flag (TP_I2C, TXE, Enabled);
      Send_Data (TP_I2C, Reg_Addr);

      --  Value
      Wait_For_Flag (TP_I2C, TXE, Enabled);
      Send_Data (TP_I2C, Data);

      while not Get_Flag (TP_I2C, TXE) or else not Get_Flag (TP_I2C, BTF) loop
         null;
      end loop;

      Generate_Stop (TP_I2C, Enabled);
   end Write_Register;

   procedure TP_Ctrl_Lines is
      GPIO_Conf : GPIO_Port_Configuration;
   begin
      Enable_Clock (SDA_GPIO);
      Enable_Clock (SCL_GPIO);

      Enable_Clock (TP_I2C);

      Reset (TP_I2C);

      Enable_Clock (TP_I2C);

      Configure_Alternate_Function (SCL_GPIO, SCL_Pin, SCL_AF);
      Configure_Alternate_Function (SDA_GPIO, SDA_Pin, SDA_AF);

      GPIO_Conf.Speed       := Speed_25MHz;
      GPIO_Conf.Mode        := Mode_AF;
      GPIO_Conf.Output_Type := Open_Drain;
      GPIO_Conf.Resistors   := Floating;
      GPIO_Conf.Locked      := True;
      Configure_IO (SCL_GPIO, SCL_Pin, GPIO_Conf);
      Configure_IO (SDA_GPIO, SDA_Pin, GPIO_Conf);
   end TP_Ctrl_Lines;

   procedure TP_I2C_Config is
      I2C_Conf : I2C_Config;
   begin
      STM32F4.Reset_Clock_Control.I2C3_Force_Reset;
      STM32F4.Reset_Clock_Control.I2C3_Release_Reset;

      I2C_Conf.Mode := I2C_Mode_I2C;
      I2C_Conf.Duty_Cycle := I2C_DutyCycle_2;
      I2C_Conf.Own_Address := 16#00#;
      I2C_Conf.Ack := I2C_Ack_Enable;
      I2C_Conf.Ack_Address := I2C_AcknowledgedAddress_7bit;
      I2C_Conf.Clock_Speed := 1_000;

      Configure (TP_I2C, I2C_Conf);

      Set_State (TP_I2C, Enabled);
   end TP_I2C_Config;

   procedure IOE_Reset is
   begin
      Write_Register (IOE_REG_SYS_CTRL1, 16#02#);

      --  Give some time for the reset
      delay until Clock + Milliseconds (2);

      Write_Register (IOE_REG_SYS_CTRL1, 16#00#);
   end IOE_Reset;

   procedure IOE_Function_Command (Func : Byte; Enabled : Boolean) is
      Reg : Byte := Read_Register (IOE_REG_SYS_CTRL2);
   begin
      --  CTRL2 functions are disabled when corresponding bit is set

      if Enabled then
         Reg := Reg and (not Func);
      else
         Reg := Reg or Func;
      end if;

      Write_Register (IOE_REG_SYS_CTRL2, Reg);
   end IOE_Function_Command;

   procedure IOE_AF_Config (Pin : Byte; Enabled : Boolean) is
      Reg : Byte := Read_Register (IOE_REG_GPIO_AF);
   begin
      if Enabled then
         Reg := Reg or Pin;
      else
         Reg := Reg and (not Pin);
      end if;

      Write_Register (IOE_REG_GPIO_AF, Reg);
   end IOE_AF_Config;

   function Get_IOE_ID return Half_Word is
   begin
      return (Half_Word (Read_Register (0)) * (2**8))
        or Half_Word (Read_Register (1));
   end Get_IOE_ID;

   procedure Initialize is
   begin
      TP_Ctrl_Lines;
      TP_I2C_Config;

      delay until Clock + Milliseconds (100);

      --  Check chip id.
      if Get_IOE_ID /= 16#0811# then
         raise Program_Error;
      end if;

      IOE_Reset;

      --  Enable ADC and TSC (ie disable clock gating).
      IOE_Function_Command (IOE_ADC_FCT, true);
      IOE_Function_Command (IOE_TP_FCT, true);

      --  Sample time: 80, 12bit, + reserved ?
      Write_Register (IOE_REG_ADC_CTRL1, 16#49#);

      delay until Clock + Milliseconds (2);

      --  Freq: 3.25Mhz
      Write_Register (IOE_REG_ADC_CTRL2, 16#01#);

      --  GPIO pins for ADC
      IOE_AF_Config (TOUCH_IO_ALL, false);

      --  Average of 2 samples, delay: 500us, settling: 500us
      Write_Register (IOE_REG_TP_CFG, 16#9A#);

      --  Fifo threshold: 1
      Write_Register (IOE_REG_FIFO_TH, 16#01#);

      --  Reset fifo.
      Write_Register (IOE_REG_FIFO_STA, 16#01#);

      --  Threshold: 0 ???
      Write_Register (IOE_REG_FIFO_TH, 16#00#);

      Write_Register (IOE_REG_TP_FRACT_XYZ, 16#00#);

      --  Drive: 50mA
      Write_Register (IOE_REG_TP_I_DRIVE, 16#01#);

      --  Enable.
      Write_Register (IOE_REG_TP_CTRL, 16#01#);

      --  Clear interrupt bits.
      Write_Register (IOE_REG_INT_STA, 16#FF#);
   end Initialize;

   function Read_X return LCD.Width is
      X, XR : Integer;
      Raw_X : Half_Word;
   begin
      Raw_X := Read_Data (IOE_REG_TP_DATA_X);
      X := Integer (Raw_X);

      if X <= 3000 then
         X := 3900 - X;
      else
         X := 3800 - X;
      end if;

      XR := X / 15;

      if XR < LCD.Width'First then
         XR := LCD.Width'First;
      elsif XR > LCD.Width'Last then
         XR := LCD.Width'Last;
      end if;
      return LCD.Width (XR);
   end Read_X;

   function Read_Y return LCD.Height is
      Y, YR : Integer;
      Raw_Y : Half_Word;
   begin
      Raw_Y := Read_Data (IOE_REG_TP_DATA_Y);
      Y := Integer (Raw_Y);

      Y := Y - 360;

      YR := Y / 11;

      if YR < LCD.Height'First then
         YR := LCD.Height'First;
      elsif YR > LCD.Height'Last then
         YR := LCD.Height'Last;
      end if;
      return LCD.Height (YR);
   end Read_Y;

   function Read_Z return Half_Word is
   begin
      return Read_Data (IOE_REG_TP_DATA_Z);
   end Read_Z;

   function Get_State return TP_State is
      State : TP_State;
      Ctrl : Byte;
      X : LCD.Width  := 0;
      Y : LCD.Height := 0;
      Z : Half_Word  := 0;
   begin

      --  Check Touch detected bit in CTRL register
      Ctrl := Read_Register (IOE_REG_TP_CTRL);
      State.Touch_Detected := (Ctrl and 16#80#) /= 0;

      if State.Touch_Detected then
         X := Read_X;
         Y := Read_Y;
         Z := Read_Z;
      end if;

      State.X := X;
      State.Y := Y;
      State.Z := Z;

      --  Clear fifo.
      Write_Register (IOE_REG_FIFO_STA, 16#01#);
      Write_Register (IOE_REG_FIFO_STA, 16#00#);
      return State;
   end Get_State;

end STM32F4.Touch_Panel;
