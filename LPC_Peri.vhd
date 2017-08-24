-- --------------------------------------------------------------------
-- >>>>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<
-- --------------------------------------------------------------------
-- Copyright (c) 2005 - 2011 by Lattice Semiconductor Corporation
-- --------------------------------------------------------------------
--
-- Permission:
--
-- Lattice Semiconductor grants permission to use this code for use
-- in synthesis for any Lattice programmable logic product. Other
-- use of this code, including the selling or duplication of any
-- portion is strictly prohibited.
--
-- Disclaimer:
--
-- This VHDL or Verilog source code is intended as a design reference
-- which illustrates how these types of functions can be implemented.
-- It is the user's responsibility to verify their design for
-- consistency and functionality through the use of formal
-- verification methods. Lattice Semiconductor provides no warranty
-- regarding the use or functionality of this code.
--
-- --------------------------------------------------------------------
--
-- Lattice Semiconductor Corporation
-- 5555 NE Moore Court
-- Hillsboro, OR 97214
-- U.S.A
--
-- TEL: 1-800-Lattice (USA and Canada)
-- 503-268-8001 (other locations)
--
-- web: http://www.latticesemi.com/
-- email: techsupport@latticesemi.com
--
-- --------------------------------------------------------------------
-- Code Revision History :
-- --------------------------------------------------------------------
-- Ver: | Author |Mod. Date |Changes Made:
-- V0.5 | MR     |01/29/08  |Initial ver
-- V1.0 | MR     |02/09/09  |Clean up comments
-- V1.1	| Peter	 |09/22/09	|Add VHDL support
-- --------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

ENTITY LPC_Peri IS
  PORT
  (
      -- LPC Interface
    lclk                    : IN std_logic;
      -- Clock
    lreset_n                : IN std_logic;
      -- Reset - Active Low (Same as PCI Reset)
    lframe_n                : IN std_logic;
      -- Frame - Active Low
    lad_in                  : INOUT std_logic_vector(3 DOWNTO 0);
      -- Address/Data Bus
    addr_hit                : IN std_logic;
    current_state           : OUT std_logic_vector(4 DOWNTO 0);
    din                     : IN std_logic_vector(7 DOWNTO 0);
    lpc_data_in             : OUT std_logic_vector(7 DOWNTO 0);
    lpc_data_out            : OUT std_logic_vector(3 DOWNTO 0);
    lpc_addr                : OUT std_logic_vector(15 DOWNTO 0);
    lpc_en                  : OUT std_logic;
    io_rden_sm              : OUT std_logic;
    io_wren_sm              : OUT std_logic
  );
END ENTITY LPC_Peri;

ARCHITECTURE translated OF LPC_Peri IS
   --reg  [3:0] LAD;
  SIGNAL sync_en                  :  std_logic:='0';
  SIGNAL rd_addr_en               :  std_logic_vector(3 DOWNTO 0):="0000";
  SIGNAL wr_data_en               :  std_logic_vector(1 DOWNTO 0):="00";
  SIGNAL rd_data_en               :  std_logic_vector(1 DOWNTO 0):="00";
  SIGNAL tar_F                    :  std_logic:='0';
  SIGNAL next_state               :  std_logic_vector(4 DOWNTO 0):="00000";

  SIGNAL lpc_data_out_variable		 :  std_logic_vector(3 DOWNTO 0):="0000";
  SIGNAL current_state_variable   :  std_logic_vector(4 DOWNTO 0):="00000";
  SIGNAL lad_in_temp							 :  std_logic_vector(3 DOWNTO 0):="0000";
  signal lpc_addr_temp            :  std_logic_vector(15 DOWNTO 0):="0000000000000000";

   ---------------
   -- -------------------------------------------------------------------------
   -- FSM output logic - Control state machine - LPC I/O read & I/O write only
   -- -------------------------------------------------------------------------
   --
   ----------------------------------------------------------------------------

  Attribute Syn_keep :boolean;
  Attribute Syn_keep of tar_F : signal is True;

BEGIN
   -- --------------------------------------------------------------------------
   -- FSM -- state machine supporting LPC I/O read & I/O write only
   -- --------------------------------------------------------------------------
  lpc_data_out <= lpc_data_out_variable;
  current_state <= current_state_variable;
  lad_in <= lad_in_temp;
  lpc_addr<=lpc_addr_temp;
   --
  PROCESS (lclk, lreset_n)
  BEGIN
    IF (NOT lreset_n = '1') THEN
      current_state_variable <= "00000";
    ELSIF (lclk'EVENT AND lclk = '1') THEN
      current_state_variable <= next_state;
    END IF;
  END PROCESS;
   ---------
   ----------------
  next_state <= "00000" WHEN (lreset_n = '0') ELSE
                "00001" WHEN (((current_state_variable = "00000") AND (lframe_n = '0')) AND (lad_in = "0000")) ELSE
                "00001" WHEN (((current_state_variable = "00001") AND (lframe_n = '0')) AND (lad_in = "0000")) ELSE
                "00010" WHEN (((current_state_variable = "00001") AND (lframe_n = '1')) AND (lad_in = "0000")) ELSE
                "01101" WHEN (((current_state_variable = "00001") AND (lframe_n = '1')) AND (lad_in = "0010")) ELSE
                "00000" WHEN (lframe_n = '0') ELSE
                "00011" WHEN (current_state_variable = "00010") ELSE
                "00100" WHEN (current_state_variable = "00011") ELSE
                "00101" WHEN (current_state_variable = "00100") ELSE
                "00110" WHEN (current_state_variable = "00101") ELSE
                "00111" WHEN (current_state_variable = "00110") ELSE
                "01000" WHEN (current_state_variable = "00111") ELSE
                "00000" WHEN ((current_state_variable = "01000") AND (addr_hit = '0')) ELSE
                "01001" WHEN ((current_state_variable = "01000") AND (addr_hit = '1')) ELSE
                "01011" WHEN (current_state_variable = "01001") ELSE
                "01100" WHEN (current_state_variable = "01011") ELSE
                "10111" WHEN (current_state_variable = "01100") ELSE
                "01110" WHEN (current_state_variable = "01101") ELSE
                "01111" WHEN (current_state_variable = "01110") ELSE
                "10000" WHEN (current_state_variable = "01111") ELSE
                "10001" WHEN (current_state_variable = "10000") ELSE
                "10010" WHEN (current_state_variable = "10001") ELSE
                "10011" WHEN (current_state_variable = "10010") ELSE
                "10100" WHEN (current_state_variable = "10011") ELSE
                "10101" WHEN (current_state_variable = "10100") ELSE
                "00000" WHEN ((current_state_variable = "10101") AND (addr_hit = '0')) ELSE
                "10110" WHEN ((current_state_variable = "10101") AND (addr_hit = '1')) ELSE
                "11000" WHEN (current_state_variable = "10110") ELSE
                "11001" WHEN (current_state_variable = "11000") ELSE "00000";
   -------------------------
   -------------------------
   -------------------------
  tar_F <= '1' WHEN (next_state = "10111") ELSE '0';
   --
  sync_en <= '1' WHEN (next_state = "01001") ELSE
             '1' WHEN (next_state = "10110") ELSE '0';
   --
  rd_data_en <= "01" WHEN (next_state = "01011") ELSE
                "10" WHEN (next_state = "01100") ELSE "00";
   --
  wr_data_en <= "01" WHEN (next_state = "10010") ELSE
                "10" WHEN (next_state = "10011") ELSE "00" ;
   --
  io_rden_sm <= '1' WHEN (next_state = "00111") ELSE
                '1' WHEN (next_state = "01000") ELSE '0';
   --
  io_wren_sm <= '1' WHEN (next_state = "10100") ELSE
                '1' WHEN (next_state = "10101") ELSE '0' ;
----------------------------------
--
  lpc_addr_temp(15 downto 12)<=lad_in when rd_addr_en(3)='1' else lpc_addr_temp(15 downto 12);
  lpc_addr_temp(11 downto 8)<=lad_in when rd_addr_en(2)='1' else lpc_addr_temp(11 downto 8);
  lpc_addr_temp(7 downto 4)<=lad_in when rd_addr_en(1)='1' else lpc_addr_temp(7 downto 4);
  lpc_addr_temp(3 downto 0)<=lad_in when rd_addr_en(0)='1' else lpc_addr_temp(3 downto 0);

   --
   --Register Data In

  PROCESS (lclk)
  BEGIN   		 
    if (lclk'EVENT AND lclk = '1') then       		 			          
      if (wr_data_en(0) = '1') then
        lpc_data_in(3 DOWNTO 0) <= lad_in;
      end if;
            --
      if (wr_data_en(1) = '1') then
        lpc_data_in(7 DOWNTO 4) <= lad_in;
      end if;
       --LAD = (current_state == `IO_WR_SYNC) ? 4'b0000 : 4'bzzzz; // On the beginning of write sync, it should be assigned to 'sync success' (0)	
    end if;
  END PROCESS;
  --

  lad_in_temp<="0000" when current_state_variable="10110" else
               lpc_data_out_variable when rd_data_en(0)='1' else
               lpc_data_out_variable when rd_data_en(1)='1' else "ZZZZ" ;

  --
  -- Read Back-side Data to LPC

  lpc_data_out_variable<="0000" when sync_en='1' else
                         "1111" when tar_F = '1' else
                         "0000" when lframe_n = '0' else
                         din(3 downto 0) when rd_data_en(0) = '1' else
                         din(7 downto 4) when rd_data_en(1) = '1' else "0000";

  lpc_en<='1' when sync_en = '1' else
          '1' when tar_F = '1' else
          '0' when lframe_n = '0' else
          '1' when rd_data_en(0) = '1' else
          '1' when rd_data_en(1) = '1' else '0';



END ARCHITECTURE translated;
