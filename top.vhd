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

---------------------------------------------------------------------------
Entity top is
---------------------------------------------------------------------------
port
(
  --board features
  osc_12m : in std_logic;
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

  component LPC_Peri
    port (
    -- LPC Interface
    lclk : IN std_logic;
    -- Clock
    lreset_n : IN std_logic;
    -- Reset - Active Low (Same as PCI Reset)
    lframe_n : IN std_logic;
    -- Frame - Active Low
    lad_in : INOUT std_logic_vector(3 DOWNTO 0);
    -- Address/Data Bus
    addr_hit      : IN std_logic;
    current_state : OUT std_logic_vector(4 DOWNTO 0);
    din           : IN std_logic_vector(7 DOWNTO 0);
    lpc_data_in   : OUT std_logic_vector(7 DOWNTO 0);
    lpc_data_out  : OUT std_logic_vector(3 DOWNTO 0);
    lpc_addr      : OUT std_logic_vector(15 DOWNTO 0);
    lpc_en        : OUT std_logic;
    io_rden_sm    : OUT std_logic;
    io_wren_sm    : OUT std_logic
  );
  end component LPC_Peri;

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

  signal lpc_state : std_logic_vector(4 downto 0);
  signal lpc_addr : std_logic_vector(15 downto 0);
  signal lpc_din : std_logic_vector(7 downto 0);
  signal lpc_dout : std_logic_vector(3 downto 0);
  signal lpc_en, io_rden_sm, io_wren_sm : std_logic;

  signal frame_n : std_logic;

  signal osc_12m_tgl, osc_pci_tgl : std_logic := '0';

  signal ser_txd, ser_rxd : std_logic_vector(7 downto 0);
  signal ser_tx_valid, ser_rx_valid : std_logic;
  signal ser_busy : std_logic;

  type state_t is (st0_idle, st1_type, st2_d0, st3_d1, st4_lf);
  signal state : state_t;

  signal buf_addr : std_logic_vector(15 downto 0);
  signal buf_din : std_logic_vector(7 downto 0);
  signal buf_rd, buf_wr : std_logic;

  signal pcirst : std_logic;

begin

  frame_n <= not frame;
  pcirst  <= not pcirst_n;

  --LED Mappings
  leds(0) <= osc_12m_tgl;
  leds(1) <= osc_pci_tgl;

  leds(2) <= not (lpc_en and (io_rden_sm or io_wren_sm));
  leds(3) <= '1' when (lpc_state = b"00000") else '0';

  leds(4) <= '1' when (state = st0_idle) else '0';

  leds(7 downto 5) <= "101";

  --LPC Peripheral
  lpc_per : LPC_Peri
  port map
  (
    --external
    lclk     => pciclk,
    lreset_n => pcirst_n,
    lframe_n => frame,
    lad_in   => lad,

    --internal
    addr_hit => '0',
    current_state => lpc_state,
    din => x"00",
    lpc_data_in => lpc_din,
    lpc_data_out => lpc_dout,
    lpc_addr => lpc_addr,
    lpc_en => lpc_en,
    io_rden_sm => io_rden_sm,
    io_wren_sm => io_wren_sm
  );

  process (osc_12m)
    variable cnt : integer;
  begin
    if (rising_edge(osc_12m)) then
      if (cnt = (12*1000*1000/2-1)) then
        cnt := 0;
        osc_12m_tgl <= not osc_12m_tgl;
      else
        cnt := cnt + 1;
      end if;
    end if;
  end process;

  process (pciclk, pcirst_n)
    variable cnt : integer;
  begin
    if (pcirst_n = '0') then
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

  process (pciclk, pcirst_n)
  begin
    if (pcirst_n = '0') then
      state <= st0_idle;

      ser_tx_valid <= '0';
      ser_txd      <= x"00";
    else
      if (rising_edge(pciclk)) then
        ser_tx_valid <= '0';

        if (not ser_busy) then
          case (state) is
            when st0_idle =>
              if (lpc_en) then
                state <= st1_type;

                buf_addr <= lpc_addr;
                buf_din  <= lpc_din;
                buf_rd   <= io_rden_sm;
                buf_wr   <= io_wren_sm;

                ser_tx_valid <= '1';
                ser_txd      <= x"52" when io_rden_sm = '1' else --'R'
                                x"54" when io_wren_sm = '1' else --'W'
                                x"3f"; -- '?'
              end if;
            when st1_type =>
              state <= st2_d0;

              ser_tx_valid <= '1';
              ser_txd      <= buf_addr(15 downto 8);
            when st2_d0 =>
              state <= st3_d1;

              ser_tx_valid <= '1';
              ser_txd      <= buf_addr(7 downto 0);
            when st3_d1 =>
              state <= st4_lf;

              ser_tx_valid <= '1';
              ser_txd      <= buf_din;
            when st4_lf =>
              state <= st0_idle;

              ser_tx_valid <= '1';
              ser_txd      <= x"0a"; --'LF'
          end case;
        end if;
      end if;
    end if;
  end process;

end architecture top_1;
