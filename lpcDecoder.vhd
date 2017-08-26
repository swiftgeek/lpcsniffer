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
  trans_addr  : out std_logic_vector(31 downto 0);
  trans_data  : out std_logic_vector(7 downto 0)
);
end entity;


---------------------------------------------------------------------------
Architecture lpcDecoder_1 of lpcDecoder is
---------------------------------------------------------------------------

  type state_t is (st_idle, st_type, st_size, st_tar, st_addr, st_channel, st_data, st_resp);
  signal state : state_t;

  signal cnt : integer range 0 to 7;

  signal trans_is_io, trans_is_mem : std_logic;
  signal trans_is_rd, trans_is_wr : std_logic;

begin

  trans_is_io  <= '1' when (trans_type = IO_RD or trans_type = IO_WR) else '0';
  trans_is_mem <= '1' when (trans_type = MEM_RD or trans_type = MEM_WR) else '0';
  trans_is_rd  <= '1' when (trans_type = IO_RD or trans_type = MEM_RD) else '0';
  trans_is_wr  <= '1' when (trans_type = IO_WR or trans_type = MEM_WR) else '0';

  --Follows spec 1.0 section 4.2.1.x
  process (lclk, lreset_n)
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
              state      <= st_addr;
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
            state <= st_resp;
            cnt   <= 0;
          --TODO(al): if dma, skip address
          end if;

        --Address (IO and MEM only) 4.2.1.5
        when st_addr =>
          --shift in from bottom nibble
          trans_addr(3 downto 0)  <= lad;
          trans_addr(31 downto 4) <= trans_addr(27 downto 0);
          cnt <= cnt + 1;

          --Spec notes IO is 4 clocks, MEM is 8 clocks
          if ((trans_is_io = '1' and cnt = 3) or (trans_is_mem = '1' and cnt = 7)) then
            cnt <= 0;
            --clear unused top bits in IO space
            if (trans_is_io = '1') then
              trans_addr(31 downto 16) <= (others => '0');
            end if;

            if (trans_is_rd = '1') then
              state <= st_tar;
            elsif (trans_is_wr = '1') then
              state <= st_data;
            else
              state <= st_idle;
            end if;
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
            --TODO(al): should be several TAR/SYNC states after this being driven
            state       <= st_idle;
            trans_valid <= '1';
            cnt <= 0;
          end if;

        --Sync
        when st_resp =>
          case (lad) is
            when lpc_sync_complete =>
              state <= st_data;
            when lpc_sync_short | lpc_sync_long =>
              --TODO(al): implement better timeout?
              if (lframe_n = '0') then
                state <= st_idle;
              end if;
            when lpc_sync_error =>
            when others =>
              --error
              state <= st_idle;
          end case;

      end case;
    end if;
  end process;

end architecture lpcDecoder_1;
