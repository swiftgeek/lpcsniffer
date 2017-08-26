---------------------------------------------------------------------------
-- Author   : Ali Lown <ali@lown.me.uk>
-- File          : lpcDefs.vhd
--
-- Abstract :
--
---------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

---------------------------------------------------------------------------
Package lpcDefs is
---------------------------------------------------------------------------

  type lpc_start_t is (UNKNOWN, TARGET, GRANT_BM0, GRANT_BM1);
  type lpc_type_t is (UNKNOWN, IO_RD, IO_WR, MEM_RD, MEM_WR, DMA_RD, DMA_WR);
end lpcDefs;
