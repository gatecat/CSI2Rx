library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--VHDL MIPI CSI-2 Rx designed for Xilinx 7-series FPGAs
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

--This driver is designed for 4 lane links and has been tested with the Omnivison OV13850
--It supports resolutions up to 4k at 30fps (higher has not been tested but may work) with
--10-bit Bayer data (support for other output formats is not yet implemented). This is output
--in traditional parallel video format with a few tweaks

--For improved timing performance up to 4 pixels per clock can be output. For the ease of debayering blocks,
--the previous line's data; and whether the current line is even (BGBG) or odd (GRGR) is also output.

--At minimum you will need to provide it with suitable clocks from a PLL (the pixel clock input
--should in general either be phase locked to the master clock input to the camera or the CSI byte clock)
--and configure skew parameters and video port timings for your camera setup

--The primary testing platform is a Digilent Genesys 2 (Kintex-7 XC7K325T) with a
--custom FMC breakout board to connect two Firefly OV13850 modules.
--A previous version has also been tested on a ML605 Virtex-6 development board;
--however functioning support is not guaranteed

entity csi_rx_4lane is
  generic (
    --FPGA series to control SERDES/buffer generation
    --either "VIRTEX6" or "7SERIES"
    fpga_series : string := "7SERIES";

    --Low-level PHY parameters

    dphy_term_en : boolean := true; --Enable internal termination on all pairs

    --Use these to invert channels if needed on your PCB
    d0_invert : boolean := false;
    d1_invert : boolean := false;
    d2_invert : boolean := false;
    d3_invert : boolean := false;

    --These skew values are the delay settings for the IDELAYs on each lane
    --Adjust these for optimum stability with your PCB layout and cameras
    d0_skew : natural := 0;
    d1_skew : natural := 0;
    d2_skew : natural := 0;
    d3_skew : natural := 0;

    --Output port pixel timings (for included OV13850 config at 23.98fps with MCLK 24.399MHz and output clock 145Mz)
    video_hlength : natural := 4041; --total visible and blanking pixels per line
    video_vlength : natural := 2992; --total visible and blanking lines per frame

    video_hsync_pol : boolean := true; --hsync polarity: true for positive sync, false for negative sync
    video_hsync_len : natural := 48; --horizontal sync length in pixels
    video_hbp_len : natural := 122; --horizontal back porch length (excluding sync)
    video_h_visible : natural := 3840; --number of visible pixels per line

    video_vsync_pol : boolean := true; --vsync polarity: true for positive sync, false for negative sync
    video_vsync_len : natural := 3; --vertical sync length in lines
    video_vbp_len : natural := 23; --vertical back porch length (excluding sync)
    video_v_visible : natural := 2160; --number of visible lines per frame

    pixels_per_clock : natural := 2;  --Number of pixels per clock to output; 1, 2 or 4


    --Set this to false if this is not the first CSI rx or other IDELAY using device in the system
    generate_idelayctrl : boolean := false

  );
  port(
    ref_clock_in : in std_logic; --IDELAY reference clock (nominally 200MHz)
    pixel_clock_in : in std_logic; --Output pixel clock from PLL
    byte_clock_out : out std_logic; --DSI byte clock output

    enable : in std_logic; --system enable input
    reset : in std_logic; --synchronous active high reset input

    video_valid : out std_logic; --goes high when valid frames are being received

    --DSI signals, signal 1 is P and signal 0 is N
    dphy_clk : in std_logic_vector(1 downto 0);
    dphy_d0 : in std_logic_vector(1 downto 0);
    dphy_d1 : in std_logic_vector(1 downto 0);
    dphy_d2 : in std_logic_vector(1 downto 0);
    dphy_d3 : in std_logic_vector(1 downto 0);

    --Pixel data output
    video_hsync : out std_logic;
    video_vsync : out std_logic;
    video_den : out std_logic;
    video_line_start : out std_logic; --like hsync but asserted for one clock period only and only for visible lines
    video_odd_line : out std_logic; --LSB of y-coordinate for a downstream debayering block
    video_data : out std_logic_vector(((10 * pixels_per_clock) - 1) downto 0); --LSW is leftmost pixel
    video_prev_line_data : out std_logic_vector(((10 * pixels_per_clock) - 1) downto 0) --last line's data at this point, for a debayering block to use
  );
end csi_rx_4lane;

architecture Behavioral of csi_rx_4lane is
  signal csi_byte_clock : std_logic;
  signal link_reset_out : std_logic;
  signal wait_for_sync : std_logic;
  signal packet_done : std_logic;
  signal word_clock : std_logic;
  signal word_data : std_logic_vector(31 downto 0);
  signal word_valid : std_logic;

  signal packet_payload : std_logic_vector(31 downto 0);
  signal packet_payload_valid : std_logic;
  signal csi_vsync : std_logic;
  signal csi_in_frame, csi_in_line : std_logic;

  signal unpack_data : std_logic_vector(39 downto 0);
  signal unpack_data_valid : std_logic;
begin
  link : entity work.csi_rx_4_lane_link
    generic map(
      fpga_series => fpga_series,
      dphy_term_en => dphy_term_en,
      d0_invert => d0_invert,
      d1_invert => d1_invert,
      d2_invert => d2_invert,
      d3_invert => d3_invert,
      d0_skew => d0_skew,
      d1_skew => d1_skew,
      d2_skew => d2_skew,
      d3_skew => d3_skew,
      generate_idelayctrl => generate_idelayctrl)
    port map(
      dphy_clk => dphy_clk,
      dphy_d0 => dphy_d0,
      dphy_d1 => dphy_d1,
      dphy_d2 => dphy_d2,
      dphy_d3 => dphy_d3,
      ref_clock => ref_clock_in,
      reset => reset,
      enable => enable,
      wait_for_sync => wait_for_sync,
      packet_done => packet_done,
      reset_out => link_reset_out,
      word_clock => csi_byte_clock,
      word_data => word_data,
      word_valid => word_valid);

  depacket : entity work.csi_rx_packet_handler
    port map (
      clock => csi_byte_clock,
      reset => link_reset_out,
      enable => enable,
      data => word_data,
      data_valid => word_valid,
      sync_wait => wait_for_sync,
      packet_done => packet_done,
      payload_out => packet_payload,
      payload_valid => packet_payload_valid,
      vsync_out => csi_vsync,
      in_frame => csi_in_frame,
      in_line => csi_in_line);

  unpack10 : entity work.csi_rx_10bit_unpack
    port map (
      clock => csi_byte_clock,
      reset => link_reset_out,
      enable => enable,
      data_in => packet_payload,
      din_valid => packet_payload_valid,
      data_out => unpack_data,
      dout_valid => unpack_data_valid);

  vout : entity work.csi_rx_video_output
    generic map (
      video_hlength => video_hlength,
      video_vlength => video_vlength,
      video_hsync_pol => video_hsync_pol,
      video_hsync_len => video_hsync_len,
      video_hbp_len => video_hbp_len,
      video_h_visible => video_h_visible,
      video_vsync_pol => video_vsync_pol,
      video_vsync_len => video_vsync_len,
      video_vbp_len => video_vbp_len,
      video_v_visible => video_v_visible,
      pixels_per_clock => pixels_per_clock)
    port map (
      output_clock => pixel_clock_in,
      csi_byte_clock => csi_byte_clock,
      enable => enable,
      reset => reset,
      pixel_data_in => unpack_data,
      pixel_data_valid => unpack_data_valid,
      csi_in_frame => csi_in_frame,
      csi_in_line => csi_in_line,
      csi_vsync => csi_vsync,
      video_valid => video_valid,
      video_hsync => video_hsync,
      video_vsync => video_vsync,
      video_den => video_den,
      video_line_start => video_line_start,
      video_odd_line => video_odd_line,
      video_data => video_data,
      video_prev_line_data => video_prev_line_data
    );

  byte_clock_out <= csi_byte_clock;
end Behavioral;
