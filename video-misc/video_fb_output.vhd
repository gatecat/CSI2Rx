library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--Framebuffer video output controller
--Copyright (C) 2016 David Shah
--Licensed under the MIT License


entity video_fb_output is
  generic(
    video_hlength : natural := 2200; --total visible and blanking pixels per line
    video_vlength : natural := 1125; --total visible and blanking lines per frame

    video_hsync_pol : boolean := true; --hsync polarity: true for positive sync, false for negative sync (does not affect framebuffer outputs)
    video_hsync_len : natural := 44; --horizontal sync length in pixels
    video_hbp_len : natural := 88; --horizontal back porch length (excluding sync)
    video_h_visible : natural := 1920; --number of visible pixels per line

    video_vsync_pol : boolean := true; --vsync polarity: true for positive sync, false for negative sync
    video_vsync_len : natural := 5; --vertical sync length in lines
    video_vbp_len : natural := 4; --vertical back porch length (excluding sync)
    video_v_visible : natural := 1080 --number of visible lines per frame

  );

  port(
    pixel_clock : in std_logic;
    reset : in std_logic; --active high async reset

    --Framebuffer controller interface
    fbc_vsync : out std_logic;
    fbc_data : in std_logic_vector(23 downto 0);

    --Output port timing signals
    --line_start is like hsync but always active high and only asserted for visible lines and for 1 clock cycle
    video_vsync : out std_logic;
    video_hsync : out std_logic;
    video_den : out std_logic;
    video_line_start : out std_logic;

    --Pixel output port
    video_data : out std_logic_vector(23 downto 0)
  );
end video_fb_output;

architecture Behavioral of video_fb_output is
  signal timing_v_pos : natural range 0 to video_vlength - 1;
  signal timing_h_pos : natural range 0 to video_hlength - 1;


  signal den_int : std_logic;
begin
  fbc_vsync <= '1' when timing_v_pos = 0 else '0';

  video_data <= fbc_data when den_int = '1' else x"000000";
  video_den <= den_int;

  tmg_gen : entity work.video_timing_ctrl
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
      video_v_visible => video_v_visible)
    port map(
      pixel_clock => pixel_clock,
      reset => reset,
      ext_sync => '0',

      timing_h_pos => timing_h_pos,
      timing_v_pos => timing_v_pos,
      pixel_x => open,
      pixel_y => open,

      video_vsync => video_vsync,
      video_hsync => video_hsync,
      video_den => den_int,
      video_line_start => video_line_start);
end Behavioral;
