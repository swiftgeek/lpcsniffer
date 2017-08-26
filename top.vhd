---------------------------------------------------------------------------
-- Author   : Ali Lown <ali@lown.me.uk>
-- File          : top.vhd
--
-- Abstract :
--
---------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
use work.lpcDefs.all;

---------------------------------------------------------------------------
Entity top is
---------------------------------------------------------------------------
port
(
  --board features
  osc_12m : in std_logic;
  crest : in std_logic;
  leds : out std_logic_vector(7 downto 0);
  dips : in std_logic_vector(3 downto 0);

  --lpc header
  pciclk : in std_logic;
  frame  : in std_logic;
  pcirst_n : in std_logic;
  lad : inout std_logic_vector(3 downto 0);

  --UART
  rxd : in std_logic;
  txd : out std_logic
);
end entity;


---------------------------------------------------------------------------
Architecture top_1 of top is
---------------------------------------------------------------------------

  component lpcDecoder
    port (
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
  end component lpcDecoder;

  component uartTop
    port ( -- global signals
     clr : in  std_logic;                     -- global reset input
     clk : in  std_logic;                     -- global clock input
                                                    -- uart serial signals
     serIn  : in  std_logic;                     -- serial data input
     serOut : out std_logic;                     -- serial data output
                                                    -- transmit and receive internal interface signals
     txData    : in  std_logic_vector(7 downto 0);  -- data byte to transmit
     newTxData : in  std_logic;                     -- asserted to indicate that there is a new data byte for transmission
     txBusy    : out std_logic;                     -- signs that transmitter is busy
     rxData    : out std_logic_vector(7 downto 0);  -- data byte received
     newRxData : out std_logic;                     -- signs that a new byte was received
                                                    -- baud rate configuration register - see baudGen.vhd for details
     baudFreq  : in  std_logic_vector(11 downto 0); -- baud rate setting registers - see header description
     baudLimit : in  std_logic_vector(15 downto 0); -- baud rate setting registers - see header description
     baudClk   : out std_logic);                    -- 
  end component uartTop;

  signal osc_12m_tgl, osc_pci_tgl : std_logic := '0';

  signal ser_txd, ser_rxd : std_logic_vector(7 downto 0);
  signal ser_tx_valid, ser_rx_valid : std_logic;
  signal ser_busy, ser_busy_r : std_logic;

  type state_t is (st0_idle, st0_wait, st1_addr, st2_sep, st3_data, st4_lf);
  signal state : state_t;

  signal t_valid : std_logic;
  signal t_start : lpc_start_t;
  signal t_type  : lpc_type_t;
  signal t_addr  : std_logic_vector(15 downto 0);
  signal t_data  : std_logic_vector(7 downto 0);

  signal buf_addr : std_logic_vector(15 downto 0);
  signal buf_data : std_logic_vector(7 downto 0);
  signal buf_type : lpc_type_t;

  signal pcirst : std_logic;

  --extra sync on reset line to reduce external influence
  signal pcirst_n_r, pcirst_n_sync : std_logic;
  signal crst_n_r, crst_n_sync : std_logic;

  function nibble_to_hex (X : std_logic_vector(3 downto 0)) return std_logic_vector(7 downto 0) is
  begin
    if (unsigned(X) < 10) then
      --for X in to 9, ascii codes 0x30-0x39
      return std_logic_vector(unsigned'(x"30") + unsigned(X));
    else
    --for X in 10 to 15, ascii codes 0x41-0x46
      return std_logic_vector(unsigned'(x"41") + unsigned(X) - unsigned'(x"0a"));
    end if;
  end nibble_to_hex;

begin

  process (pciclk)
  begin
    if (rising_edge(pciclk)) then
      pcirst_n_r    <= pcirst_n;
      pcirst_n_sync <= pcirst_n_r;
    end if;
  end process;

  process (osc_12m)
  begin
    if (rising_edge(osc_12m)) then
      crst_n_r    <= crest;
      crst_n_sync <= crst_n_r;
    end if;
  end process;

  pcirst  <= not pcirst_n_sync;

  --LED Mappings
  leds(0) <= osc_12m_tgl;
  leds(1) <= osc_pci_tgl;

  leds(2) <= '0' when (t_valid = '1' and (t_type = IO_RD)) else '1';
  leds(3) <= '0' when (t_valid = '1' and (t_type = IO_WR)) else '1';

  leds(4) <= '1' when (state = st0_idle) else '0';

  leds(5) <= not crst_n_sync;

  leds(7 downto 6) <= "11";

  --LPC Peripheral
  lpc_per : lpcDecoder
  port map
  (
    --external
    lclk     => pciclk,
    lreset_n => pcirst_n_sync,
    lframe_n => frame,
    lad      => lad,

    --internal
    trans_valid => t_valid,
    trans_start => t_start,
    trans_type  => t_type,
    trans_addr  => t_addr,
    trans_data  => t_data
  );

  process (osc_12m, crst_n_sync)
    variable cnt : integer;
  begin
    if (crst_n_sync = '0') then
      cnt := 0;
      osc_12m_tgl <= '0';
    elsif (rising_edge(osc_12m)) then
      if (cnt = (12*1000*1000/2-1)) then
        cnt := 0;
        osc_12m_tgl <= not osc_12m_tgl;
      else
        cnt := cnt + 1;
      end if;
    end if;
  end process;

  process (pciclk, pcirst_n_sync, crst_n_sync)
    variable cnt : integer;
  begin
    if (pcirst_n_sync = '0' or crst_n_sync = '0') then
      osc_pci_tgl <= '0';
      cnt := 0;
    else
      if (rising_edge(pciclk)) then
        if (cnt = (33*1000*1000/2-1)) then
          cnt := 0;
          osc_pci_tgl <= not osc_pci_tgl;
        else
          cnt := cnt + 1;
        end if;
      end if;
    end if;
  end process;

  --UART Peripheral
  uart_per : uartTop
  port map
  (
    clr => pcirst,
    clk => pciclk,

    serIn  => rxd,
    serOut => txd,

    txData    => ser_txd,
    newTxData => ser_tx_valid,
    txBusy    => ser_busy,

    rxData    => ser_rxd,
    newRxData => ser_rx_valid,

    --for 115,200 from a 33MHz clock
    baudFreq  => x"180",
    baudLimit => x"195b",
    baudClk => open
  );

  process (pciclk, pcirst_n_sync, crst_n_sync)
    variable cnt : integer range 0 to 7;
  begin
    if (pcirst_n_sync = '0' or crst_n_sync = '0') then
      state <= st0_idle;

      ser_tx_valid <= '0';
      ser_txd      <= x"00";
      ser_busy_r   <= '0';

      cnt := 0;
    elsif (rising_edge(pciclk)) then
      ser_tx_valid <= '0';
      ser_busy_r   <= ser_busy;

      case (state) is
        when st0_idle =>
          if (t_valid and not ser_busy) then
            state <= st0_wait;

            buf_addr <= t_addr;
            buf_data <= t_data;
            buf_type <= t_type;

          end if;

        when st0_wait =>
          if (ser_busy and not ser_busy_r) then
            state <= st1_addr;
            cnt := 0;
          end if;

          if (not ser_busy) then
            ser_tx_valid <= '1';
            ser_txd      <= x"52" when buf_type = IO_RD else  --'R'
                            x"57" when buf_type = IO_WR else  --'W'
                            x"4d" when buf_type = MEM_RD else --'M'
                            x"4e" when buf_type = MEM_WR else --'N'
                            x"44" when buf_type = DMA_RD else --'D'
                            x"45" when buf_type = DMA_WR else --'E'
                            x"3f"; -- '?'
          end if;

        when st1_addr =>
          if (ser_busy and not ser_busy_r) then
            if (cnt = 3) then
              state <= st2_sep;
              cnt   := 0;
            else
              buf_addr(15 downto 4) <= buf_addr(11 downto 0);
              buf_addr(3 downto 0)  <= "0000";
              cnt := cnt + 1;
            end if;
          end if;

          if (not ser_busy) then
            ser_tx_valid <= '1';
            ser_txd      <= nibble_to_hex(buf_addr(15 downto 12));
          end if;

        when st2_sep =>
          if (ser_busy and not ser_busy_r) then
            state <= st3_data;
          end if;

          if (not ser_busy) then
            ser_tx_valid <= '1';
            ser_txd      <= x"20"; --' '
          end if;

        when st3_data =>
          if (ser_busy and not ser_busy_r) then
            if (cnt = 1) then
              state <= st4_lf;
              cnt   := 0;
            else
              buf_data(7 downto 4) <= buf_data(3 downto 0);
              buf_data(3 downto 0) <= "0000";
              cnt := cnt + 1;
            end if;
          end if;

          if (not ser_busy) then
            ser_tx_valid <= '1';
            ser_txd      <= nibble_to_hex(buf_data(7 downto 4));
          end if;

        when st4_lf =>
          if (ser_busy and not ser_busy_r) then
            state <= st0_idle;
          end if;

          if (not ser_busy) then
            ser_tx_valid <= '1';
            ser_txd      <= x"0a"; --'LF'
          end if;
      end case;
    end if;
  end process;
end architecture top_1;
