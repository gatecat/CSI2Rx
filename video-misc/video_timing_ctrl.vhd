library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--Flexible Video Timing Controller
--Copyright (C) 2016 David Shah
--Licensed under the MIT License


entity video_timing_ctrl is
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
    video_v_visible : natural := 1080; --number of visible lines per frame

    --H and V timing coordinates at rising edge of external sync input
    sync_v_pos : natural := 132;
    sync_h_pos : natural := 1079
  );

  port(
    pixel_clock : in std_logic;
    reset : in std_logic; --active high async reset

    --External sync input
    ext_sync : in std_logic;

    --Timing and pixel coordinate outputs
    timing_h_pos : out natural range 0 to video_hlength - 1;
    timing_v_pos : out natural range 0 to video_vlength - 1;
    pixel_x : out natural range 0 to video_h_visible - 1;
    pixel_y : out natural range 0 to video_v_visible - 1;

    --Traditional timing signals
    --line_start is like hsync but always active high and only asserted for visible lines and for 1 clock cycle
    video_vsync : out std_logic;
    video_hsync : out std_logic;
    video_den : out std_logic;
    video_line_start : out std_logic
  );
end video_timing_ctrl;

architecture Behavioral of video_timing_ctrl is
  constant t_hsync_end : natural := video_hsync_len - 1;
  constant t_hvis_begin : natural := video_hsync_len + video_hbp_len;
  constant t_hvis_end : natural := t_hvis_begin + video_h_visible - 1;

  constant t_vsync_end : natural := video_vsync_len - 1;
  constant t_vvis_begin : natural := video_vsync_len + video_vbp_len;
  constant t_vvis_end : natural := t_vvis_begin + video_v_visible - 1;

  signal h_pos : natural range 0 to video_hlength - 1;
  signal v_pos : natural range 0 to video_vlength - 1;

  signal x_int : natural range 0 to video_h_visible - 1;
  signal y_int : natural range 0 to video_h_visible - 1;

  signal h_visible, v_visible : std_logic;
  signal hsync_pos, vsync_pos : std_logic;

  signal ext_sync_last : std_logic;
  signal ext_sync_curr : std_logic;
begin
  --Basic counters
  process(pixel_clock, reset)
  begin
    if reset = '1' then
      h_pos <= 0;
      v_pos <= 0;
    elsif rising_edge(pixel_clock) then
      if ext_sync_curr = '1' and ext_sync_last = '0' then
        h_pos <= sync_h_pos;
        v_pos <= sync_v_pos;
      else
        if h_pos = video_hlength - 1 then
          h_pos <= 0;
          if v_pos = video_vlength - 1 then
            v_pos <= 0;
          else
            v_pos <= v_pos + 1;
          end if;
        else
          h_pos <= h_pos + 1;
        end if;
      end if;
      ext_sync_curr <= ext_sync;
      ext_sync_last <= ext_sync_curr;
    end if;
  end process;

  --Visible signals
  v_visible <= '1' when (v_pos >= t_vvis_begin) and (v_pos <= t_vvis_end) else '0';
  h_visible <= '1' when (h_pos >= t_hvis_begin) and (h_pos <= t_hvis_end) else '0';

  --Pixel coordinates
  x_int <= (h_pos - t_hvis_begin) when (h_visible = '1') and (v_visible = '1') else 0;
  y_int <= (v_pos - t_vvis_begin) when v_visible = '1' else 0;

  --den and line_start signals
  video_den <= h_visible and v_visible;
  video_line_start <= '1' when (v_visible = '1') and (h_pos = 0) else '0';

  --Sync signals
  vsync_pos <= '1' when v_pos <= t_vsync_end else '0';
  hsync_pos <= '1' when h_pos <= t_hsync_end else '0';
  video_vsync <= vsync_pos when video_vsync_pol else not vsync_pos;
  video_hsync <= hsync_pos when video_hsync_pol else not hsync_pos;

  --External outputs
  timing_h_pos <= h_pos;
  timing_v_pos <= v_pos;
  pixel_x <= x_int;
  pixel_y <= y_int;
end Behavioral;
