library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

--Pipeline register for video systems (supports up to 2 pixels per clock)
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

--Insert this where needed to obtain timing closure for the design

entity video_register is
  port(
    clock : in std_logic;

    den_in : in std_logic;
    vsync_in  : in std_logic;
    hsync_in : in std_logic;
    line_start_in : in std_logic;
    pixel_1_in : in std_logic_vector(23 downto 0);
    pixel_2_in : in std_logic_vector(23 downto 0);

    den_out : out std_logic;
    vsync_out  : out std_logic;
    hsync_out : out std_logic;
    line_start_out : out std_logic;
    pixel_1_out : out std_logic_vector(23 downto 0);
    pixel_2_out : out std_logic_vector(23 downto 0)
  );
end entity;

architecture Behavioral of video_register is

begin
  process(clock)
  begin
    if rising_edge(clock) then
      den_out <= den_in;
      vsync_out <= vsync_in;
      hsync_out <= hsync_in;
      line_start_out <= line_start_in;
      pixel_1_out <= pixel_1_in;
      pixel_2_out <= pixel_2_in;
    end if;
  end process;
end Behavioral;
