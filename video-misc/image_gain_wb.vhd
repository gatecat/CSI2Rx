library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--Gain/White Balance for CSI-2 Rx Example
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

--This applies simple gain and white balance adjustments to the image, also converting 10-bit
--RGB to 8-bit RGB. Like other processing blocks this operates on two pixels per clock

entity image_gain_wb is
  generic (
    --Red, green and blue channel gains in units of 1/8
    red_gain : natural := 10;
    green_gain : natural := 7;
    blue_gain : natural := 9
  );
  port(
    clock : in std_logic;

    input_vsync : in std_logic;
    input_hsync : in std_logic;
    input_den : in std_logic;
    input_line_start : in std_logic;
    input_data_even : in std_logic_vector(29 downto 0);
    input_data_odd : in std_logic_vector(29 downto 0);

    output_vsync : out std_logic;
    output_hsync : out std_logic;
    output_den : out std_logic;
    output_line_start : out std_logic;
    output_data_even : out std_logic_vector(23 downto 0);
    output_data_odd : out std_logic_vector(23 downto 0)

  );
end image_gain_wb;

architecture Behavioral of image_gain_wb is

  --Multiply a 10-bit number by a 4-bit natural and shift right to a 11-bit result
  function channel_mul(ch : std_logic_vector; gain : natural)
    return std_logic_vector is
  variable chvalue : unsigned(9 downto 0);
  variable gvalue : unsigned(3 downto 0);
  variable mul : unsigned(13 downto 0);
  variable result : std_logic_vector(10 downto 0);
  begin
    chvalue := unsigned(ch);
    gvalue := to_unsigned(gain, 4);
    mul := chvalue * gvalue;
    result := std_logic_vector(mul(13 downto 3));
    return result;
  end channel_mul;

  --Divide an 11-bit number by 4 and clamp it to an 8 bit unsigned value
  function clamp_to_8bit(inp : std_logic_vector)
    return std_logic_vector is
  variable result : std_logic_vector(7 downto 0);
  variable value : unsigned(10 downto 0);
  begin
    value := unsigned(inp);
    if value > 1023 then
      result := x"FF";
    else
      result := std_logic_vector(value(9 downto 2));
    end if;
    return result;
  end clamp_to_8bit;

begin

  process(clock)
  begin
    if rising_edge(clock) then
      output_vsync <= input_vsync;
      output_hsync <= input_hsync;
      output_den <= input_den;
      output_line_start <= input_line_start;

      output_data_even(7 downto 0) <= clamp_to_8bit(channel_mul(input_data_even(9 downto 0), blue_gain));
      output_data_even(15 downto 8) <= clamp_to_8bit(channel_mul(input_data_even(19 downto 10), green_gain));
      output_data_even(23 downto 16) <= clamp_to_8bit(channel_mul(input_data_even(29 downto 20), red_gain));

      output_data_odd(7 downto 0) <= clamp_to_8bit(channel_mul(input_data_odd(9 downto 0), blue_gain));
      output_data_odd(15 downto 8) <= clamp_to_8bit(channel_mul(input_data_odd(19 downto 10), green_gain));
      output_data_odd(23 downto 16) <= clamp_to_8bit(channel_mul(input_data_odd(29 downto 20), red_gain));
    end if;
  end process;

end Behavioral;
