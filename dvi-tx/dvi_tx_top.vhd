library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

--Simple DVI Transmitter for Xilinx 7-series devices
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

--This is a minimal DVI transmitter core designed for Xilinx 7-series devices
--and tested using the HDMI output the Digilent Genesys 2 board (Kintex-7 XC7K325T)

entity dvi_tx is
  port(
    pixel_clock : in std_logic; --pixel clock input
    ddr_bit_clock : in std_logic; --DDR bit clock i.e. pixel_clock*5 - must be from same MMCM/PLL as pixel_clock
    reset : in std_logic; --synchronous active high reset input
    den : in std_logic; --video data valid input (active high)
    hsync : in std_logic; --video hsync input (polarity is timing dependent)
    vsync : in std_logic; --video vsync input (polarity is timing dependent)
    pixel_data : in std_logic_vector(23 downto 0); --24-bit video data

    tmds_clk : out std_logic_vector(1 downto 0); --TMDS clock lane; 1 is P, 0 is N
    tmds_d0 : out std_logic_vector(1 downto 0); --TMDS data lanes; 1 is P, 0 is N
    tmds_d1 : out std_logic_vector(1 downto 0);
    tmds_d2 : out std_logic_vector(1 downto 0));
end dvi_tx;

architecture Behavioral of dvi_tx is
  signal ctrl : std_logic_vector(5 downto 0); --TMDS control signal states
  signal tmds_enc : std_logic_vector(29 downto 0); --TMDS encoded data

  type tmds_lanes_t is array (0 to 2) of std_logic_vector(1 downto 0);
  signal tmds_lanes : tmds_lanes_t;

begin
  ctrl(0) <= hsync;
  ctrl(1) <= vsync;
  ctrl(5 downto 2) <= "0000";

  gen_lane : for i in 0 to 2 generate
    lane_enc : entity work.dvi_tx_tmds_enc
      port map(
        clock => pixel_clock,
        reset => reset,
        den => den,
        data => pixel_data(((8*i) + 7) downto (8*i)),
        ctrl => ctrl(((2*i) + 1) downto (2*i)),
        tmds => tmds_enc( ((10*i) + 9) downto (10*i)));

    lane_phy : entity work.dvi_tx_tmds_phy
      port map(
        pixel_clock => pixel_clock,
        ddr_bit_clock => ddr_bit_clock,
        reset => reset,
        data => tmds_enc( ((10*i) + 9) downto (10*i)),
        tmds_lane => tmds_lanes(i));
  end generate;

  clock_phy : entity work.dvi_tx_clk_drv
    port map(
      pixel_clock => pixel_clock,
      tmds_clk => tmds_clk);

  tmds_d0 <= tmds_lanes(0);
  tmds_d1 <= tmds_lanes(1);
  tmds_d2 <= tmds_lanes(2);

end Behavioral;
