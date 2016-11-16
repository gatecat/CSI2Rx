----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09.11.2016 09:30:48
-- Design Name: 
-- Module Name: genesys2_hdmitest - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity genesys2_hdmitest is
  Port (
    clock_p : in std_logic;
    clock_n : in std_logic;
    reset_n : in std_logic;
    
    hdmi_clk : out std_logic_vector(1 downto 0);
    hdmi_d0 : out std_logic_vector(1 downto 0);
    hdmi_d1 : out std_logic_vector(1 downto 0);
    hdmi_d2 : out std_logic_vector(1 downto 0)

  );
end genesys2_hdmitest;

architecture Behavioral of genesys2_hdmitest is

signal sys_clock : std_logic;

signal reset : std_logic;
signal pixel_clock, hdmi_bit_clock : std_logic;

signal video_data : std_logic_vector(23 downto 0);
signal video_den, video_hsync, video_vsync : std_logic;

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
    
    pll : entity work.hdmi_pll
    port map(
        sysclk => sys_clock,
        pixel_clock => pixel_clock,
        hdmi_bit_clock => hdmi_bit_clock
    );
    
    
    dvi_tx : entity work.dvi_tx
    port map(
        pixel_clock => pixel_clock,
        ddr_bit_clock => hdmi_bit_clock,
        reset => reset,
        den => video_den,
        hsync => video_hsync,
        vsync => video_vsync,
        pixel_data => video_data,
    
        tmds_clk => hdmi_clk,
        tmds_d0 => hdmi_d0,
        tmds_d1 => hdmi_d1,
        tmds_d2 => hdmi_d2
    );
    
    pattern_gen : entity work.test_pattern_1080p
    port map(
        clock => pixel_clock,
        den => video_den,
        hsync => video_hsync,
        vsync => video_vsync,
        pixel_data => video_data
    );    
end Behavioral;
