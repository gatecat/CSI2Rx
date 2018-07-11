library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--MIPI CSI-2 Rx Video Output Controller
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

--This receives unpacked 10bit pixel data from the unpacker and framing signals from the packet handler,
--and writes it into a dual-port line buffer to cross it from the byte clock into the pixel clock domain
--It also generates all the necessary video output signals

entity csi_rx_video_output is
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
    video_v_visible : natural := 2160; --number of visible lines per frame

    pixels_per_clock : natural := 2  --Number of pixels per clock to output; 1, 2 or 4
  );
  port(
    output_clock : in std_logic; --Output pixel clock
    csi_byte_clock : in std_logic; --CSI byte clock

    enable : in std_logic; --system enable input
    reset : in std_logic; --synchronous active high reset input

    pixel_data_in : in std_logic_vector(39 downto 0); --Unpacked 10 bit data
    pixel_data_valid : in std_logic;

    csi_in_frame : in std_logic;
    csi_in_line : in std_logic;
    csi_vsync : in std_logic;

    video_valid : out std_logic; --goes high when valid frames are being received

    --Pixel data output
    video_hsync : out std_logic;
    video_vsync : out std_logic;
    video_den : out std_logic;
    video_line_start : out std_logic; --like hsync but asserted for one clock period only and only for visible lines
    video_odd_line : out std_logic; --LSB of y-coordinate for a downstream debayering block
    video_data : out std_logic_vector(((10 * pixels_per_clock) - 1) downto 0); --LSW is leftmost pixel
    video_prev_line_data : out std_logic_vector(((10 * pixels_per_clock) - 1) downto 0) --last line's data at this point, for a debayering block to use
  );
end csi_rx_video_output;

architecture Behavioral of csi_rx_video_output is
  signal csi_in_line_last, csi_in_frame_last, csi_odd_line, csi_frame_started : std_logic  := '0';
  signal video_fsync_pre, video_fsync : std_logic := '0';

  signal csi_x_pos : natural range 0 to video_h_visible - 1;

  constant output_width : natural := video_h_visible / pixels_per_clock;
  constant output_tmg_hlength : natural := video_hlength / pixels_per_clock;
  constant output_hvis_begin : natural := (video_hsync_len + video_hbp_len) / pixels_per_clock;

  signal output_timing_h : natural range 0 to output_tmg_hlength - 1;
  signal output_pixel_y : natural range 0 to video_v_visible - 1;

  signal linebuf_write_address : natural range 0 to video_h_visible / 4 - 1;
  signal linebuf_read_address : natural range 0 to output_width - 1;

  signal even_linebuf_wren, odd_linebuf_wren : std_logic := '0';
  signal even_linebuf_q, odd_linebuf_q : std_logic_vector(((10 * pixels_per_clock) - 1) downto 0);

  signal output_hsync, output_vsync, output_den, output_line_start, output_odd_line : std_logic;
  signal output_data, output_prev_line_data : std_logic_vector(((10 * pixels_per_clock) - 1) downto 0);
begin

  process(csi_byte_clock)
  begin
    if rising_edge(csi_byte_clock) then
      if reset = '1' then
        csi_in_line_last <= '0';
        csi_in_frame_last <= '0';
        csi_frame_started <= '0';
        csi_odd_line <= '1';
      elsif enable = '1' then

        csi_in_frame_last <= csi_in_frame;
        csi_in_line_last <= csi_in_line;

        if csi_in_frame_last = '0' and csi_in_frame = '1' then --Start of frame
          csi_x_pos <= 0;
          csi_odd_line <= '1';
          csi_frame_started <= '0';
        elsif csi_in_line_last = '0' and csi_in_line = '1' then --Start of line
          csi_x_pos <= 0;
          csi_odd_line <= not csi_odd_line;
          csi_frame_started <= '1';
        elsif pixel_data_valid = '1' then
          csi_x_pos <= csi_x_pos + 4;
        end if;

      end if;
    end if;
  end process;
  linebuf_write_address <= csi_x_pos / 4;
  even_linebuf_wren <= pixel_data_valid when csi_odd_line = '0' else '0';
  odd_linebuf_wren <= pixel_data_valid when csi_odd_line = '1' else '0';

  process(output_clock)
  begin
    if rising_edge(output_clock) then
      if reset = '1' then
        video_fsync_pre <= '0';
        video_fsync <= '0';
      elsif enable = '1' then
        video_fsync_pre <= csi_frame_started;
        video_fsync <= video_fsync_pre;

        --Register video output
        video_hsync <= output_hsync;
        video_vsync <= output_vsync;
        video_den <= output_den;
        video_line_start <= output_line_start;
        video_odd_line <= output_odd_line;
        video_data <= output_data;
        video_prev_line_data <= output_prev_line_data;
      end if;
    end if;
  end process;

  output_odd_line <= '1' when output_pixel_y mod 2 = 1 else '0';
  output_data <= odd_linebuf_q when output_odd_line = '1' else even_linebuf_q;
  output_prev_line_data <= even_linebuf_q when output_odd_line = '1' else odd_linebuf_q;
  linebuf_read_address <= (output_timing_h - (output_hvis_begin - 1)); -- the -1 accounts for the RAM read latency

  output_timing : entity work.video_timing_ctrl
    generic map(
      video_hlength => output_tmg_hlength,
      video_vlength => video_vlength,

      video_hsync_pol => video_hsync_pol,
      video_hsync_len => video_hsync_len / pixels_per_clock,
      video_hbp_len => video_hbp_len / pixels_per_clock,
      video_h_visible => video_h_visible / pixels_per_clock,

      video_vsync_pol => video_vsync_pol,
      video_vsync_len => video_vsync_len,
      video_vbp_len => video_vbp_len,
      video_v_visible => video_v_visible,

      sync_v_pos => (video_vbp_len + video_vsync_len - 1), --keep output 1 line behind input
      sync_h_pos => (output_tmg_hlength - 5)
    )
    port map(
      pixel_clock => output_clock,
      reset => reset,

      ext_sync => video_fsync,

      timing_h_pos => output_timing_h,
      timing_v_pos => open,
      pixel_x => open,
      pixel_y => output_pixel_y,

      video_vsync => output_vsync,
      video_hsync => output_hsync,
      video_den => output_den,
      video_line_start => output_line_start
    );


  even_linebuf : entity work.csi_rx_line_buffer
    generic map(
      line_width => video_h_visible,
      pixels_per_clock => pixels_per_clock
    )
    port map(
      write_clock => csi_byte_clock,
      write_addr => linebuf_write_address,
      write_data => pixel_data_in,
      write_en => even_linebuf_wren,

      read_clock => output_clock,
      read_addr => linebuf_read_address,
      read_q => even_linebuf_q
    );

  odd_linebuf : entity work.csi_rx_line_buffer
    generic map(
      line_width => video_h_visible,
      pixels_per_clock => pixels_per_clock
    )
    port map(
      write_clock => csi_byte_clock,
      write_addr => linebuf_write_address,
      write_data => pixel_data_in,
      write_en => odd_linebuf_wren,

      read_clock => output_clock,
      read_addr => linebuf_read_address,
      read_q => odd_linebuf_q
    );

  video_valid <= '1'; --not yet implemented
end Behavioral;
