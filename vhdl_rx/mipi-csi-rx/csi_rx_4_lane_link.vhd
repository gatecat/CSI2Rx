library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

--MIPI CSI-2 Rx 4 lane link layer
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

--This combines the clock and data PHYs; byte aligners and word aligner to
--form the lower levels of the CSI Rx link layer

entity csi_rx_4_lane_link is
  generic(
    fpga_series : string := "7SERIES";

    dphy_term_en : boolean := true;

    d0_invert : boolean := false;
    d1_invert : boolean := false;
    d2_invert : boolean := false;
    d3_invert : boolean := false;

    d0_skew : natural := 0;
    d1_skew : natural := 0;
    d2_skew : natural := 0;
    d3_skew : natural := 0;

    generate_idelayctrl : boolean := false
  );
  port(
    dphy_clk : in STD_LOGIC_VECTOR (1 downto 0); --clock lane (1 is P, 0 is N)
    dphy_d0 : in STD_LOGIC_VECTOR (1 downto 0); --data lanes (1 is P, 0 is N)
    dphy_d1 : in STD_LOGIC_VECTOR (1 downto 0);
    dphy_d2 : in STD_LOGIC_VECTOR (1 downto 0);
    dphy_d3 : in STD_LOGIC_VECTOR (1 downto 0);
    ref_clock : in STD_LOGIC; --reference clock for clock detection and IDELAYCTRLs (nominally ~200MHz)
    reset : in STD_LOGIC; --active high synchronous reset in
    enable : in STD_LOGIC; --active high enable out
    wait_for_sync : in STD_LOGIC; --sync wait signal from packet handler
    packet_done : in STD_LOGIC; --packet done signal from packet handler
    reset_out : out STD_LOGIC; --reset output based on clock detection
    word_clock : out STD_LOGIC; --divided word clock output
    word_data : out STD_LOGIC_VECTOR (31 downto 0); --aligned word data output
    word_valid : out STD_LOGIC --whether or not above data is synced and aligned
  );
end csi_rx_4_lane_link;

architecture Behavioral of csi_rx_4_lane_link is

  signal ddr_bit_clock : std_logic;
  signal ddr_bit_clock_b : std_logic;
  signal word_clock_int : std_logic;
  signal serdes_reset : std_logic;

  signal deser_data : std_logic_vector(31 downto 0);
  signal deser_data_rev : std_logic_vector(31 downto 0);

  signal byte_align_data : std_logic_vector(31 downto 0);
  signal byte_valid : std_logic_vector(3 downto 0);
  signal word_align_data : std_logic_vector(31 downto 0);

  signal byte_packet_done : std_logic;

begin

  clkphy : entity work.csi_rx_hs_clk_phy
    generic map(
      series => fpga_series,
      term_en => dphy_term_en)
    port map(
      dphy_clk => dphy_clk,
      reset => reset,
      ddr_bit_clock => ddr_bit_clock,
      ddr_bit_clock_b => ddr_bit_clock_b,
      byte_clock => word_clock_int);

  clkdet : entity work.csi_rx_clock_det
    port map(
      ref_clock => ref_clock,
      ext_clock => word_clock_int,
      enable => enable,
      reset_in => reset,
      reset_out => serdes_reset);


  d0phy : entity work.csi_rx_hs_lane_phy
    generic map(
      series => fpga_series,
      invert => d0_invert,
      term_en => dphy_term_en,
      delay => d0_skew)
    port map (
      ddr_bit_clock => ddr_bit_clock,
      ddr_bit_clock_b => ddr_bit_clock_b,
      byte_clock => word_clock_int,
      enable => enable,
      reset => serdes_reset,
      dphy_hs => dphy_d0,
      deser_out => deser_data(7 downto 0));

  d1phy : entity work.csi_rx_hs_lane_phy
    generic map(
      series => fpga_series,
      invert => d1_invert,
      term_en => dphy_term_en,
      delay => d1_skew)
    port map (
      ddr_bit_clock => ddr_bit_clock,
      ddr_bit_clock_b => ddr_bit_clock_b,
      byte_clock => word_clock_int,
      enable => enable,
      reset => serdes_reset,
      dphy_hs => dphy_d1,
      deser_out => deser_data(15 downto 8));

  d2phy : entity work.csi_rx_hs_lane_phy
    generic map(
      series => fpga_series,
      invert => d2_invert,
      term_en => dphy_term_en,
      delay => d2_skew)
    port map (
      ddr_bit_clock => ddr_bit_clock,
      ddr_bit_clock_b => ddr_bit_clock_b,
      byte_clock => word_clock_int,
      enable => enable,
      reset => serdes_reset,
      dphy_hs => dphy_d2,
      deser_out => deser_data(23 downto 16));

  d3phy : entity work.csi_rx_hs_lane_phy
    generic map(
      series => fpga_series,
      invert => d3_invert,
      term_en => dphy_term_en,
      delay => d3_skew)
    port map (
      ddr_bit_clock => ddr_bit_clock,
      ddr_bit_clock_b => ddr_bit_clock_b,
      byte_clock => word_clock_int,
      enable => enable,
      reset => serdes_reset,
      dphy_hs => dphy_d3,
      deser_out => deser_data(31 downto 24));

  gen_bytealign : for i in 0 to 3 generate
      ba : entity work.csi_rx_byte_align
            port map (
              clock => word_clock_int,
              reset => serdes_reset,
              enable => enable,
              deser_in => deser_data((8*i) + 7 downto 8 * i),
              wait_for_sync => wait_for_sync,
              packet_done => byte_packet_done,
              valid_data => byte_valid(i),
              data_out => byte_align_data((8*i) + 7 downto 8 * i));
  end generate;

  wordalign : entity work.csi_rx_word_align
    port map (
      word_clock => word_clock_int,
      reset => serdes_reset,
      enable => enable,
      packet_done => packet_done,
      wait_for_sync => wait_for_sync,
      packet_done_out => byte_packet_done,
      word_in => byte_align_data,
      valid_in => byte_valid,
      word_out => word_align_data,
      valid_out => word_valid);

  word_clock <= word_clock_int;
  word_data <= word_align_data;
  reset_out <= serdes_reset;

  gen_idctl : if generate_idelayctrl generate
    idctrl : entity work.csi_rx_idelayctrl_gen
      port map(
        ref_clock => ref_clock,
        reset => reset);
  end generate;
end Behavioral;
