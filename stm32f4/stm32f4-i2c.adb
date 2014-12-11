------------------------------------------------------------------------------
--                                                                          --
--                             GNAT EXAMPLE                                 --
--                                                                          --
--             Copyright (C) 2014, Free Software Foundation, Inc.           --
--                                                                          --
-- GNAT is free software;  you can  redistribute it  and/or modify it under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  GNAT is distributed in the hope that it will be useful, but WITH- --
-- OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE.                                     --
--                                                                          --
-- As a special exception under Section 7 of GPL version 3, you are granted --
-- additional permissions described in the GCC Runtime Library Exception,   --
-- version 3.1, as published by the Free Software Foundation.               --
--                                                                          --
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
-- GNAT was originally developed  by the GNAT team at  New York University. --
-- Extensive contributions were provided by Ada Core Technologies Inc.      --
--                                                                          --
------------------------------------------------------------------------------

with STM32F4.Reset_Clock_Control; use STM32F4.Reset_Clock_Control;

package body STM32F4.I2C is

   subtype I2C_SR1_Flag is I2C_Flag range SB .. SMBALERT;
   subtype I2C_SR2_Flag is I2C_Flag range MSL .. DUALF;

   SR1_Flag_Pos : constant array (I2C_SR1_Flag) of Natural :=
     (0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12, 14, 15);

   SR2_Flag_Pos : constant array (I2C_SR2_Flag) of Natural :=
     (0, 1, 2, 4, 5, 6, 7);

   ---------------
   -- Configure --
   ---------------

   procedure Configure (Port : out I2C_Port; Conf : I2C_Config) is
      CR2, CR1   : Half_Word;
      CCR        : Half_Word := 0;
      Pclk1      : Word;
      Freq_Range : Half_Word;
   begin
      --  Load CR2 and clear FREQ
      --  the Reference Manual, RM0090, Doc ID 018909 Rev 6 843 specifies that the
      --  reset value for Cr2 is zero so we just clear it
--        CR2 := Port.CR2 and (not 16#3F#);
      CR2 := 0;

      --  Compute frequency from pclk1
      Pclk1 := Get_Clock_Frequency.Pclk1;
      Freq_Range := Half_Word (Pclk1 / 1_000_000);
      if Freq_Range < 2 or else Freq_Range > 42 then
         raise Program_Error;
      end if;

      Port.CR2 := CR2 or Freq_Range;

      Set_State (Port, Disabled);

      if Conf.Clock_Speed <= 100_000 then
         CCR := Half_Word (Pclk1 / (Conf.Clock_Speed * 2));

         if CCR < 4 then
            CCR := 4;
         end if;
         Port.TRISE := Freq_Range + 1;
      else
         --  Fast mode

         if Conf.Duty_Cycle = I2C_DutyCycle_2 then
            CCR := Half_Word (Pclk1 / (Conf.Clock_Speed * 3));
         else
            CCR := Half_Word (Pclk1 / (Conf.Clock_Speed * 25));
            CCR := CCR or I2C_DutyCycle_16_9;
         end if;

         if (CCR and 16#0FFF#) = 0 then
            CCR := 1;
         end if;

         CCR := CCR or 16#80#;

         Port.TRISE := (Freq_Range * 300) / 1000 + 1;
      end if;

      Port.CCR := CCR;

      Set_State (Port, Enabled);

      CR1 := Port.CR1;

      CR1 := CR1 and 16#FBF5#;

      CR1 := CR1 or Conf.Mode or Conf.Ack;
      Port.CR1 := CR1;

      Port.OAR1 := Conf.Ack_Address or Conf.Own_Address;
   end Configure;

   ---------------
   -- Set_State --
   ---------------

   procedure Set_State (Port : in out I2C_Port; State : I2C_State) is
   begin
      if State = Enabled then
         Port.CR1 := Port.CR1 or CR1_PE;
      else
         Port.CR1 := Port.CR1 and (not CR1_PE);
      end if;
   end Set_State;

   ----------------
   -- Is_Enabled --
   ----------------

   function Is_Enabled (Port : I2C_Port) return Boolean is
   begin
      return (Port.CR1 and 16#01#) /= 0;
   end Is_Enabled;

   --------------------
   -- Generate_Start --
   --------------------

   procedure Generate_Start (Port : in out I2C_Port; State : I2C_State) is
   begin
      if State = Enabled then
         Port.CR1 := Port.CR1 or CR1_START;
      else
         Port.CR1 := Port.CR1 and (not CR1_START);
      end if;
   end Generate_Start;

   -------------------
   -- Generate_Stop --
   -------------------

   procedure Generate_Stop (Port : in out I2C_Port; State : I2C_State) is
   begin
      if State = Enabled then
         Port.CR1 := Port.CR1 or CR1_STOP;
      else
         Port.CR1 := Port.CR1 and (not CR1_STOP);
      end if;
   end Generate_Stop;

   --------------------
   -- Send_7Bit_Addr --
   --------------------

   procedure Send_7Bit_Addr
     (Port : in out I2C_Port;
      Addr : Byte;
      Dir  : I2C_Direction)
   is
      Address : Half_Word := Half_Word (Addr);
   begin
      if Dir = Receiver then
         Address := Address or I2C_OAR1_ADD0;
      else
         Address := Address and (not I2C_OAR1_ADD0);
      end if;

      Port.DR := Address;
   end Send_7Bit_Addr;

   --------------
   -- Get_Flag --
   --------------

   function Get_Flag (Port : I2C_Port; Flag : I2C_Flag) return Boolean is
   begin
      if Flag in I2C_SR1_Flag then
         return (Port.SR1 and (2**SR1_Flag_Pos (Flag))) /= 0;
      else
         return (Port.SR2 and (2**SR2_Flag_Pos (Flag))) /= 0;
      end if;
   end Get_Flag;

   ----------------
   -- Clear_Flag --
   ----------------

   procedure Clear_Flag (Port : in out I2C_Port; Flag : I2C_Flag) is
      Unref : Half_Word with Unreferenced;
   begin
      if Flag = ADDR then
         --  To clear the ADDR flag we have to read SR2 after reading SR1
         Unref := Port.SR1;
         Unref := Port.SR2;
      else
         if Flag in I2C_SR1_Flag then
            Port.SR1 := Port.SR1 and (not (2**SR1_Flag_Pos (Flag)));
         else
            Port.SR2 := Port.SR2 and (not (2**SR2_Flag_Pos (Flag)));
         end if;
      end if;
   end Clear_Flag;

   -------------------
   -- Wait_For_Flag --
   -------------------

   procedure Wait_For_Flag (Port     : I2C_Port;
                            Flag     : I2C_Flag;
                            State    : I2C_State;
                            Time_Out : Natural := 1_000_000)
   is
      pragma Unreferenced (Time_Out);
      Expected : constant Boolean := (if State = Enabled then True else False);
      --  Cnt : Natural := Time_Out;
   begin
      while Get_Flag (Port, Flag) /= Expected loop
         --  Cnt := Cnt - 1;
         --  if Cnt = 0 then
         --     raise Program_Error;
         --  end if;
         null;
      end loop;
   end Wait_For_Flag;

   ---------------
   -- Send_Data --
   ---------------

   procedure Send_Data (Port : in out I2C_Port; Data : Byte) is
   begin
      Port.DR := Half_Word (Data);
   end Send_Data;

   ---------------
   -- Read_Data --
   ---------------

   function Read_Data (Port : I2C_Port) return Byte is
   begin
      return Byte (Port.DR);
   end Read_Data;

   --------------------
   -- Set_Ack_Config --
   --------------------

   procedure Set_Ack_Config (Port : in out I2C_Port; State : I2C_State) is
   begin
      if State = Enabled then
         Port.CR1 := Port.CR1 or CR1_ACK;
      else
         Port.CR1 := Port.CR1 and (not CR1_ACK);
      end if;
   end Set_Ack_Config;

   ---------------------
   -- Set_Nack_Config --
   ---------------------

   procedure Set_Nack_Config (Port  : in out I2C_Port; Pos : I2C_Nack_Position) is
   begin
      if Pos = Next then
         Port.CR1 := Port.CR1 or CR1_POS;
      else
         Port.CR1 := Port.CR1 and (not CR1_POS);
      end if;
   end Set_Nack_Config;

end STM32F4.I2C;
