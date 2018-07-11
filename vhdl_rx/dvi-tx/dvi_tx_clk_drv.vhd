library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VComponents.all;

--DVI Transmitter clock lane driver
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

--This drives the TMDS clock lane, taking the pixel clock as input
entity dvi_tx_clk_drv is
  port(
    pixel_clock : in std_logic;
    tmds_clk : out std_logic_vector(1 downto 0));
end dvi_tx_clk_drv;

architecture Behavioral of dvi_tx_clk_drv is
  signal tmds_clk_pre : std_logic;
begin
  --Using an ODDR simplifies clock routing and avoids the need for a clock capable output
  clk_oddr : ODDR
    generic map(
      DDR_CLK_EDGE => "OPPOSITE_EDGE",
      INIT => '0',
      SRTYPE => "SYNC")
    port map(
      Q => tmds_clk_pre,
      C => pixel_clock,
      CE => '1',
      D1 => '1',
      D2 => '0',
      R => '0',
      S => '0');

  clk_obuf : OBUFDS
    generic map (
      IOSTANDARD => "DEFAULT",
      SLEW => "FAST")
    port map (
      O => tmds_clk(1),
      OB => tmds_clk(0),
      I => tmds_clk_pre);
end Behavioral;
