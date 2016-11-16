library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--Low speed Omnivision camera reset sequencing and control
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

entity ov13850_control_top is
port(reset : in std_logic;
    clock : in std_logic; --400kHz clock
    i2c_sda : inout std_logic;
    i2c_sck : inout std_logic;
    rst_out : out std_logic;
    loading_out : out std_logic
    );
end ov13850_control_top;

architecture Behavioral of ov13850_control_top is

signal current_cmd : std_logic_vector(23 downto 0);
signal statecntr : unsigned(17 downto 0) := (others => '0');
signal cmd_addr :  std_logic_vector(8 downto 0);

signal i2c_en : std_logic;
signal i2c_start : std_logic;
signal i2c_done : std_logic;

constant state_end : integer := 262000;

begin

  i2c_if : entity work.ov_i2c_control
    generic map(
      slave_addr => x"20")
    port map(
      clock_in => clock,
      data_in => current_cmd,
      enable => i2c_en,
      start_xfer => i2c_start,
      xfer_done => i2c_done,
      i2c_sck => i2c_sck,
      i2c_sda => i2c_sda);

  regs : entity work.ov13850_4k_regs
    port map(
      clock => clock,
      address => cmd_addr,
      data => current_cmd);

  loading_out <= '1' when statecntr < state_end else '0';

  --Keep track of where we are in the setup procedure
  process(clock, reset)
  begin
    if reset = '1' then
        statecntr <= (others => '0');
    elsif rising_edge(clock) then
        if statecntr < state_end then
            statecntr <= statecntr + 1;
        end if;
    end if;
  end process;

  --Power on reset
  process(statecntr)
  begin
    if statecntr < 16384 then
        rst_out <= '0';
    else
        rst_out <= '1';
    end if;
  end process;

  --I2C command selection
  process(statecntr, current_cmd)
  variable statecntr_sub : unsigned(17 downto 0);
  begin
    if statecntr < 32768 then
        i2c_en <= '0';
        i2c_start <= '0';
        cmd_addr <= "0" & x"00";
    else
        statecntr_sub := statecntr - 32768;
        --We output a new command over I2C every 128 cycles
        cmd_addr <= std_logic_vector(statecntr_sub(17 downto 9));
        --All zeroes indicate a dummy command
        if current_cmd = x"000000" then
            i2c_en <= '0';
            i2c_start <= '0';
        else
            i2c_en <= '1';
            --Output a start transaction signal for cycles 1&2
            if statecntr_sub(8 downto 2) = 1 or statecntr_sub(8 downto 2) = 2 then
                i2c_start <= '1';
            else
                i2c_start <= '0';
            end if;
        end if;
    end if;
  end process;
end Behavioral;
