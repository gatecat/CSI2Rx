library ieee ;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--I2C controller for the VCM driver inside the camera module, responsible for
--focusing
--Copyright (C) 2016 David Shah
--Licensed under the MIT License


entity vcm_i2c_control is
port (clock_in : in std_logic;
  data_in : in std_logic_vector(9 downto 0); -- 10 bit VCM setting
  enable : in std_logic;
  start_xfer : in std_logic; --pull high, then low to reset and start xfer
  xfer_done : out std_logic; --signifies that the transfer is done
  i2c_sck : inout std_logic; --I2C SCK pin
  i2c_sda : inout std_logic); --I2C SDA pin
end vcm_i2c_control;

architecture behv_i2c of vcm_i2c_control is
signal sys_en : std_logic;
signal sda_int : std_logic; --Internal I2C data, 0=low, 1=tristate
signal sck_int : std_logic; --Internal I2C clock, 0=low, 1=tristate
signal sck_force : std_logic; --Used to force I2C clock

signal state_cntr : unsigned(7 downto 0); --Internal counter for keeping track of state

constant state_done : integer := 168; --value of state_cntr when transfer finished

constant slave_addr : std_logic_vector(7 downto 0) := x"18"; --VCM driver slave address

begin

process(enable, start_xfer, state_cntr)
begin
  if enable = '1' and start_xfer = '0' then
      if state_cntr >= state_done then
          sys_en <= '0';
          xfer_done <= '1';
      else
          sys_en <= '1';
          xfer_done <= '0';
      end if;
  else
      sys_en <= '0';
      xfer_done <= '0';
  end if;
end process;

process(start_xfer, clock_in)
begin
  if start_xfer = '1' then
      state_cntr <= "00000000";
  else
      if rising_edge(clock_in) then
          if state_cntr < state_done then
              state_cntr <= state_cntr + 1;
          end if;
      end if;
  end if;
end process;

process(sda_int, sck_int, sys_en)
begin
  if sys_en = '1' then
      if sda_int = '1' then
          i2c_sda <= 'Z';
      else
          i2c_sda <= '0';
      end if;

      if sck_int = '1' then
          i2c_sck <= 'Z';
      else
          i2c_sck <= '0';
      end if;
  else
      i2c_sda <= 'Z';
      i2c_sck <= 'Z';
  end if;
end process;

process(state_cntr, clock_in, sck_force)

begin
  if state_cntr(7 downto 2) >= 13 and state_cntr(7 downto 2) <= 39 then
      sck_int <= sck_force or (state_cntr(1) xor state_cntr(0));
  else
      sck_int <= sck_force;
  end if;
end process;

process(start_xfer, clock_in)
begin
  if start_xfer = '1' then
      sda_int <= '1';
      sck_force <= '1';
  elsif rising_edge(clock_in) then
      if state_cntr(1 downto 0) = 3 then
          case state_cntr(7 downto 2) is
              --start sequence
              when "001001" =>
                  sda_int <= '1';
                  sck_force <= '1';
              when "001010" =>
                  sda_int <= '0';
              when "001011" =>
                  sck_force <= '0';
              --I2C slave address
              when "001100" =>
                  sda_int <= slave_addr(7);
              when "001101" =>
                  sda_int <= slave_addr(6);
              when "001110" =>
                  sda_int <= slave_addr(5);
              when "001111" =>
                  sda_int <= slave_addr(4);
              when "010000" =>
                  sda_int <= slave_addr(3);
              when "010001" =>
                  sda_int <= slave_addr(2);
              when "010010" =>
                  sda_int <= slave_addr(1);
              when "010011" =>
                  sda_int <= slave_addr(0);
              when "010100" =>
                  sda_int <= '1';
              --Register address LSB
              when "010101" =>
                  sda_int <= '0';
              when "010110" =>
                  sda_int <= '0';
              when "010111" =>
                  sda_int <= data_in(9);
              when "011000" =>
                  sda_int <= data_in(8);
              when "011001" =>
                  sda_int <= data_in(7);
              when "011010" =>
                  sda_int <= data_in(6);
              when "011011" =>
                  sda_int <= data_in(5);
              when "011100" =>
                  sda_int <= data_in(4);
              when "011101" =>
                  sda_int <= '1';
              --Register value
              when "011110" =>
                  sda_int <= data_in(3);
              when "011111" =>
                  sda_int <= data_in(2);
              when "100000" =>
                  sda_int <= data_in(1);
              when "100001" =>
                  sda_int <= data_in(0);
              when "100010" =>
                  sda_int <= '0';
              when "100011" =>
                  sda_int <= '1';
              when "100100" =>
                  sda_int <= '1';
              when "100101" =>
                  sda_int <= '1';
              when "100110" =>
                  sda_int <= '1';
              --STOP
              when "100111" =>
                  sda_int <= '0';
                  sck_force <= '0';
              when "101000" =>
                  sck_force <= '1';
              when "101001" =>
                  sda_int <= '1';
              when others =>
          end case;
      end if;
  end if;
end process;
end behv_i2c;
