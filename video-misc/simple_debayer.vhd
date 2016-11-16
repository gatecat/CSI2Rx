library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--Minimal Debayering Block for CSI-2 Rx
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

--This uses the simplest possible method to debayer two pixels per clock,
--purely as a proof of concept to demo the CSI-2 Rx core. It is designed to go between
--the CSI-2 Rx and the white balance/gain controller, also included in the example

entity simple_debayer is
  port(
    clock : in std_logic;

    input_hsync : in std_logic;
    input_vsync : in std_logic;
    input_den : in std_logic;
    input_line_start : in std_logic;
    input_odd_line : in std_logic;
    input_data : in std_logic_vector(19 downto 0);
    input_prev_line_data : in std_logic_vector(19 downto 0);

    output_hsync : out std_logic;
    output_vsync : out std_logic;
    output_den : out std_logic;
    output_line_start : out std_logic;
    output_data_even : out std_logic_vector(29 downto 0); --10bit R:G:B
    output_data_odd : out std_logic_vector(29 downto 0) --10bit R:G:B
  );
end simple_debayer;

architecture Behavioral of simple_debayer is
signal last_block_c, last_block_p : std_logic_vector(19 downto 0);
signal pre_hsync, pre_vsync, pre_den, pre_line_start : std_logic;
signal pre_data_even, pre_data_odd : std_logic_vector(29 downto 0);
function channel_average(val_1, val_2 : std_logic_vector)
  return std_logic_vector is
    variable sum : unsigned(10 downto 0);
    variable result : std_logic_vector(9 downto 0);
  begin
    sum := resize(unsigned(val_1), 11) + resize(unsigned(val_2), 11);
    result := std_logic_vector(sum(10 downto 1));
    return result;
end function;


begin
  process(clock)
    variable pixel_0_R, pixel_0_G, pixel_0_B : std_logic_vector(9 downto 0);
    variable pixel_1_R, pixel_1_G, pixel_1_B : std_logic_vector(9 downto 0);

  begin
    if rising_edge(clock) then
      pre_hsync <= input_hsync;
      pre_vsync <= input_vsync;
      pre_den <= input_den;
      pre_line_start <= input_line_start;

      if input_odd_line = '1' then
        pixel_0_R := channel_average(input_data(19 downto 10), last_block_c(19 downto 10));
        pixel_0_G := input_data(9 downto 0);
        pixel_0_B := input_prev_line_data(9 downto 0);

        pixel_1_R := input_data(19 downto 10);
        pixel_1_G := channel_average(input_data(9 downto 0), last_block_p(19 downto 10));
        pixel_1_B := input_prev_line_data(9 downto 0);
      else
        pixel_0_R := channel_average(input_prev_line_data(19 downto 10), last_block_p(19 downto 10));
        pixel_0_G := channel_average(input_data(19 downto 10), last_block_c(19 downto 10));
        pixel_0_B := input_data(9 downto 0);

        pixel_1_R := input_prev_line_data(19 downto 10);
        pixel_1_G := input_data(19 downto 10);
        pixel_1_B := input_data(9 downto 0);
      end if;

      pre_data_even <= pixel_0_R & pixel_0_G & pixel_0_B;
      pre_data_odd <= pixel_1_R & pixel_1_G & pixel_1_B;

      output_hsync <= pre_hsync;
      output_vsync <= pre_vsync;
      output_den <= pre_den;
      output_line_start <= pre_line_start;
      output_data_even <= pre_data_even;
      output_data_odd <= pre_data_odd;

      if input_den = '1' then
        last_block_c <= input_data;
        last_block_p <= input_prev_line_data;
      end if;
    end if;
  end process;
end architecture;
