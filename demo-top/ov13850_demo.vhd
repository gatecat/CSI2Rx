library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

--OV13850 Demo Top Level Design
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

entity ov13850_demo is
  Port (
    clock_p : in std_logic;
    clock_n : in std_logic;
    reset_n : in std_logic;

    hdmi_clk : out std_logic_vector(1 downto 0);
    hdmi_d0 : out std_logic_vector(1 downto 0);
    hdmi_d1 : out std_logic_vector(1 downto 0);
    hdmi_d2 : out std_logic_vector(1 downto 0);
    
    vga_hsync : out std_logic;
    vga_vsync : out std_logic;
    vga_r : out std_logic_vector(4 downto 0);
    vga_g : out std_logic_vector(5 downto 0);
    vga_b : out std_logic_vector(4 downto 0);

    zoom_mode : in std_logic;
    freeze : in std_logic;

    --Camera CSI port
    csi0_clk : in std_logic_vector(1 downto 0);
    csi0_d0 : in std_logic_vector(1 downto 0);
    csi0_d1 : in std_logic_vector(1 downto 0);
    csi0_d2 : in std_logic_vector(1 downto 0);
    csi0_d3 : in std_logic_vector(1 downto 0);

    --Camera control port
    cam_mclk : out std_logic;
    cam_rstn : out std_logic;
    cam_i2c_sda : inout std_logic;
    cam_i2c_sck : inout std_logic;

   --DDR3 interface
    ddr3_addr : out std_logic_vector(14 downto 0);
    ddr3_ba : out std_logic_vector(2 downto 0);
    ddr3_cas_n : out std_logic;
    ddr3_ck_n : out std_logic_vector(0 downto 0);
    ddr3_ck_p : out std_logic_vector(0 downto 0);
    ddr3_cke : out std_logic_vector(0 downto 0);
    ddr3_ras_n : out std_logic;
    ddr3_reset_n : out std_logic;
    ddr3_we_n : out std_logic;
    ddr3_dq : inout std_logic_vector(31 downto 0);
    ddr3_dqs_n : inout std_logic_vector(3 downto 0);
    ddr3_dqs_p : inout std_logic_vector(3 downto 0);
    ddr3_cs_n : out std_logic_vector(0 downto 0);
    ddr3_dm : out std_logic_vector(3 downto 0);
    ddr3_odt : out std_logic_vector(0 downto 0)
  );
end ov13850_demo;

architecture Behavioral of ov13850_demo is

  signal sys_clock : std_logic;

  signal reset : std_logic;
  signal dvi_pixel_clock, dvi_bit_clock : std_logic;

  signal dvi_data : std_logic_vector(23 downto 0);
  signal dvi_den, dvi_hsync, dvi_vsync : std_logic;

  signal i2c_clk_in, i2c_clk_div_1, i2c_clk_div : std_logic;
  signal cam_loading, csi_en, csi_rst : std_logic;

  signal camera_rstn_int : std_logic;
  signal input_pixel_clock : std_logic;

  signal camera_line_start, camera_den, camera_hsync, camera_vsync, camera_odd_line : std_logic;
  signal camera_data, camera_prev_line_data : std_logic_vector(19 downto 0);

  signal debayer_line_start, debayer_den, debayer_hsync, debayer_vsync : std_logic;
  signal debayer_data_even, debayer_data_odd : std_logic_vector(29 downto 0);

  signal fbin_line_start, fbin_den, fbin_hsync, fbin_vsync : std_logic;
  signal fbin_data_even, fbin_data_odd : std_logic_vector(23 downto 0);

  component dvi_pll is
    port(
      sysclk : in std_logic;
      pixel_clock : out std_logic;
      dvi_bit_clock : out std_logic);
  end component;

  component camera_pll is
    port(
      sysclk : in std_logic;
      camera_pixel_clock : out std_logic;
      camera_mclk : out std_logic;
      i2c_clkin : out std_logic);
  end component;


begin
    reset <= not reset_n;

    clkbuf : IBUFGDS
    generic map(
        DIFF_TERM => TRUE,
        IBUF_LOW_PWR => FALSE,
        IOSTANDARD => "DEFAULT")
    port map(
        O => sys_clock,
        I => clock_p,
        IB => clock_n);

    pll1 : dvi_pll
    port map(
        sysclk => sys_clock,
        pixel_clock => dvi_pixel_clock,
        dvi_bit_clock => dvi_bit_clock
    );

    pll2 : camera_pll
    port map(
        sysclk => sys_clock,
        camera_pixel_clock => input_pixel_clock,
        camera_mclk => cam_mclk,
        i2c_clkin => i2c_clk_in
    );

    --Divide 5MHz from PLL to slower I2C/reset controller input clock
    i2c_clkdiv : BUFR
      generic map(
        BUFR_DIVIDE => "8",
        SIM_DEVICE => "7SERIES")
      port map(
        O => i2c_clk_div_1,
        CE => '1',
        CLR => reset,
        I => i2c_clk_in);

    i2c_clkdiv2 : BUFR
      generic map(
        BUFR_DIVIDE => "4",
        SIM_DEVICE => "7SERIES")
      port map(
        O => i2c_clk_div,
        CE => '1',
        CLR => reset,
        I => i2c_clk_div_1);

    cam_ctl : entity work.ov13850_control_top
      port map (
        reset => reset,
        clock => i2c_clk_div,
        i2c_sda => cam_i2c_sda,
        i2c_sck => cam_i2c_sck,
        rst_out => camera_rstn_int,
        loading_out => cam_loading);

    cam_rstn <= camera_rstn_int;
    csi_rst <= not camera_rstn_int;
    csi_en <= not cam_loading;

    csi_rx : entity work.csi_rx_4lane
      generic map(
        fpga_series => "7SERIES",
        dphy_term_en => true,
        d0_invert => false,
        d1_invert => false,
        d2_invert => false,
        d3_invert => false,
        d0_skew => 10,
        d1_skew => 10,
        d2_skew => 10,
        d3_skew => 10,
        video_hlength =>  4041,
        video_vlength => 2992,
        video_hsync_pol => true,
        video_hsync_len => 48,
        video_hbp_len => 122,
        video_h_visible => 3840,
        video_vsync_pol => true,
        video_vsync_len => 3,
        video_vbp_len => 23 ,
        video_v_visible => 2160,
        pixels_per_clock => 2,
        generate_idelayctrl => true)
      port map(
        ref_clock_in => sys_clock,
        pixel_clock_in => input_pixel_clock,
        byte_clock_out => open,
        enable => csi_en,
        reset => csi_rst,
        video_valid => open,

        dphy_clk => csi0_clk,
        dphy_d0 => csi0_d0,
        dphy_d1 => csi0_d1,
        dphy_d2 => csi0_d2,
        dphy_d3 => csi0_d3,

        video_hsync => camera_hsync,
        video_vsync => camera_vsync,
        video_den => camera_den,
        video_line_start => camera_line_start,
        video_odd_line => camera_odd_line,
        video_data => camera_data,
        video_prev_line_data => camera_prev_line_data);

    db : entity work.simple_debayer
      port map(
        clock => input_pixel_clock,
        input_vsync => camera_vsync,
        input_hsync => camera_hsync,
        input_den => camera_den,
        input_odd_line => camera_odd_line,
        input_line_start => camera_line_start,
        input_data => camera_data,
        input_prev_line_data => camera_prev_line_data,
       
        output_vsync => debayer_vsync,
        output_hsync => debayer_hsync,
        output_den => debayer_den,
        output_line_start => debayer_line_start,
        output_data_even => debayer_data_even,
        output_data_odd => debayer_data_odd);

    wb : entity work.image_gain_wb
      generic map(
        red_gain => 10,
        green_gain => 7,
        blue_gain => 9)
      port map(
        clock => input_pixel_clock,
        input_vsync => debayer_vsync,
        input_hsync => debayer_hsync,
        input_den => debayer_den,
        input_line_start => debayer_line_start,
        input_data_even => debayer_data_even,
        input_data_odd => debayer_data_odd,
        
        output_vsync => fbin_vsync,
        output_hsync => fbin_hsync,
        output_den => fbin_den,
        output_line_start => fbin_line_start,
        output_data_even => fbin_data_even,
        output_data_odd => fbin_data_odd);

    fbtest : entity work.framebuffer_top
      port map(
        input_pixck => input_pixel_clock,
        input_vsync => fbin_vsync,
        input_line_start => fbin_line_start,
        input_den => fbin_den,
        input_data_even => fbin_data_even,
        input_data_odd => fbin_data_odd,

        system_clock => sys_clock,
        system_reset => reset,
        zoom_mode => zoom_mode,
        freeze => freeze,

        output_pixck => dvi_pixel_clock,
        output_vsync => dvi_vsync,
        output_hsync => dvi_hsync,
        output_den => dvi_den,
        output_line_start  => open,
        output_data => dvi_data,

        --DDR3 interface
        ddr3_addr => ddr3_addr,
        ddr3_ba => ddr3_ba,
        ddr3_cas_n => ddr3_cas_n,
        ddr3_ck_n => ddr3_ck_n,
        ddr3_ck_p => ddr3_ck_p,
        ddr3_cke => ddr3_cke,
        ddr3_ras_n => ddr3_ras_n,
        ddr3_reset_n => ddr3_reset_n,
        ddr3_we_n => ddr3_we_n,
        ddr3_dq => ddr3_dq,
        ddr3_dqs_n => ddr3_dqs_n,
        ddr3_dqs_p => ddr3_dqs_p,
        ddr3_cs_n => ddr3_cs_n,
        ddr3_dm => ddr3_dm,
        ddr3_odt => ddr3_odt
     );

    dvi_tx : entity work.dvi_tx
      port map(
          pixel_clock => dvi_pixel_clock,
          ddr_bit_clock => dvi_bit_clock,
          reset => reset,
          den => dvi_den,
          hsync => dvi_hsync,
          vsync => dvi_vsync,
          pixel_data => dvi_data,

          tmds_clk => hdmi_clk,
          tmds_d0 => hdmi_d0,
          tmds_d1 => hdmi_d1,
          tmds_d2 => hdmi_d2
      );
      
    vga_hsync <= dvi_hsync;
    vga_vsync <= dvi_vsync;
    vga_r <= dvi_data(23 downto 19);
    vga_g <= dvi_data(15 downto 10);
    vga_b <= dvi_data(7 downto 3);
end Behavioral;
