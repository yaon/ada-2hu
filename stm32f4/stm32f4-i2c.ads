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

--  This file provides definitions for the STM32F4 (ARM Cortex M4F
--  from ST Microelectronics) Inter-Integrated Circuit (I2C) facility.

package STM32F4.I2C is

   type I2C_Port is limited private;

   I2C_Mode_I2C         : constant := 16#0000#;
   I2C_Mode_SMBusDevice : constant := 16#0002#;
   I2C_Mode_SMBusHost   : constant := 16#000A#;

   I2C_DutyCycle_16_9 : constant := 16#4000#;
   I2C_DutyCycle_2    : constant := 16#BFFF#;

   I2C_Ack_Enable  : constant := 16#0400#;
   I2C_Ack_Disable : constant := 16#0000#;

   type I2C_Direction is (Transmitter, Receiver);

   I2C_Direction_Transmitter : constant := 16#00#;
   I2C_Direction_Receiver    : constant := 16#01#;

   I2C_AcknowledgedAddress_7bit  : constant := 16#4000#;
   I2C_AcknowledgedAddress_10bit : constant := 16#C000#;

   type I2C_Flag is (SB, ADDR, BTF, ADD10, STOPF, RxNE, TxE, BERR, ARLO, AF,
                     OVR, PECERR, TIMEOUT, SMBALERT, MSL, BUSY, TRA,
                     GENCALL, SMBDEFAULT, SMBHOST, DUALF);

   type I2C_Config is record
      Clock_Speed : Word;
      Mode        : Half_Word;
      Duty_Cycle  : Half_Word;
      Own_Address : Half_Word;
      Ack         : Half_Word;
      Ack_Address : Half_Word;
   end record;

   procedure Configure (Port : out I2C_Port; Conf : I2C_Config);

   type I2C_State is (Enabled, Disabled);

   procedure Set_State (Port : in out I2C_Port; State : I2C_State);

   function Is_Enabled (Port : I2C_Port) return Boolean;

   procedure Generate_Start (Port : in out I2C_Port; State : I2C_State);

   procedure Generate_Stop (Port : in out I2C_Port; State : I2C_State);

   procedure Send_7Bit_Addr
     (Port : in out I2C_Port;
      Addr : Byte;
      Dir  : I2C_Direction);

   procedure Send_Data (Port : in out I2C_Port; Data : Byte);

   function Read_Data (Port : I2C_Port) return Byte;

   function Get_Flag (Port : I2C_Port; Flag : I2C_Flag) return Boolean;

   procedure Clear_Flag (Port : in out I2C_Port; Flag : I2C_Flag);

   procedure Wait_For_Flag
     (Port     : I2C_Port;
      Flag     : I2C_Flag;
      State    : I2C_State;
      Time_Out : Natural := 1_000_000);

   procedure Set_Ack_Config (Port : in out I2C_Port; State : I2C_State);

   type I2C_Nack_Position is (Next, Current);

   procedure Set_Nack_Config (Port : in out I2C_Port; Pos : I2C_Nack_Position);

private

   type I2C_Port is record
      CR1       : Half_Word;
      Reserved1 : Half_Word;
      CR2       : Half_Word;
      Reserved2 : Half_Word;
      OAR1      : Half_Word;
      Reserved3 : Half_Word;
      OAR2      : Half_Word;
      Reserved4 : Half_Word;
      DR        : Half_Word;
      Reserved5 : Half_Word;
      SR1       : Half_Word;
      Reserved6 : Half_Word;
      SR2       : Half_Word;
      Reserved7 : Half_Word;
      CCR       : Half_Word;
      Reserved8 : Half_Word;
      TRISE     : Half_Word;
      Reserved9 : Half_Word;
      FLTR      : Half_Word;
      Reserved0 : Half_Word;
   end record
     with Volatile, Size => 20 * 16;

   for I2C_Port use record
      CR1       at 0  range 0 .. 15;
      Reserved1 at 2  range 0 .. 15;
      CR2       at 4  range 0 .. 15;
      Reserved2 at 6  range 0 .. 15;
      OAR1      at 8  range 0 .. 15;
      Reserved3 at 10 range 0 .. 15;
      OAR2      at 12 range 0 .. 15;
      Reserved4 at 14 range 0 .. 15;
      DR        at 16 range 0 .. 15;
      Reserved5 at 18 range 0 .. 15;
      SR1       at 20 range 0 .. 15;
      Reserved6 at 22 range 0 .. 15;
      SR2       at 24 range 0 .. 15;
      Reserved7 at 26 range 0 .. 15;
      CCR       at 28 range 0 .. 15;
      Reserved8 at 30 range 0 .. 15;
      TRISE     at 32 range 0 .. 15;
      Reserved9 at 34 range 0 .. 15;
      FLTR      at 36 range 0 .. 15;
      Reserved0 at 38 range 0 .. 15;
   end record;


   CR1_PE        : constant := 16#0001#; --  Peripheral Enable
   CR1_SMBUS     : constant := 16#0002#; --  SMBus Mode
   CR1_SMBTYPE   : constant := 16#0008#; --  SMBus Type
   CR1_ENARP     : constant := 16#0010#; --  ARP Enable
   CR1_ENPEC     : constant := 16#0020#; --  PEC Enable
   CR1_ENGC      : constant := 16#0040#; --  General Call Enable
   CR1_NOSTRETCH : constant := 16#0080#; --  Clock Stretching Disable (Slave mode)
   CR1_START     : constant := 16#0100#; --  Start Generation
   CR1_STOP      : constant := 16#0200#; --  Stop Generation
   CR1_ACK       : constant := 16#0400#; --  Acknowledge Enable
   CR1_POS       : constant := 16#0800#; --  Acknowledge/PEC Position (for data reception)
   CR1_PEC       : constant := 16#1000#; --  Packet Error Checking
   CR1_ALERT     : constant := 16#2000#; --  SMBus Alert
   CR1_SWRST     : constant := 16#8000#; --  Software Reset

   I2C_OAR1_ADD0 : constant := 16#0001#;
   I2C_OAR1_ADD1 : constant := 16#0002#;
   I2C_OAR1_ADD2 : constant := 16#0004#;
   I2C_OAR1_ADD3 : constant := 16#0008#;
   I2C_OAR1_ADD4 : constant := 16#0010#;
   I2C_OAR1_ADD5 : constant := 16#0020#;
   I2C_OAR1_ADD6 : constant := 16#0040#;
   I2C_OAR1_ADD7 : constant := 16#0080#;
   I2C_OAR1_ADD8 : constant := 16#0100#;
   I2C_OAR1_ADD9 : constant := 16#0200#;

end STM32F4.I2C;
