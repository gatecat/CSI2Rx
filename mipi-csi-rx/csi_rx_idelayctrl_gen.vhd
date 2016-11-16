library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VComponents.all;

--Core-specific IDELAYCTRL wrapper
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

entity csi_rx_idelayctrl_gen is
  generic(
    fpga_series : string := "7SERIES"
  );
  port(
    ref_clock : in std_logic; --IDELAYCTRL reference clock
    reset : in std_logic --IDELAYCTRL reset
  );
end csi_rx_idelayctrl_gen;

architecture Behavioral of csi_rx_idelayctrl_gen is
begin
  gen_v6_7s: if fpga_series = "VIRTEX6" or fpga_series = "7SERIES" generate
    delayctrl : IDELAYCTRL
      port map (
        RDY    => open,
        REFCLK => ref_clock,
        RST    => reset
      );
  end generate;
end architecture;
