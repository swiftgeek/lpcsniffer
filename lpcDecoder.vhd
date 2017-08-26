---------------------------------------------------------------------------
-- Author   : Ali Lown <ali@lown.me.uk>
-- File          : lpcDecoder.vhd
--
-- Abstract : Implements LPC 1.0 transaction decoding
--
---------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

use work.lpcDefs.all;

---------------------------------------------------------------------------
Entity lpcDecoder is
---------------------------------------------------------------------------
port
(
  --LPC interface
  lclk     : in std_logic;
  lreset_n : in std_logic;
  lframe_n : in std_logic;
  lad      : inout std_logic_vector(3 downto 0);

  --Decoded interface
  trans_valid : out std_logic;
  trans_start : out lpc_start_t;
  trans_type  : out lpc_type_t;
  trans_addr  : out std_logic_vector(15 downto 0);
  trans_data  : out std_logic_vector(7 downto 0)
);
end entity;


---------------------------------------------------------------------------
Architecture lpcDecoder_1 of lpcDecoder is
---------------------------------------------------------------------------

  type state_t is (st_idle, st_type, st_size, st_tar, st_addr, st_channel, st_data);
  signal state : state_t;

  signal cnt : integer range 0 to 7;

begin

  --Follows spec 1.0 section 4.2.1.x
  process (all)
  begin
    if (lreset_n = '0') then
      state <= st_idle;
      trans_valid <= '0';
      trans_start <= UNKNOWN;
      trans_type  <= UNKNOWN;

      cnt <= 0;
    elsif (rising_edge(lclk)) then
      trans_valid <= '0';

      case (state) is
        --START 4.2.1.1
        when st_idle =>
          if (lframe_n = '0') then
            state <= st_type;
            case (lad) is
              when "0000" => trans_start <= TARGET;
              when "0010" => trans_start <= GRANT_BM0;
              when "0011" => trans_start <= GRANT_BM1;
              when others => trans_start <= UNKNOWN;
            end case;
          end if;

        --Cycle Type/Direction 4.2.1.2
        when st_type =>
          case (lad(3 downto 2)) is
            when "00" =>
              state      <= st_tar;
              trans_type <= IO_RD when lad(1) = '0' else IO_WR;
              cnt        <= 0;
            when "01" =>
              state      <= st_size;
              trans_type <= MEM_RD when lad(1) = '0' else MEM_WR;
            when "10" =>
              state      <= st_size;
              trans_type <= DMA_RD when lad(1) = '0' else DMA_WR;
            when others =>
              --invalid cycle value
              state <= st_idle;
          end case;

        --Size (MEM and DMA only) 4.2.1.3
        when st_size =>
          --TODO(al): implement 1, 2 or 4 byte decoding
          state <= st_idle;

        --Bus Turn-around allowance 4.2.1.4
        when st_tar =>
          cnt <= cnt + 1;
          if (cnt = 1) then
            state <= st_addr;
            cnt   <= 0;
          --TODO(al): if dma, skip address
          end if;

        --Address (IO and MEM only) 4.2.1.5
        when st_addr =>
          --shift in from bottom nibble
          trans_addr(3 downto 0)  <= lad;
          trans_addr(15 downto 4) <= trans_addr(11 downto 0);
          cnt <= cnt + 1;

          --Spec claims IO is 4 clocks, MEM is 8 clocks
          --Yet, observation suggests port 0x80 uses 2-clock addressing
          --TODO(al): revisit from further observation?
          if (cnt = 1) then
            state <= st_data;
            cnt   <= 0;
          end if;

        --Channel (DMA only) 4.2.1.6
        when st_channel =>
          --TODO(al): implemen
          state <= st_idle;

        --Data 4.2.1.7
        when st_data =>
          --shift in from top nibble
          trans_data(7 downto 4) <= lad;
          trans_data(3 downto 0) <= trans_data(7 downto 4);
          cnt <= cnt + 1;

          if (cnt = 1) then
            state       <= st_idle;
            trans_valid <= '1';
            cnt <= 0;
          end if;

      end case;
    end if;
  end process;

end architecture lpcDecoder_1;
