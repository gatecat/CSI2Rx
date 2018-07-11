library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--Simple Test Square Generator
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

entity test_pattern_gen is
  generic(
    video_hlength : natural := 4046; --total visible and blanking pixels per line
    video_vlength : natural := 2190; --total visible and blanking lines per frame

    video_hsync_pol : boolean := true; --hsync polarity: true for positive sync, false for negative sync
    video_hsync_len : natural := 48; --horizontal sync length in pixels
    video_hbp_len : natural := 122; --horizontal back porch length (excluding sync)
    video_h_visible : natural := 3840; --number of visible pixels per line

    video_vsync_pol : boolean := true; --vsync polarity: true for positive sync, false for negative sync
    video_vsync_len : natural := 3; --vertical sync length in lines
    video_vbp_len : natural := 23; --vertical back porch length (excluding sync)
    video_v_visible : natural := 2160 --number of visible lines per frame
  );

  port(
    pixel_clock : in std_logic;
    reset : in std_logic; --active high async reset

    video_vsync : out std_logic;
    video_hsync : out std_logic;
    video_den : out std_logic;
    video_line_start : out std_logic;

    --2 pixel per clock output
    video_pixel_even : out std_logic_vector(23 downto 0);
    video_pixel_odd : out std_logic_vector(23 downto 0)
  );
end test_pattern_gen;

architecture Behavioral of test_pattern_gen is
  type pattern_colours_t is array(0 to 15) of std_logic_vector(23 downto 0);

  constant pattern_colours : pattern_colours_t := (x"FF0000", x"00FF00", x"0000FF", x"FFFFFF",
                                                   x"AA0000", x"00AA00", x"0000AA", x"AAAAAA",
                                                   x"550000", x"005500", x"000055", x"555555",
                                                   x"FFFF00", x"FF00FF", x"00FFFF", x"000000");


  signal pattern_index : unsigned(3 downto 0);
  signal pattern_value : std_logic_vector(23 downto 0);

  signal den_int : std_logic;
  signal pixel_x_div : natural range 0 to (video_h_visible / 2) - 1;
  signal pixel_x : natural range 0 to video_h_visible - 1;
  signal pixel_y : natural range 0 to video_v_visible - 1;


begin

  pixel_x <= pixel_x_div * 2;

  pattern_index(1 downto 0) <= to_unsigned(pixel_x, 14)(4 downto 3);
  pattern_index(3 downto 2) <= to_unsigned(pixel_y, 14)(4 downto 3);

  pattern_value <= pattern_colours(to_integer(pattern_index));

  video_pixel_even <= pattern_value when den_int = '1' else x"000000";
  video_pixel_odd <= pattern_value when den_int = '1' else x"000000";

  video_den <= den_int;

  tmg_gen : entity work.video_timing_ctrl
    generic map (
      video_hlength => video_hlength / 2, --divide by two because two pixels per clock
      video_vlength => video_vlength,

      video_hsync_pol => video_hsync_pol,
      video_hsync_len => video_hsync_len / 2,
      video_hbp_len => video_hbp_len / 2,
      video_h_visible => video_h_visible / 2,

      video_vsync_pol => video_vsync_pol,
      video_vsync_len => video_vsync_len,
      video_vbp_len => video_vbp_len,
      video_v_visible => video_v_visible)
    port map(
      pixel_clock => pixel_clock,
      reset => reset,
      ext_sync => '0',

      timing_h_pos => open,
      timing_v_pos => open,
      pixel_x => pixel_x_div,
      pixel_y => pixel_y,

      video_vsync => video_vsync,
      video_hsync => video_hsync,
      video_den => den_int,
      video_line_start => video_line_start);
end Behavioral;
