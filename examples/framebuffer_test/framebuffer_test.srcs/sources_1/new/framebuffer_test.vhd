--Framebuffer Test Top Level Design

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity genesys2_fbtest is
  Port (
    clock_p : in std_logic;
    clock_n : in std_logic;
    reset_n : in std_logic;
    
    hdmi_clk : out std_logic_vector(1 downto 0);
    hdmi_d0 : out std_logic_vector(1 downto 0);
    hdmi_d1 : out std_logic_vector(1 downto 0);
    hdmi_d2 : out std_logic_vector(1 downto 0);
    
    zoom_mode : in std_logic;
    freeze : in std_logic;
    
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
end genesys2_fbtest;

architecture Behavioral of genesys2_fbtest is

signal sys_clock : std_logic;

signal reset : std_logic;
signal dvi_pixel_clock, dvi_bit_clock : std_logic;

signal dvi_data : std_logic_vector(23 downto 0);
signal dvi_den, dvi_hsync, dvi_vsync : std_logic;

signal input_pixel_clock : std_logic;

signal pattern_line_start, pattern_den, pattern_hsync, pattern_vsync : std_logic;
signal pattern_data_even, pattern_data_odd : std_logic_vector(23 downto 0);

signal input_line_start, input_den, input_hsync, input_vsync : std_logic;
signal input_data_even, input_data_odd : std_logic_vector(23 downto 0);

component dvi_pll is
  port(
    sysclk : in std_logic;
    pixel_clock : out std_logic;
    dvi_bit_clock : out std_logic);
end component;

component camera_pll is
  port(
    sysclk : in std_logic;
    camera_pixel_clock : out std_logic);
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
        camera_pixel_clock => input_pixel_clock
    );
    
    fbtest : entity work.framebuffer_top
      port map(
        input_pixck => input_pixel_clock,
        input_vsync => input_vsync,
        input_line_start => input_line_start,
        input_den => input_den,
        input_data_even => input_data_even,
        input_data_odd => input_data_odd,
        
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
   
    tp : entity work.test_pattern_gen
      port map(
        pixel_clock => input_pixel_clock,
        reset => reset,
    
        video_vsync => pattern_vsync,
        video_hsync => pattern_hsync,
        video_den => pattern_den,
        video_line_start => pattern_line_start,
    
        --2 pixel per clock output
        video_pixel_even => pattern_data_even,
        video_pixel_odd => pattern_data_odd);
    
    vreg1: entity work.video_register
      port map(
        clock => input_pixel_clock,
        
        den_in => pattern_den,
        vsync_in => pattern_vsync,
        hsync_in => pattern_hsync,
        line_start_in => pattern_line_start,
        pixel_1_in => pattern_data_even,
        pixel_2_in => pattern_data_odd,
        
        den_out => input_den,
        vsync_out => input_vsync,
        hsync_out => input_hsync,
        line_start_out => input_line_start,
        pixel_1_out => input_data_even,
        pixel_2_out => input_data_odd     
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
end Behavioral;
