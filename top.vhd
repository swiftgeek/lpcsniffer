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
  lad : inout std_logic_vector(3 downto 0)
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

  signal lpc_state : std_logic_vector(4 downto 0);
  signal lpc_addr : std_logic_vector(15 downto 0);
  signal lpc_din : std_logic_vector(7 downto 0);
  signal lpc_dout : std_logic_vector(3 downto 0);
  signal lpc_en, io_rden_sm, io_wren_sm : std_logic;

  signal frame_n : std_logic;

  signal osc_12m_tgl, osc_pci_tgl : std_logic := '0';

begin

  frame_n <= not frame;

  --LED Mappings
  leds(0) <= osc_12m_tgl;
  leds(1) <= osc_pci_tgl;

  leds(2) <= not (lpc_en and (io_rden_sm or io_wren_sm));
  leds(7 downto 3) <= not lpc_state;

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
    if (rising_edge(pciclk)) then
      if (pcirst_n = '0') then
        osc_pci_tgl <= '0';
        cnt := 0;
      else
        if (cnt = (33*1000*1000/2-1)) then
          cnt := 0;
          osc_pci_tgl <= not osc_pci_tgl;
        else
          cnt := cnt + 1;
        end if;
      end if;
    end if;
  end process;

end architecture top_1;
