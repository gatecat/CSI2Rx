library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VComponents.all;

--DVI Transmitter TMDS PHY for Xilinx 7-series devices
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

--This handles the actual serialisation and transmission of 10bit encoded
--TMDS data

entity dvi_tx_tmds_phy is
  port(
    pixel_clock : in std_logic; --DVI pixel clock in
    ddr_bit_clock : in std_logic; --DDR bit clock i.e. pixel_clock*5 - must be from same MMCM/PLL as pixel_clock
    reset : in std_logic; --SERDES reset input
    data : in std_logic_vector(9 downto 0);
    tmds_lane : out std_logic_vector(1 downto 0) --1 is P, 0 is N
  );
end dvi_tx_tmds_phy;

architecture Behavioral of dvi_tx_tmds_phy is
  signal reset_lat : std_logic; --reset latched to pixel clock
  signal shift_1, shift_2 : std_logic; --used to link master and slave OSERDES
  signal data_se : std_logic; --serialised data before output buffer
begin
  process(pixel_clock)
  begin
    if rising_edge(pixel_clock) then
      reset_lat <= reset;
    end if;
  end process;

  master_oserdes : OSERDESE2
    generic map(
      DATA_RATE_OQ => "DDR",
      DATA_RATE_TQ => "SDR",
      DATA_WIDTH => 10,
      INIT_OQ => '0',
      INIT_TQ => '0',
      SERDES_MODE => "MASTER",
      SRVAL_OQ => '0',
      SRVAL_TQ => '0',
      TBYTE_CTL => "FALSE",
      TBYTE_SRC => "FALSE",
      TRISTATE_WIDTH => 1)
    port map(
      CLK => ddr_bit_clock,
      CLKDIV => pixel_clock,
      D1 => data(0),
      D2 => data(1),
      D3 => data(2),
      D4 => data(3),
      D5 => data(4),
      D6 => data(5),
      D7 => data(6),
      D8 => data(7),
      OCE => '1',
      OFB => open,
      OQ => data_se,
      RST => reset_lat,
      SHIFTIN1 => shift_1,
      SHIFTIN2 => shift_2,
      SHIFTOUT1 => open,
      SHIFTOUT2 => open,
      TBYTEIN => '0',
      TCE => '1',
      TFB => open,
      TQ => open,
      T1 => '0',
      T2 => '0',
      T3 => '0',
      T4 => '0');

  slave_oserdes : OSERDESE2
    generic map(
      DATA_RATE_OQ => "DDR",
      DATA_RATE_TQ => "SDR",
      DATA_WIDTH => 10,
      INIT_OQ => '0',
      INIT_TQ => '0',
      SERDES_MODE => "SLAVE",
      SRVAL_OQ => '0',
      SRVAL_TQ => '0',
      TBYTE_CTL => "FALSE",
      TBYTE_SRC => "FALSE",
      TRISTATE_WIDTH => 1)
    port map(
      CLK => ddr_bit_clock,
      CLKDIV => pixel_clock,
      D1 => '0',
      D2 => '0',
      D3 => data(8),
      D4 => data(9),
      D5 => '0',
      D6 => '0',
      D7 => '0',
      D8 => '0',
      OCE => '1',
      OFB => open,
      OQ => open,
      RST => reset_lat,
      SHIFTIN1 => '0',
      SHIFTIN2 => '0',
      SHIFTOUT1 => shift_1,
      SHIFTOUT2 => shift_2,
      TBYTEIN => '0',
      TCE => '1',
      TFB => open,
      TQ => open,
      T1 => '0',
      T2 => '0',
      T3 => '0',
      T4 => '0');

  outbuf : OBUFDS
    generic map (
      IOSTANDARD => "DEFAULT",
      SLEW => "FAST")
    port map (
      O => tmds_lane(1),
      OB => tmds_lane(0),
      I => data_se);
end Behavioral;
